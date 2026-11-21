import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/contributions.dart';

/// Ricorda sul dispositivo quando si è aiutato sulle segnalazioni degli
/// altri e quale riepilogo settimanale è già stato mostrato, per utente.
class ContributionLogService {
  ContributionLogService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static String helpsKey(String userId) => 'freeway.helps.$userId';
  static String weekKey(String userId) => 'freeway.week_shown.$userId';

  /// Bastano per qualche mese di aiuti.
  static const int maxEntries = 500;

  String? _userId;
  List<HelpEntry> _helps = [];

  List<HelpEntry> get helps => List.unmodifiable(_helps);

  Future<List<HelpEntry>> load(String userId) async {
    _userId = userId;
    _helps = [];
    try {
      final raw = (await _preferences()).getString(helpsKey(userId));
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is List) {
        _helps = [for (final item in decoded) ?HelpEntry.fromJson(item)];
      }
    } catch (_) {
      // Dati illeggibili: si riparte da zero.
    }
    return helps;
  }

  /// Registra un aiuto, una volta per ostacolo e tipo.
  Future<void> add(String userId, HelpEntry entry) async {
    if (_userId != userId) await load(userId);
    if (_helps.any((h) => h.key == entry.key)) return;
    _helps = [entry, ..._helps].take(maxEntries).toList();
    try {
      await (await _preferences()).setString(
        helpsKey(userId),
        jsonEncode([for (final h in _helps) h.toJson()]),
      );
    } catch (_) {}
  }

  Future<bool> wasWeekShown(String userId, DateRange week) async {
    try {
      return (await _preferences()).getString(weekKey(userId)) == week.id;
    } catch (_) {
      return false;
    }
  }

  Future<void> markWeekShown(String userId, DateRange week) async {
    try {
      await (await _preferences()).setString(weekKey(userId), week.id);
    } catch (_) {}
  }
}
