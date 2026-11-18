import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import '../models/route_option.dart';
import '../models/travel_mode.dart';
import 'arrival_side.dart';
import 'geo_utils.dart';
import 'route_warnings.dart';

const String kUserAgent = 'FreeWayApp/2.0 (freeway-accessibility-app)';

/// Chiave di OpenRouteService, passata in fase di build con
/// `--dart-define=ORS_API_KEY=...`. Se manca si usa solo OSRM.
const String kOrsApiKey = String.fromEnvironment('ORS_API_KEY');

/// Calcola percorsi pedonali tenendo conto degli ostacoli segnalati.
///
/// Con una chiave di OpenRouteService usa il profilo `wheelchair` (che evita
/// gradini, pendenze e fondi sconnessi) e passa gli ostacoli come zone da
/// evitare. Senza chiave, o se OpenRouteService non risponde, usa il profilo
/// pedonale di OSRM con una deviazione intorno al primo ostacolo.
///
/// Con [TravelMode.walking] cerca invece il percorso a piedi più veloce
/// (profilo `foot-walking` di OpenRouteService o pedonale di OSRM) e si limita
/// a contare gli ostacoli lungo il tragitto.
class RoutingService {
  RoutingService({http.Client? client, String orsApiKey = kOrsApiKey})
      : _client = client ?? http.Client(),
        _orsApiKey = orsApiKey;

  final http.Client _client;
  final String _orsApiKey;

  /// Raggio (in metri) entro cui un ostacolo è considerato sul percorso.
  static const double obstacleRadius = 30;

  /// Metà del lato (in metri) dell'area da evitare intorno a un ostacolo.
  static const double avoidHalfSide = 15;

  /// Massimo numero di ostacoli passati a OpenRouteService per richiesta.
  static const int maxAvoidedObstacles = 100;

  bool get usesWheelchairProfile => _orsApiKey.isNotEmpty;

