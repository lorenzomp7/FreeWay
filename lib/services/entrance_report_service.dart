import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entrance_report.dart';
import 'geo_utils.dart';

/// Risposte alla domanda "Com'era l'ingresso?" nella collezione `ingressi`.
class EntranceReportService {
  EntranceReportService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('ingressi');

  /// Salva la risposta di [userId] per la destinazione [position], insieme
  /// all'ora in `limiti/{uid}` che le regole usano per limitarne la
  /// frequenza.
  Future<void> add(LatLng position, EntranceAnswer answer, String userId) {
    final batch = _firestore.batch()
      ..set(_collection.doc(), {
        'lat': position.latitude,
        'lng': position.longitude,
        'answer': answer.value,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      })
      ..set(_firestore.collection('limiti').doc(userId), {
        'lastEntranceAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    return batch.commit();
  }

  /// Risposte entro [radius] metri da [position] dell'ultimo anno.
  ///
  /// Firestore filtra solo sulla latitudine; longitudine, distanza ed età
  /// si controllano qui. Se la lettura non riesce la scheda funziona senza.
  Future<EntranceSummary> near(
    LatLng position, {
    double radius = 40,
    DateTime? now,
  }) async {
    final delta = radius / 111195;
    try {
      final snapshot = await _collection
          .where('lat', isGreaterThanOrEqualTo: position.latitude - delta)
          .where('lat', isLessThanOrEqualTo: position.latitude + delta)
          .limit(200)
          .get();
      final reports = [for (final doc in snapshot.docs) ?_parse(doc.data())];
      return EntranceSummary.of(
        nearbyRecent(reports, position, radius: radius, now: now),
      );
    } catch (_) {
      return const EntranceSummary();
    }
  }

  static EntranceReport? _parse(Map<String, dynamic> data) {
    final lat = data['lat'], lng = data['lng'];
    final answer = EntranceAnswer.fromValue(data['answer']);
    if (lat is! num || lng is! num || answer == null) return null;
    final timestamp = data['timestamp'];
    return EntranceReport(
      position: LatLng(lat.toDouble(), lng.toDouble()),
      answer: answer,
      reportedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

/// Le risposte di [reports] entro [radius] metri da [position] e non più
/// vecchie di [maxAge]: un ingresso può essere stato sistemato.
List<EntranceReport> nearbyRecent(
  Iterable<EntranceReport> reports,
  LatLng position, {
  double radius = 40,
  Duration maxAge = const Duration(days: 365),
  DateTime? now,
}) {
  final limit = (now ?? DateTime.now()).subtract(maxAge);
  return [
    for (final report in reports)
      if (haversineDistance(report.position, position) <= radius &&
          (report.reportedAt == null || report.reportedAt!.isAfter(limit)))
        report,
  ];
}

/// Decide se all'arrivo si può fare la domanda sull'ingresso.
///
/// Fatta a ogni arrivo diventerebbe un fastidio: al massimo [perDay] volte
/// al giorno e [perWeek] alla settimana. Gli orari restano sul dispositivo.
class ArrivalQuestionPolicy {
  ArrivalQuestionPolicy({
    Future<SharedPreferences> Function()? preferences,
    this.perDay = 2,
    this.perWeek = 5,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;
  final int perDay;
  final int perWeek;

  static const String _key = 'arrival_question_shown';

  /// `true` se in [shown] ci sono meno di [perDay] domande nelle ultime 24
  /// ore e meno di [perWeek] negli ultimi 7 giorni.
  static bool allowed(
    Iterable<DateTime> shown,
    DateTime now, {
    int perDay = 2,
    int perWeek = 5,
  }) {
    final day = now.subtract(const Duration(days: 1));
    final week = now.subtract(const Duration(days: 7));
    return shown.where((t) => t.isAfter(day)).length < perDay &&
        shown.where((t) => t.isAfter(week)).length < perWeek;
  }

  Future<List<DateTime>> _load(SharedPreferences prefs) async {
    return [
      for (final value in prefs.getStringList(_key) ?? const <String>[])
        ?DateTime.tryParse(value),
    ];
  }

  /// Se si può fare la domanda adesso; in quel caso la registra.
  Future<bool> tryAsk({DateTime? now}) async {
    final time = now ?? DateTime.now();
    try {
      final prefs = await _preferences();
      final shown = await _load(prefs);
      if (!allowed(shown, time, perDay: perDay, perWeek: perWeek)) {
        return false;
      }
      final week = time.subtract(const Duration(days: 7));
      await prefs.setStringList(_key, [
        for (final t in [...shown, time])
          if (t.isAfter(week)) t.toIso8601String(),
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
