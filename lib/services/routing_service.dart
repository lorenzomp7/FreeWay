import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import '../models/route_option.dart';
import 'geo_utils.dart';

const String kUserAgent = 'FreeWayApp/2.0 (freeway-accessibility-app)';

/// Calcola percorsi pedonali con OSRM tenendo conto degli ostacoli segnalati.
class RoutingService {
  /// Raggio (in metri) entro cui un ostacolo è considerato sul percorso.
  static const double obstacleRadius = 30;

  Future<List<RouteOption>> getRoutes(
    LatLng start,
    LatLng end,
    List<Obstacle> obstacles,
  ) async {
    final routes = await _fetchRoutes([start, end], alternatives: 3);
    if (routes.isEmpty) throw Exception('Nessun percorso trovato');

    for (final route in routes) {
      route.obstacleCount = _countObstacles(route.points, obstacles);
    }

    final candidates = List<RouteOption>.of(routes);
    final best = candidates.first;
    if (best.obstacleCount > 0 && obstacles.isNotEmpty) {
      final points = best.points;
      final obstacle = _firstObstacleOnRoute(points, obstacles);
      if (obstacle != null) {
        final detour =
            await _findDetour(start, end, obstacle, points, obstacles);
        if (detour != null) candidates.add(detour);
      }
    }

    // Rimuove i percorsi praticamente identici.
    final unique = <RouteOption>[];
    for (final route in candidates) {
      final duplicate = unique.any(
        (other) =>
            (other.distance - route.distance).abs() < 15 &&
            haversineDistance(other.points.first, route.points.first) < 10,
      );
      if (!duplicate) unique.add(route);
    }

    unique.sort((a, b) {
      final byObstacles = a.obstacleCount.compareTo(b.obstacleCount);
      if (byObstacles != 0) return byObstacles;
      return a.distance.compareTo(b.distance);
    });

    final shortest = unique.map((r) => r.distance).reduce(math.min);
    for (var i = 0; i < unique.length; i++) {
      final route = unique[i];
      if (i == 0 &&
          route.obstacleCount == 0 &&
          unique.any((r) => r.obstacleCount > 0)) {
        route.isRecommended = true;
        route.label = 'Evita ostacoli';
      } else if (i == 0) {
        route.isRecommended = true;
        route.label = 'Consigliato';
      } else if (route.distance <= shortest + 10) {
        route.label = 'Più corto';
      } else {
        route.label = 'Alternativa ${i + 1}';
      }
    }
    return unique;
  }

  /// Prova a passare a lato dell'ostacolo aggiungendo un punto intermedio.
  Future<RouteOption?> _findDetour(
    LatLng start,
    LatLng end,
    Obstacle obstacle,
    List<LatLng> routePoints,
    List<Obstacle> obstacles,
  ) async {
    final target = obstacle.position;

    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < routePoints.length; i++) {
      final d = haversineDistance(routePoints[i], target);
      if (d < nearestDistance) {
        nearestDistance = d;
        nearestIndex = i;
      }
    }

    // Direzione del percorso vicino all'ostacolo e relativa perpendicolare.
    final before = routePoints[math.max(0, nearestIndex - 5)];
    final after = routePoints[math.min(routePoints.length - 1, nearestIndex + 5)];
    final dLat = after.latitude - before.latitude;
    final dLng = after.longitude - before.longitude;
    final length = math.sqrt(dLat * dLat + dLng * dLng);
    final perpY = length > 0 ? -dLng / length : 0.0;
    final perpX = length > 0 ? dLat / length : 1.0;

    final originalCount = _countObstacles(routePoints, obstacles);
    final detours = <RouteOption>[];
    const offsets = [0.0016, 0.0026, 0.0036];

    for (final offset in offsets) {
      final shifts = <math.Point<double>>[
        math.Point(perpX * offset, perpY * offset),
        math.Point(-perpX * offset, -perpY * offset),
        math.Point(0, offset),
        math.Point(0, -offset),
        math.Point(offset, 0),
        math.Point(-offset, 0),
      ];

      for (final shift in shifts) {
        final waypoint =
            LatLng(target.latitude + shift.y, target.longitude + shift.x);
        try {
          final routes = await _fetchRoutes([start, waypoint, end]);
          if (routes.isNotEmpty) {
            final candidate = routes.first;
            final clearance = candidate.points
                .map((p) => haversineDistance(p, target))
                .reduce(math.min);
            if (clearance > 35) {
              final count = _countObstacles(candidate.points, obstacles);
              if (count < originalCount) {
                candidate.obstacleCount = count;
                candidate.label = 'Evita ostacoli';
                detours.add(candidate);
                if (count == 0) break;
              }
            }
          }
        } catch (_) {
          // Si prova con il punto successivo.
        }
      }
      if (detours.any((r) => r.obstacleCount == 0)) break;
    }

    if (detours.isEmpty) return null;
    detours.sort((a, b) {
      final byObstacles = a.obstacleCount.compareTo(b.obstacleCount);
      if (byObstacles != 0) return byObstacles;
      return a.distance.compareTo(b.distance);
    });
    return detours.first;
  }

  Future<List<RouteOption>> _fetchRoutes(
    List<LatLng> waypoints, {
    int alternatives = 0,
  }) async {
    final coordinates =
        waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    var url = 'https://router.project-osrm.org/route/v1/foot/$coordinates'
        '?overview=full&geometries=geojson&steps=true';
    if (alternatives > 0) url += '&alternatives=$alternatives';

    final response =
        await http.get(Uri.parse(url), headers: {'User-Agent': kUserAgent});
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];

    final result = <RouteOption>[];
    for (var i = 0; i < routes.length; i++) {
      final route = routes[i] as Map<String, dynamic>;
      final points = (route['geometry']['coordinates'] as List)
          .map<LatLng>((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      final steps = <RouteStep>[];
      for (final leg in route['legs'] as List) {
        for (final rawStep in leg['steps'] as List) {
          final step = rawStep as Map<String, dynamic>;
          final maneuver = step['maneuver'] as Map<String, dynamic>;
          final location = maneuver['location'] as List;
          final type = (maneuver['type'] as String?) ?? '';
          final modifier = (maneuver['modifier'] as String?) ?? '';
          final name = (step['name'] as String?) ?? '';
          steps.add(RouteStep(
            instruction: '$type|$modifier|$name',
            location: LatLng(
              (location[1] as num).toDouble(),
              (location[0] as num).toDouble(),
            ),
            maneuverType: type,
            modifier: modifier,
            streetName: name,
            distance: (step['distance'] as num).toDouble(),
            duration: (step['duration'] as num).toDouble(),
          ));
        }
      }

      result.add(RouteOption(
        points: points,
        distance: (route['distance'] as num).toDouble(),
        duration: (route['duration'] as num).toDouble(),
        steps: steps,
        index: i,
      ));
    }
    return result;
  }

  Obstacle? _firstObstacleOnRoute(List<LatLng> points, List<Obstacle> obstacles) {
    for (final obstacle in obstacles) {
      for (var i = 0; i < points.length; i += 3) {
        if (haversineDistance(points[i], obstacle.position) <= obstacleRadius) {
          return obstacle;
        }
      }
    }
    return null;
  }

  int _countObstacles(List<LatLng> points, List<Obstacle> obstacles) {
    var count = 0;
    for (final obstacle in obstacles) {
      for (var i = 0; i < points.length; i += 3) {
        if (haversineDistance(points[i], obstacle.position) <= obstacleRadius) {
          count++;
          break;
        }
      }
    }
    return count;
  }
}
