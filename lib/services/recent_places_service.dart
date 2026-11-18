import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Luoghi cercati di recente, salvati sul dispositivo come le "Ricerche
/// recenti" di Google Maps.
///
/// Il più recente è il primo. Un luogo cercato di nuovo torna in cima invece
/// di comparire due volte.
class RecentPlacesService {
  RecentPlacesService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const String storageKey = 'freeway.recent_places';

  /// Numero massimo di luoghi tenuti in cronologia.
  static const int maxPlaces = 15;

  List<Map<String, dynamic>> _places = [];

  List<Map<String, dynamic>> get places => List.unmodifiable(_places);

  Future<List<Map<String, dynamic>>> load() async {
    try {
      final raw = (await _preferences()).getString(storageKey);
      if (raw == null) return places;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _places = decoded
            .whereType<Map<String, dynamic>>()
            .where((p) => p['lat'] is num && p['lon'] is num)
            .take(maxPlaces)
            .toList();
      }
    } catch (_) {
      // Cronologia illeggibile o archivio non disponibile: si riparte vuoti.
      _places = [];
    }
    return places;
  }

  /// Mette [place] in cima alla cronologia.
  Future<List<Map<String, dynamic>>> add(Map<String, dynamic> place) async {
    final entry = <String, dynamic>{
      'name': place['name'] ?? place['display_name'],
      'display_name': place['display_name'] ?? place['name'],
      'lat': double.parse(place['lat'].toString()),
      'lon': double.parse(place['lon'].toString()),
      if (place['address'] is Map) 'address': place['address'],
      if (place['kind'] != null) 'kind': place['kind'],
    };
    _places = [
      entry,
      ..._places.where((p) => !isSamePlace(p, entry)),
    ].take(maxPlaces).toList();
    await _save();
    return places;
  }

  Future<List<Map<String, dynamic>>> remove(Map<String, dynamic> place) async {
    _places = _places.where((p) => !isSamePlace(p, place)).toList();
    await _save();
    return places;
  }

  Future<List<Map<String, dynamic>>> clear() async {
    _places = [];
    await _save();
    return places;
  }

  /// Luoghi recenti il cui nome o indirizzo contiene tutte le parole di
  /// [query], da mostrare prima dei suggerimenti mentre si digita.
  List<Map<String, dynamic>> matching(String query, {int limit = 3}) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    return _places
        .where((place) {
          final address = place['address'];
          final text = [
            place['name'],
            if (address is Map) ...address.values,
          ].whereType<Object>().join(' ').toLowerCase();
          return words.every(text.contains);
        })
        .take(limit)
        .toList();
  }

  /// Stesso nome e coordinate entro circa 10 metri.
  static bool isSamePlace(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aLat = double.tryParse(a['lat'].toString());
    final aLon = double.tryParse(a['lon'].toString());
    final bLat = double.tryParse(b['lat'].toString());
    final bLon = double.tryParse(b['lon'].toString());
    if (aLat == null || aLon == null || bLat == null || bLon == null) {
      return false;
    }
    return (aLat - bLat).abs() < 0.0001 &&
        (aLon - bLon).abs() < 0.0001 &&
        '${a['name']}'.toLowerCase() == '${b['name']}'.toLowerCase();
  }

  Future<void> _save() async {
    try {
      await (await _preferences()).setString(storageKey, jsonEncode(_places));
    } catch (_) {
      // Senza archivio la cronologia resta solo in memoria.
    }
  }
}
