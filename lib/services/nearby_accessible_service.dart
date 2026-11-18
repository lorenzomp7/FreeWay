import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geo_utils.dart';
import 'geocoding_service.dart' show placeKind;

/// Filtri di accessibilità nella ricerca, come i filtri dei servizi
/// ("Wheelchair accessible", "Disability parking", "Restrooms") che alcuni
/// navigatori offrono cercando un luogo.
enum NearbyFilter {
  wheelchair('Accessibili in sedia a rotelle', 'Luogo accessibile'),
  parking('Parcheggi disabili', 'Parcheggio per disabili'),
  toilets('Bagni accessibili', 'Bagno accessibile');

  const NearbyFilter(this.label, this.genericName);

  /// Testo del filtro.
  final String label;

  /// Nome usato per i luoghi senza nome (un parcheggio, un bagno pubblico).
  final String genericName;
}

/// Cerca su OpenStreetMap, tramite Overpass, i luoghi accessibili vicino a
/// un punto. I risultati hanno la stessa forma dei suggerimenti della
/// ricerca, così si aprono nella scheda del luogo come gli altri.
class NearbyAccessibleService {
  NearbyAccessibleService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static final Uri endpoint = Uri.https('overpass-api.de', '/api/interpreter');

  /// Raggio di ricerca in metri.
  static const int radius = 800;

  /// Risultati al massimo, dai più vicini.
  static const int maxResults = 30;

  /// `null` se Overpass non risponde; lista vuota se non c'è nulla.
  Future<List<Map<String, dynamic>>?> search(
    NearbyFilter filter,
    LatLng center,
  ) async {
    try {
      // Modulo semplice, senza intestazioni in più: nel browser non serve il
      // controllo preventivo CORS.
      final response = await _client
          .post(endpoint, body: {'data': buildQuery(filter, center)})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) return null;
      return parse(filter, data, center);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static String buildQuery(NearbyFilter filter, LatLng center) {
    final around =
        'around:$radius,${center.latitude.toStringAsFixed(6)},'
        '${center.longitude.toStringAsFixed(6)}';
    final filters = switch (filter) {
      // Solo luoghi con un nome: negozi, uffici, musei, ristoranti…
      NearbyFilter.wheelchair =>
        'nwr($around)["wheelchair"~"^(yes|designated)\$"]["name"];',
      NearbyFilter.parking =>
        'nwr($around)["amenity"="parking"]["capacity:disabled"]'
            '["capacity:disabled"!="no"]["capacity:disabled"!="0"];'
            'nwr($around)["parking_space"="disabled"];',
      NearbyFilter.toilets =>
        'nwr($around)["amenity"="toilets"]'
            '["wheelchair"~"^(yes|designated)\$"];'
            'nwr($around)["toilets:wheelchair"~"^(yes|designated)\$"];',
    };
    return '[out:json][timeout:15];($filters);out center 200;';
  }

  /// Chiavi di OpenStreetMap che dicono che tipo di luogo è.
  static const List<String> _kindKeys = [
    'amenity',
    'shop',
    'tourism',
    'healthcare',
    'leisure',
    'office',
    'railway',
    'public_transport',
    'building',
  ];

  @visibleForTesting
  static List<Map<String, dynamic>> parse(
    NearbyFilter filter,
    Map<String, dynamic> data,
    LatLng center,
  ) {
    final elements = data['elements'];
    if (elements is! List) return const [];
    final seen = <String>{};
    final places = <({double distance, Map<String, dynamic> place})>[];
    for (final element in elements) {
      if (element is! Map<String, dynamic>) continue;
      final type = element['type'];
      final id = element['id'];
      final point = element['center'] is Map<String, dynamic>
          ? element['center'] as Map<String, dynamic>
          : element;
      final lat = point['lat'], lon = point['lon'];
      if (type is! String || id is! num || lat is! num || lon is! num) {
        continue;
      }
      final osmType = switch (type) {
        'node' => 'N',
        'way' => 'W',
        'relation' => 'R',
        _ => null,
      };
      if (osmType == null || !seen.add('$osmType$id')) continue;
      final tags = element['tags'] is Map<String, dynamic>
          ? element['tags'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final name = tags['name'] as String? ?? filter.genericName;
      final street = tags['addr:street'] as String?;
      final number = tags['addr:housenumber'] as String?;
      final address = street == null
          ? null
          : (number == null ? street : '$street $number');
      final kindKey = _kindKeys.firstWhere(
        (k) => tags[k] is String,
        orElse: () => '',
      );
      final position = LatLng(lat.toDouble(), lon.toDouble());
      places.add((
        distance: haversineDistance(center, position),
        place: {
          'name': name,
          'display_name': name,
          'lat': lat,
          'lon': lon,
          'osm_type': osmType,
          'osm_id': id.toInt(),
          'kind': placeKind(kindKey, '${tags[kindKey] ?? ''}'),
          'address': {'street': ?address, 'city': tags['addr:city']},
        },
      ));
    }
    places.sort((a, b) => a.distance.compareTo(b.distance));
    return [for (final p in places.take(maxResults)) p.place];
  }
}
