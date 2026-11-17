import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'routing_service.dart' show kUserAgent;

/// Ricerca indirizzi tramite Nominatim (OpenStreetMap).
class GeocodingService {
  Timer? _debounce;

  /// Cerca [query] dopo 350 ms di inattività e passa i risultati a [onResults].
  void searchDebounced(
    String query,
    void Function(List<Map<String, dynamic>> results) onResults,
  ) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      onResults([]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        onResults(await search(trimmed));
      } catch (_) {
        onResults([]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    // Prima prova limitando la ricerca all'Italia...
    final italian = await http.get(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': query,
        'limit': '8',
        'countrycodes': 'it',
        'addressdetails': '1',
      }),
      headers: {'User-Agent': kUserAgent},
    );
    if (italian.statusCode == 200) {
      final results = jsonDecode(italian.body) as List;
      if (results.isNotEmpty) {
        return results.map((e) => e as Map<String, dynamic>).toList();
      }
    }

    // ...poi senza limitazioni geografiche.
    final global = await http.get(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'json',
        'q': query,
        'limit': '8',
        'addressdetails': '1',
      }),
      headers: {'User-Agent': kUserAgent},
    );
    if (global.statusCode == 200) {
      return (jsonDecode(global.body) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    return [];
  }

  /// Restituisce un indirizzo leggibile per [position], se disponibile.
  Future<String?> reverse(LatLng position) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'json',
        'lat': '${position.latitude}',
        'lon': '${position.longitude}',
        'addressdetails': '1',
      });
      final response = await http.get(uri, headers: {'User-Agent': kUserAgent});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
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

  void dispose() => _debounce?.cancel();
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
