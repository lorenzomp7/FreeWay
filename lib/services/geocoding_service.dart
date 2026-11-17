import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'routing_service.dart' show kUserAgent;

/// Suggerimenti di ricerca da Photon e geocodifica inversa da Nominatim.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _requestTimeout = Duration(seconds: 5);
  static const _searchOrigin = LatLng(45.54, 10.22); // Brescia
  static const _minReverseInterval = Duration(milliseconds: 1100);

  /// Numero massimo di ricerche tenute in memoria.
  static const int cacheSize = 50;

  final Map<String, List<Map<String, dynamic>>> _cache = {};
  Future<void> _queue = Future.value();
  DateTime? _lastRequest;
  Timer? _debounce;
  int _generation = 0;

  /// Cerca [query] dopo 300 ms di inattività e passa i risultati a [onResults].
  /// I risultati di una ricerca superata da una più recente vengono scartati.
  void searchDebounced(
    String query,
    void Function(List<Map<String, dynamic>> results) onResults, {
    required void Function() onError,
  }) {
    cancelSearch();
    final generation = _generation;
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      onResults([]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await search(trimmed);
        if (generation == _generation) onResults(results);
      } on Exception {
        if (generation == _generation) onError();
      }
    });
  }

  void cancelSearch() {
    _debounce?.cancel();
    _generation++;
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    final key = query.trim().toLowerCase();
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // Torna in fondo: è la più recente.
      return List.of(cached);
    }

    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query.trim(),
      'limit': '8',
      'lat': '${_searchOrigin.latitude}',
      'lon': '${_searchOrigin.longitude}',
    });
    final response = await _client.get(uri).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      throw http.ClientException('Photon: HTTP ${response.statusCode}', uri);
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final features = data is Map<String, dynamic> ? data['features'] : null;
    if (features is! List)
      throw const FormatException('Risposta Photon non valida');
    final results = features
        .whereType<Map<String, dynamic>>()
        .map(_photonPlace)
        .nonNulls
        .toList();

    _cache[key] = results;
    if (_cache.length > cacheSize) _cache.remove(_cache.keys.first);
    return List.of(results);
  }

  Map<String, dynamic>? _photonPlace(Map<String, dynamic> feature) {
    final properties = feature['properties'];
    final geometry = feature['geometry'];
    if (properties is! Map<String, dynamic> ||
        geometry is! Map<String, dynamic>) {
      return null;
    }
    final coordinates = geometry['coordinates'];
    if (coordinates is! List ||
        coordinates.length < 2 ||
        coordinates[0] is! num ||
        coordinates[1] is! num) {
      return null;
    }
    final street = properties['street'];
    final houseNumber = properties['housenumber'];
    final streetAddress = street != null && houseNumber != null
        ? '$street $houseNumber'
        : street;
    final name = properties['name'] ?? streetAddress;
    if (name == null) return null;
    final city = properties['city'] ?? properties['locality'];
    return {
      'name': name,
      'display_name': name,
      'lat': coordinates[1],
      'lon': coordinates[0],
      'address': {
        'city': city == name ? null : city,
        'state': properties['state'] ?? properties['country'],
      },
    };
  }

  Future<http.Response> _getReverse(Uri uri) {
    final response = _queue.then((_) async {
      final last = _lastRequest;
      if (last != null) {
        final wait = _minReverseInterval - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      _lastRequest = DateTime.now();
      return _client
          .get(uri, headers: {'User-Agent': kUserAgent})
          .timeout(_requestTimeout);
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
      final response = await _getReverse(uri);
      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final street =
              address['road'] ?? address['pedestrian'] ?? address['suburb'];
          final city =
              address['city'] ??
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
    cancelSearch();
    _client.close();
  }
}

/// Titolo e sottotitolo di un suggerimento di ricerca.
class PlaceLabel {
  const PlaceLabel({required this.subtitle, required this.title});

  final String subtitle;
  final String title;
}

PlaceLabel formatPlace(Map<String, dynamic> place) {
  final address = place['address'] as Map<String, dynamic>?;
  final title =
      address?['road'] ??
      address?['pedestrian'] ??
      address?['suburb'] ??
      place['name'] ??
      (place['display_name'] as String?)?.split(',').first ??
      '';
  final city =
      address?['city'] ??
      address?['town'] ??
      address?['village'] ??
      address?['municipality'];
  final region = address?['county'] ?? address?['state'];
  final subtitle = [
    city,
    region,
  ].where((part) => part != null && part.toString().isNotEmpty).join(', ');
  return PlaceLabel(subtitle: subtitle, title: title.toString());
}
