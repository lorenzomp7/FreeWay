import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'geo_utils.dart';
import 'obstacle_alerts.dart' show nearestPointIndex;

/// Un bagno accessibile in sedia a rotelle vicino al percorso.
class AccessibleToilet {
  const AccessibleToilet({
    required this.position,
    required this.name,
    required this.metersFromStart,
    this.isLimited = false,
    this.openingHours,
  });

  final LatLng position;

  /// Nome del locale o "Bagno pubblico".
  final String name;

  /// Distanza lungo il percorso dalla partenza al punto più vicino al bagno.
  final double metersFromStart;

  /// Accessibilità solo parziale (`wheelchair=limited`).
  final bool isLimited;
  final String? openingHours;
}

/// Cerca lungo il percorso, come "Search along route" di Google Maps; per
/// FreeWay la ricerca utile sono i bagni accessibili, letti da OpenStreetMap
/// tramite Overpass.
class AlongRouteService {
  AlongRouteService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final Uri endpoint = Uri.https('overpass-api.de', '/api/interpreter');

  /// Distanza massima dal percorso, in metri.
  static const int corridorMeters = 80;

  /// Punti del percorso passati a Overpass: bastano per un corridoio di 80 m
  /// e tengono corta la richiesta.
  static const int maxQueryPoints = 40;

  /// `null` se Overpass non risponde; lista vuota se non ci sono bagni.
  Future<List<AccessibleToilet>?> accessibleToilets(List<LatLng> route) async {
    if (route.length < 2) return const [];
    try {
      // Modulo semplice, senza intestazioni in più: nel browser non serve il
      // controllo preventivo CORS.
      final response = await _client
          .post(endpoint, body: {'data': buildQuery(route)})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) return null;
      return parse(data, route);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static String buildQuery(List<LatLng> route) {
    final points = samplePoints(route, maxQueryPoints)
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(6)},'
              '${p.longitude.toStringAsFixed(6)}',
        )
        .join(',');
    final around = 'around:$corridorMeters,$points';
    return '[out:json][timeout:15];('
        'nwr($around)["amenity"="toilets"]'
        '["wheelchair"~"^(yes|designated|limited)\$"];'
        'nwr($around)["toilets:wheelchair"~"^(yes|designated)\$"];'
        ');out center 30;';
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
  static List<AccessibleToilet> parse(
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
    final toilets = <AccessibleToilet>[];
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
      final name =
          (tags['name'] as String?) ??
          (tags['amenity'] == 'toilets'
              ? 'Bagno pubblico'
              : 'Bagno accessibile');
      final wheelchair = tags['amenity'] == 'toilets'
          ? tags['wheelchair']
          : tags['toilets:wheelchair'];
      toilets.add(
        AccessibleToilet(
          position: position,
          name: name,
          metersFromStart: along[nearestPointIndex(route, position)],
          isLimited: wheelchair == 'limited',
          openingHours: tags['opening_hours'] as String?,
        ),
      );
    }
    toilets.sort((a, b) => a.metersFromStart.compareTo(b.metersFromStart));
    return toilets.sublist(0, math.min(toilets.length, 30));
  }

  void dispose() => _client.close();
}
