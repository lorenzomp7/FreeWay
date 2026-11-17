import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'routing_service.dart' show kUserAgent;

/// Ricerca indirizzi tramite Nominatim (OpenStreetMap).
///
/// Rispetta le regole d'uso di Nominatim: al massimo una richiesta al secondo
/// (le richieste vengono messe in coda) e risultati delle ricerche già fatte
/// tenuti in memoria.
class GeocodingService {
  GeocodingService({
    http.Client? client,
    this.minInterval = const Duration(milliseconds: 1100),
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Intervallo minimo tra due richieste a Nominatim.
  final Duration minInterval;

  /// Numero massimo di ricerche tenute in memoria.
  static const int cacheSize = 50;

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest;
  Timer? _debounce;
  int _generation = 0;

  /// Cerca [query] dopo 350 ms di inattività e passa i risultati a [onResults].
  /// I risultati di una ricerca superata da una più recente vengono scartati.
  void searchDebounced(
    String query,
    void Function(List<Map<String, dynamic>> results) onResults,
  ) {
    _debounce?.cancel();
    final generation = ++_generation;
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      onResults([]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      List<Map<String, dynamic>> results;
      try {
        results = await search(trimmed);
      } catch (_) {
        results = [];
      }
      if (generation == _generation) onResults(results);
    });
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final key = query.trim().toLowerCase();
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // Torna in fondo: è la più recente.
      return List.of(cached);
    }

    // Prima prova limitando la ricerca all'Italia, poi ovunque.
    var results = await _search(query, italyOnly: true);
    if (results == null || results.isEmpty) {
      results = await _search(query, italyOnly: false);
    }
    if (results == null) return [];

    _cache[key] = results;
    if (_cache.length > cacheSize) _cache.remove(_cache.keys.first);
    return List.of(results);
  }

  /// `null` se Nominatim non ha risposto correttamente.
  Future<List<Map<String, dynamic>>?> _search(
    String query, {
    required bool italyOnly,
  }) async {
    final response = await _get(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': query,
        'limit': '8',
        if (italyOnly) 'countrycodes': 'it',
        'addressdetails': '1',
        'accept-language': 'it',
      }),
    );
    if (response.statusCode != 200) return null;
    return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Esegue le richieste una alla volta, distanziate di [minInterval].
  Future<http.Response> _get(Uri uri) {
    final response = _queue.then((_) async {
      final last = _lastRequest;
      if (last != null) {
        final wait = minInterval - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastRequest = DateTime.now();
      return _client.get(uri, headers: {'User-Agent': kUserAgent});
    });
    _queue = response.then((_) {}, onError: (Object _) {});
    return response;
  }

  /// Restituisce un indirizzo leggibile per [position], se disponibile.
  Future<String?> reverse(LatLng position) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': '${position.latitude}',
        'lon': '${position.longitude}',
        'addressdetails': '1',
        'accept-language': 'it',
      });
      final response = await _get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final street =
              address['road'] ?? address['pedestrian'] ?? address['suburb'];
          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'];
          if (street != null && city != null) return '$street, $city';
          if (street != null) return '$street';
        }
        return data['display_name'] as String?;
      }
    } catch (_) {
      // Indirizzo non disponibile.
    }
    return null;
  }

  void dispose() {
    _debounce?.cancel();
    _generation++; // Ignora le ricerche ancora in corso.
  }
}

/// Titolo e sottotitolo di un risultato Nominatim.
class PlaceLabel {
  const PlaceLabel({required this.subtitle, required this.title});

  final String subtitle;
  final String title;
}

PlaceLabel formatPlace(Map<String, dynamic> place) {
  final address = place['address'] as Map<String, dynamic>?;
  final title = address?['road'] ??
      address?['pedestrian'] ??
      address?['suburb'] ??
      place['name'] ??
      (place['display_name'] as String?)?.split(',').first ??
      '';
  final city = address?['city'] ??
      address?['town'] ??
      address?['village'] ??
      address?['municipality'];
  final region = address?['county'] ?? address?['state'];
  final subtitle = [city, region]
      .where((part) => part != null && part.toString().isNotEmpty)
      .join(', ');
  return PlaceLabel(subtitle: subtitle, title: title.toString());
}