  Future<List<RouteOption>> getRoutes(
    LatLng start,
    LatLng end,
    List<Obstacle> obstacles, {
    TravelMode mode = TravelMode.wheelchair,
    List<LatLng> via = const [],
  }) async {
    final walking = mode == TravelMode.walking;
    // Tappe intermedie scelte dall'utente, come "Add stop" di Google Maps.
    final waypoints = [start, ...via, end];
    var candidates = <RouteOption>[];
    if (usesWheelchairProfile) {
      try {
        candidates = walking
            ? await _fetchOrsRoutes(waypoints,
                alternatives: true, profile: 'foot-walking')
            : await _orsCandidates(waypoints, obstacles);
      } catch (_) {
        candidates = [];
      }
    }
    if (candidates.isEmpty) {
      candidates = walking || via.isNotEmpty
          ? await _fetchRoutes(waypoints, alternatives: 3)
          : await _osrmCandidates(start, end, obstacles);
    }
    if (candidates.isEmpty) throw Exception('Nessun percorso trovato');

    for (final route in candidates) {
      route.obstacleCount = _countObstacles(route.points, obstacles);
      // "La destinazione è sulla sinistra/destra", come in Google Maps.
      applyArrivalSide(route, end);
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

    if (walking) {
      unique.sort((a, b) => a.duration.compareTo(b.duration));
      for (var i = 0; i < unique.length; i++) {
        unique[i].isRecommended = i == 0;
        unique[i].label = i == 0 ? 'Più veloce' : 'Alternativa ${i + 1}';
      }
      return unique;
    }

    // In sedia a rotelle conta prima evitare ostacoli segnalati, poi gradini,
    // salite ripide e lavori, infine la lunghezza.
    unique.sort((a, b) {
      final byObstacles = a.obstacleCount.compareTo(b.obstacleCount);
      if (byObstacles != 0) return byObstacles;
      final byWarnings = a.hardWarningCount.compareTo(b.hardWarningCount);
      if (byWarnings != 0) return byWarnings;
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

  /// Percorsi pedonali OSRM, più una deviazione intorno al primo ostacolo.
  Future<List<RouteOption>> _osrmCandidates(
    LatLng start,
    LatLng end,
    List<Obstacle> obstacles,
  ) async {
    final routes = await _fetchRoutes([start, end], alternatives: 3);
    if (routes.isEmpty) return [];

    final candidates = List<RouteOption>.of(routes);
    final best = candidates.first;
    final obstacle = _firstObstacleOnRoute(best.points, obstacles);
    if (obstacle != null) {
      final detour =
          await _findDetour(start, end, obstacle, best.points, obstacles);
      if (detour != null) candidates.add(detour);
    }
    return candidates;
  }

  // --- OpenRouteService -----------------------------------------------------

  /// Due richieste in parallelo: una con le alternative e una che evita le
  /// aree degli ostacoli (le alternative non sempre le rispettano).
  Future<List<RouteOption>> _orsCandidates(
    List<LatLng> waypoints,
    List<Obstacle> obstacles,
  ) async {
    final nearbyIds = <String>{};
    final nearby = <Obstacle>[];
    for (var i = 1; i < waypoints.length; i++) {
      for (final o in obstaclesNear(waypoints[i - 1], waypoints[i], obstacles)) {
        if (nearbyIds.add(o.id)) nearby.add(o);
      }
    }
    final avoid = nearby.take(maxAvoidedObstacles).toList();
    final requests = <Future<List<RouteOption>>>[
      _fetchOrsRoutes(waypoints, alternatives: true),
      if (avoid.isNotEmpty) _fetchOrsRoutes(waypoints, avoid: avoid),
    ];
    final results = await Future.wait(
      requests.map((r) => r.catchError((Object _) => <RouteOption>[])),
    );
    return [for (final routes in results) ...routes];
  }

  Future<List<RouteOption>> _fetchOrsRoutes(
    List<LatLng> waypoints, {
    bool alternatives = false,
    List<Obstacle> avoid = const [],
    String profile = 'wheelchair',
  }) async {
    final body = <String, dynamic>{
      'coordinates': [
        for (final p in waypoints) [p.longitude, p.latitude],
      ],
      'instructions': true,
      'units': 'm',
      'extra_info': kOrsExtraInfo,
      // OpenRouteService dà alternative solo tra due punti.
      if (alternatives && waypoints.length == 2)
        'alternative_routes': {
          'target_count': 3,
          'share_factor': 0.6,
          'weight_factor': 1.6,
        },
      if (avoid.isNotEmpty)
        'options': {'avoid_polygons': avoidPolygons(avoid)},
    };
    final response = await _client.post(
      Uri.parse(
        'https://api.openrouteservice.org/v2/directions/$profile/geojson',
      ),
      headers: {
        'Authorization': _orsApiKey,
        'Content-Type': 'application/json',
        'Accept': 'application/geo+json, application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) return [];
    return parseOrsRoutes(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Ostacoli nel rettangolo tra partenza e arrivo, allargato di circa 1 km,
  /// ordinati dal più vicino al punto medio del tragitto.
  @visibleForTesting
  static List<Obstacle> obstaclesNear(
    LatLng start,
    LatLng end,
    List<Obstacle> obstacles,
  ) {
    const margin = 0.01;
    final minLat = math.min(start.latitude, end.latitude) - margin;
    final maxLat = math.max(start.latitude, end.latitude) + margin;
    final minLng = math.min(start.longitude, end.longitude) - margin;
    final maxLng = math.max(start.longitude, end.longitude) + margin;
    final inside = obstacles.where((o) {
      final p = o.position;
      return p.latitude >= minLat &&
          p.latitude <= maxLat &&
          p.longitude >= minLng &&
          p.longitude <= maxLng;
    }).toList();
    final middle = LatLng(
      (start.latitude + end.latitude) / 2,
      (start.longitude + end.longitude) / 2,
    );
    inside.sort((a, b) => haversineDistance(a.position, middle)
        .compareTo(haversineDistance(b.position, middle)));
    return inside.take(maxAvoidedObstacles).toList();
  }

  /// Un quadrato di lato `2 * avoidHalfSide` metri intorno a ogni ostacolo,
  /// nel formato GeoJSON `MultiPolygon` richiesto da OpenRouteService.
  @visibleForTesting
  static Map<String, dynamic> avoidPolygons(List<Obstacle> obstacles) {
    return {
      'type': 'MultiPolygon',
      'coordinates': [
        for (final obstacle in obstacles) [_square(obstacle.position)],
      ],
    };
  }

  static List<List<double>> _square(LatLng center) {
    final dLat = avoidHalfSide / 111320;
    final dLng =
        avoidHalfSide / (111320 * math.cos(center.latitude * math.pi / 180));
    final south = center.latitude - dLat;
    final north = center.latitude + dLat;
    final west = center.longitude - dLng;
    final east = center.longitude + dLng;
    return [
      [west, south],
      [east, south],
      [east, north],
      [west, north],
      [west, south],
    ];
  }

  /// Converte la risposta GeoJSON di OpenRouteService in [RouteOption],
  /// con le manovre nello stesso formato di OSRM.
  @visibleForTesting
  static List<RouteOption> parseOrsRoutes(Map<String, dynamic> data) {
    final features = data['features'] as List? ?? const [];
    final result = <RouteOption>[];
    for (var i = 0; i < features.length; i++) {
      final feature = features[i] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final points = (geometry['coordinates'] as List)
          .map<LatLng>((c) => LatLng(
                ((c as List)[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
      if (points.length < 2) continue;

      final properties = feature['properties'] as Map<String, dynamic>;
      final summary =
          properties['summary'] as Map<String, dynamic>? ?? const {};
      final legs = <List<RouteStep>>[];
      for (final segment in properties['segments'] as List? ?? const []) {
        final steps = <RouteStep>[];
        legs.add(steps);
        final rawSteps = (segment as Map)['steps'] as List? ?? const [];
        for (final rawStep in rawSteps) {
          final step = rawStep as Map<String, dynamic>;
          final (type, modifier) =
              _orsManeuver((step['type'] as num?)?.toInt());
          var name = (step['name'] as String?) ?? '';
          if (name == '-') name = '';
          final wayPoints = step['way_points'] as List? ?? const [0];
          final index =
              (wayPoints.first as num).toInt().clamp(0, points.length - 1);
          steps.add(RouteStep(
            instruction: '$type|$modifier|$name',
            location: points[index],
            maneuverType: type,
            modifier: modifier,
            streetName: name,
            distance: (step['distance'] as num?)?.toDouble() ?? 0,
            duration: (step['duration'] as num?)?.toDouble() ?? 0,
          ));
        }
      }
      final steps = joinLegs(legs, keepStops: true);

      final route = RouteOption(
        points: points,
        distance: (summary['distance'] as num?)?.toDouble() ?? 0,
        duration: (summary['duration'] as num?)?.toDouble() ?? 0,
        steps: steps,
        index: i,
      );
      final extras = properties['extras'];
      if (extras is Map<String, dynamic>) {
        route
          ..warnings = parseRouteWarnings(extras, points)
          ..hasTerrainData = true;
      }
      result.add(route);
    }
    return result;
  }

  /// Tipi di manovra di OpenRouteService tradotti in tipo e modificatore OSRM.
  static (String, String) _orsManeuver(int? type) {
    switch (type) {
      case 0:
        return ('turn', 'left');
      case 1:
        return ('turn', 'right');
      case 2:
        return ('turn', 'sharp left');
      case 3:
        return ('turn', 'sharp right');
      case 4:
        return ('turn', 'slight left');
      case 5:
        return ('turn', 'slight right');
      case 7:
        return ('roundabout', '');
      case 8:
        return ('exit roundabout', '');
      case 9:
        return ('turn', 'uturn');
      case 10:
        return ('arrive', '');
      case 11:
        return ('depart', '');
      case 12:
        return ('fork', 'slight left');
      case 13:
        return ('fork', 'slight right');
      default:
        return ('continue', 'straight');
    }
  }

  // --- OSRM -----------------------------------------------------------------

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
          final routes =
              await _fetchRoutes([start, waypoint, end], userStops: false);
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

  /// Con [userStops] i punti intermedi sono tappe scelte dall'utente
  /// ("Hai raggiunto la tappa"); altrimenti servono solo a deviare il
  /// percorso e le loro manovre vengono tolte.
  Future<List<RouteOption>> _fetchRoutes(
    List<LatLng> waypoints, {
    int alternatives = 0,
    bool userStops = true,
  }) async {
    final coordinates =
        waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');
    var url = 'https://router.project-osrm.org/route/v1/foot/$coordinates'
        '?overview=full&geometries=geojson&steps=true';
    // OSRM dà alternative solo tra due punti.
    if (alternatives > 0 && waypoints.length == 2) {
      url += '&alternatives=$alternatives';
    }

    final response =
        await _client.get(Uri.parse(url), headers: {'User-Agent': kUserAgent});
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

      final legs = <List<RouteStep>>[];
      for (final leg in route['legs'] as List) {
        final steps = <RouteStep>[];
        legs.add(steps);
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
      final steps = joinLegs(legs, keepStops: userStops);

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

  /// Unisce le manovre dei tratti tra un punto e l'altro. L'arrivo a un
  /// punto intermedio diventa "Hai raggiunto la tappa" ([keepStops]) o
  /// sparisce, e la partenza del tratto dopo diventa "Prosegui".
  @visibleForTesting
  static List<RouteStep> joinLegs(
    List<List<RouteStep>> legs, {
    required bool keepStops,
  }) {
    if (legs.isEmpty) return [];
    if (legs.length == 1) return legs.first;
    RouteStep as(RouteStep step, String type, String modifier) => RouteStep(
      instruction: '$type|$modifier|${step.streetName}',
      location: step.location,
      maneuverType: type,
      modifier: modifier,
      streetName: step.streetName,
      distance: step.distance,
      duration: step.duration,
    );
    final joined = <RouteStep>[];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      for (var j = 0; j < leg.length; j++) {
        final step = leg[j];
        final isIntermediateArrival = i < legs.length - 1 &&
            j == leg.length - 1 &&
            step.maneuverType == 'arrive';
        if (isIntermediateArrival) {
          if (keepStops) joined.add(as(step, 'stop', ''));
          continue;
        }
        if (i > 0 && j == 0 && step.maneuverType == 'depart') {
          joined.add(as(step, 'continue', 'straight'));
          continue;
        }
        joined.add(step);
      }
    }
    return joined;
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
