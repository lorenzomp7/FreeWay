import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geo_utils.dart';
import 'obstacle_alerts.dart' show nearestPointIndex;

/// Cosa cercare lungo il percorso, come le categorie di "Search along
/// route" di Google Maps, scelte per chi si muove in sedia a rotelle o si
/// stanca facilmente.
enum AlongRouteCategory {
  toilets('Bagni accessibili', 'bagno accessibile', 'bagni accessibili'),
  benches('Panchine', 'panchina', 'panchine'),
  water('Fontanelle', 'fontanella', 'fontanelle');

  const AlongRouteCategory(this.label, this.singular, this.plural);

  /// Testo del pulsante.
  final String label;
  final String singular;
  final String plural;
}

/// Un luogo utile vicino al percorso.
class AlongRoutePlace {
  const AlongRoutePlace({
    required this.category,
    required this.position,
    required this.name,
    required this.metersFromStart,
    this.isLimited = false,
  });

  final AlongRouteCategory category;
  final LatLng position;

  /// Nome del locale, o un nome generico ("Bagno pubblico", "Panchina").
  final String name;

  /// Distanza lungo il percorso dalla partenza al punto più vicino.
  final double metersFromStart;

  /// Solo per i bagni: accessibilità parziale (`wheelchair=limited`).
  final bool isLimited;
}

/// Cerca lungo il percorso su OpenStreetMap, tramite Overpass.
class AlongRouteService {
  AlongRouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final Uri endpoint = Uri.https('overpass-api.de', '/api/interpreter');

  /// Distanza massima dal percorso, in metri.
  static const int corridorMeters = 80;

  /// Punti del percorso passati a Overpass: bastano per un corridoio di 80 m
  /// e tengono corta la richiesta.
  static const int maxQueryPoints = 40;

  /// Risultati al massimo per categoria.
  static const int maxResults = 30;

  /// Panchine più vicine di così si contano una volta sola (file di panchine
  /// in un parco).
  static const double _mergeMeters = 20;

  /// `null` se Overpass non risponde; lista vuota se non c'è nulla.
  Future<List<AlongRoutePlace>?> search(
    AlongRouteCategory category,
    List<LatLng> route,
  ) async {
    if (route.length < 2) return const [];
    try {
      // Modulo semplice, senza intestazioni in più: nel browser non serve il
      // controllo preventivo CORS.
      final response = await _client
          .post(endpoint, body: {'data': buildQuery(category, route)})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) return null;
      return parse(category, data, route);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static String buildQuery(AlongRouteCategory category, List<LatLng> route) {
    final points = samplePoints(route, maxQueryPoints)
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(6)},'
              '${p.longitude.toStringAsFixed(6)}',
        )
        .join(',');
    final around = 'around:$corridorMeters,$points';
    final filters = switch (category) {
      AlongRouteCategory.toilets =>
        'nwr($around)["amenity"="toilets"]'
            '["wheelchair"~"^(yes|designated|limited)\$"];'
            'nwr($around)["toilets:wheelchair"~"^(yes|designated)\$"];',
      AlongRouteCategory.benches =>
        'node($around)["amenity"="bench"];'
            'node($around)["highway"="bus_stop"]["bench"="yes"];',
      AlongRouteCategory.water =>
        'nwr($around)["amenity"="drinking_water"];'
            'nwr($around)["amenity"="water_point"];',
    };
    return '[out:json][timeout:15];($filters);out center 200;';
  }

  /// Al massimo [max] punti presi a intervalli regolari, con il primo e
  /// l'ultimo.
  @visibleForTesting
  static List<LatLng> samplePoints(List<LatLng> route, int max) {
    if (route.length <= max) return route;
    final step = (route.length - 1) / (max - 1);
    return [for (var i = 0; i < max; i++) route[(i * step).round()]];
  }

  @visibleForTesting
  static List<AlongRoutePlace> parse(
    AlongRouteCategory category,
    Map<String, dynamic> data,
    List<LatLng> route,
  ) {
    final elements = data['elements'];
    if (elements is! List) return const [];

    // Distanza progressiva lungo il percorso per ogni punto del tracciato.
    final along = <double>[0];
    for (var i = 1; i < route.length; i++) {
      along.add(along.last + haversineDistance(route[i - 1], route[i]));
    }

    final seen = <String>{};
    final places = <AlongRoutePlace>[];
    for (final element in elements.whereType<Map<String, dynamic>>()) {
      final key = '${element['type']}${element['id']}';
      if (!seen.add(key)) continue;
      final tags = element['tags'];
      if (tags is! Map<String, dynamic>) continue;
      final center = element['center'];
      final source = center is Map<String, dynamic> ? center : element;
      final lat = source['lat'];
      final lon = source['lon'];
      if (lat is! num || lon is! num) continue;
      final position = LatLng(lat.toDouble(), lon.toDouble());
      if (category == AlongRouteCategory.benches &&
          places.any(
            (p) => haversineDistance(p.position, position) < _mergeMeters,
          )) {
        continue;
      }
      places.add(
        AlongRoutePlace(
          category: category,
          position: position,
          name: _name(category, tags),
          metersFromStart: along[nearestPointIndex(route, position)],
          isLimited:
              category == AlongRouteCategory.toilets &&
              (tags['amenity'] == 'toilets'
                      ? tags['wheelchair']
                      : tags['toilets:wheelchair']) ==
                  'limited',
        ),
      );
    }
    places.sort((a, b) => a.metersFromStart.compareTo(b.metersFromStart));
    return places.sublist(0, math.min(places.length, maxResults));
  }

  static String _name(AlongRouteCategory category, Map<String, dynamic> tags) {
    final name = tags['name'] as String?;
    switch (category) {
      case AlongRouteCategory.toilets:
        return name ??
            (tags['amenity'] == 'toilets'
                ? 'Bagno pubblico'
                : 'Bagno accessibile');
      case AlongRouteCategory.benches:
        if (tags['highway'] == 'bus_stop') {
          return name == null ? 'Fermata con panchina' : 'Fermata $name';
        }
        return tags['backrest'] == 'no'
            ? 'Panchina senza schienale'
            : 'Panchina';
      case AlongRouteCategory.water:
        return name ?? 'Fontanella';
    }
  }

  void dispose() => _client.close();
}
