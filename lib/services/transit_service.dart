import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import '../models/route_option.dart';
import '../models/transit.dart';
import 'geo_utils.dart';
import 'routing_service.dart';

/// Errore del servizio dei mezzi pubblici, con un testo da mostrare.
class TransitException implements Exception {
  const TransitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Percorsi con i mezzi pubblici accessibili in sedia a rotelle, da
/// Transitous (https://transitous.org): un servizio gratuito e mondiale,
/// gestito da volontari con il motore open source MOTIS.
///
/// Regole d'uso di Transitous rispettate qui:
/// - solo l'indirizzo pubblico `api.transitous.org`, mai quello di prova;
/// - poche richieste: una cache di 2 minuti e almeno 5 secondi tra due
///   richieste (oltre 720 al giorno bisogna parlarne con loro);
/// - link visibile alle fonti ([sourcesUrl]) dove si mostrano i risultati.
class TransitService {
  TransitService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;

  static final Uri endpoint = Uri.https('api.transitous.org', '/api/v5/plan');

  /// Pagina delle fonti dei dati, da linkare in modo visibile.
  static const String sourcesUrl = 'https://transitous.org/sources/';

  static const Duration cacheLifetime = Duration(minutes: 2);
  static const Duration minInterval = Duration(seconds: 5);
  static const Duration _timeout = Duration(seconds: 20);

  final Map<String, (DateTime, List<RouteOption>)> _cache = {};
  DateTime? _lastRequest;

  /// I collegamenti da [from] a [to] in partenza adesso, con i tratti a
  /// piedi accessibili in sedia a rotelle. Prima quelli con tutti i mezzi
  /// accessibili, in fondo quelli con un mezzo che non lo è.
  Future<List<RouteOption>> plan(
    LatLng from,
    LatLng to, {
    List<Obstacle> obstacles = const [],
  }) async {
    final key = '${_place(from)}|${_place(to)}';
    final cached = _cache[key];
    final now = _clock();
    if (cached != null && now.difference(cached.$1) < cacheLifetime) {
      return cached.$2;
    }
    final last = _lastRequest;
    if (last != null) {
      final wait = minInterval - now.difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequest = _clock();

    final http.Response response;
    try {
      response = await _client.get(requestUri(from, to)).timeout(_timeout);
    } catch (_) {
      throw const TransitException(
        'Il servizio dei mezzi pubblici non risponde. Riprova tra poco.',
      );
    }
    if (response.statusCode == 429 || response.statusCode == 403) {
      throw const TransitException(
        'Troppe richieste ai mezzi pubblici: riprova tra poco.',
      );
    }
    if (response.statusCode != 200) {
      throw const TransitException(
        'Il servizio dei mezzi pubblici non risponde. Riprova tra poco.',
      );
    }
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const TransitException(
        'Risposta non valida dal servizio dei mezzi pubblici.',
      );
    }
    final routes = parse(data, obstacles: obstacles);
    _cache[key] = (_clock(), routes);
    return routes;
  }

  static String _place(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';

  /// Richiesta a MOTIS: profilo sedia a rotelle per i tratti a piedi e i
  /// cambi, indicazioni dettagliate, testi in italiano.
  @visibleForTesting
  static Uri requestUri(LatLng from, LatLng to) => endpoint.replace(
    queryParameters: {
      'fromPlace': _place(from),
      'toPlace': _place(to),
      'pedestrianProfile': 'WHEELCHAIR',
      'detailedTransfers': 'true',
      'language': 'it',
    },
  );

  /// Trasforma la risposta di `/plan` in percorsi per la scheda e la
  /// navigazione.
  @visibleForTesting
  static List<RouteOption> parse(
    Object? data, {
    List<Obstacle> obstacles = const [],
  }) {
    if (data is! Map<String, dynamic>) return const [];
    final itineraries = data['itineraries'];
    if (itineraries is! List) return const [];
    final routes = <RouteOption>[];
    for (final item in itineraries.whereType<Map<String, dynamic>>()) {
      final route = _itinerary(item, routes.length, obstacles);
      if (route != null) routes.add(route);
    }
    // Prima i viaggi con tutti i mezzi accessibili, poi quelli senza dati,
    // in fondo quelli con un mezzo non accessibile; a parità, chi arriva
    // prima.
    int rank(RouteOption r) => switch (overallAccess(r.transitLegs)) {
      TransitAccess.accessible => 0,
      TransitAccess.unknown => 1,
      TransitAccess.notAccessible => 2,
    };
    routes.sort((a, b) {
      final byAccess = rank(a).compareTo(rank(b));
      if (byAccess != 0) return byAccess;
      return a.arrivalTime!.compareTo(b.arrivalTime!);
    });
    final sorted = [
      for (var i = 0; i < routes.length; i++) _withIndex(routes[i], i),
    ];
    if (sorted.isNotEmpty &&
        overallAccess(sorted.first.transitLegs) !=
            TransitAccess.notAccessible) {
      sorted.first
        ..isRecommended = true
        ..label = 'Consigliato';
    }
    return sorted;
  }

  static RouteOption _withIndex(RouteOption r, int index) =>
      RouteOption(
          points: r.points,
          distance: r.distance,
          duration: r.duration,
          steps: r.steps,
          index: index,
        )
        ..obstacleCount = r.obstacleCount
        ..warnings = r.warnings
        ..provider = r.provider
        ..transitLegs = r.transitLegs
        ..departureTime = r.departureTime
        ..arrivalTime = r.arrivalTime;

  static RouteOption? _itinerary(
    Map<String, dynamic> item,
    int index,
    List<Obstacle> obstacles,
  ) {
    final start = _time(item['startTime']);
    final end = _time(item['endTime']);
    final rawLegs = item['legs'];
    if (start == null || end == null || rawLegs is! List) return null;

    final legs = <TransitLeg>[];
    final steps = <RouteStep>[];
    final points = <LatLng>[];
    final walkPoints = <LatLng>[];
    var distance = 0.0;
    var stairsMeters = 0.0;

    for (final raw in rawLegs.whereType<Map<String, dynamic>>()) {
      final leg = _leg(raw);
      if (leg == null) continue;
      legs.add(leg);
      points.addAll(leg.points);
      if (leg.isWalk) {
        walkPoints.addAll(leg.points);
        distance += leg.distance > 0 ? leg.distance : _length(leg.points);
        stairsMeters += _walkSteps(raw, leg, steps, first: steps.isEmpty);
      } else {
        distance += _length(leg.points);
        steps
          ..add(
            RouteStep(
              instruction:
                  'board|${leg.vehicle.name}|'
                  '${leg.line}\t${leg.headsign}\t${leg.fromName}',
              location: leg.points.first,
              maneuverType: 'board',
              modifier: leg.vehicle.name,
              streetName: leg.fromName,
              distance: _length(leg.points),
              duration: leg.duration.inSeconds.toDouble(),
            ),
          )
          ..add(
            RouteStep(
              instruction: 'alight|${leg.vehicle.name}|${leg.toName}',
              location: leg.points.last,
              maneuverType: 'alight',
              modifier: leg.vehicle.name,
              streetName: leg.toName,
            ),
          );
      }
    }
    if (legs.isEmpty || points.length < 2) return null;
    steps.add(
      RouteStep(
        instruction: 'arrive||${legs.last.toName}',
        location: points.last,
        maneuverType: 'arrive',
        modifier: '',
        streetName: legs.last.toName,
      ),
    );

    final duration =
        (item['duration'] as num?)?.toDouble() ??
        end.difference(start).inSeconds.toDouble();
    return RouteOption(
        points: points,
        distance: distance,
        duration: duration,
        steps: steps,
        index: index,
      )
      ..provider = 'transitous'
      ..transitLegs = legs
      ..departureTime = start
      ..arrivalTime = end
      // MOTIS non conosce le segnalazioni: le contiamo sui tratti a piedi.
      ..obstacleCount = RoutingService.countObstaclesAlong(
        walkPoints,
        obstacles,
      )
      ..warnings = [
        if (stairsMeters > 0)
          RouteWarning(RouteWarningKind.steps, stairsMeters),
      ];
  }

  static TransitLeg? _leg(Map<String, dynamic> raw) {
    final from = raw['from'];
    final to = raw['to'];
    final start = _time(raw['startTime']);
    final end = _time(raw['endTime']);
    if (from is! Map<String, dynamic> ||
        to is! Map<String, dynamic> ||
        start == null ||
        end == null) {
      return null;
    }
    final fromPoint = _point(from);
    final toPoint = _point(to);
    if (fromPoint == null || toPoint == null) return null;
    var points = _geometry(raw['legGeometry']);
    if (points.length < 2) points = [fromPoint, toPoint];
    final vehicle = TransitVehicle.fromMode(raw['mode'] as String?);
    final line =
        (raw['routeShortName'] ?? raw['displayName'] ?? raw['tripShortName'])
            as String? ??
        '';
    final stops = raw['intermediateStops'];
    return TransitLeg(
      vehicle: vehicle,
      line: line.trim(),
      headsign: (raw['headsign'] as String? ?? '').trim(),
      fromName: (from['name'] as String? ?? '').trim(),
      toName: (to['name'] as String? ?? '').trim(),
      departure: start,
      arrival: end,
      points: points,
      agency: (raw['agencyName'] as String? ?? '').trim(),
      access: switch (raw['wheelchairAccessible']) {
        'ACCESSIBLE' => TransitAccess.accessible,
        'NOT_ACCESSIBLE' => TransitAccess.notAccessible,
        _ => TransitAccess.unknown,
      },
      distance: (raw['distance'] as num?)?.toDouble() ?? 0,
      stops: stops is List ? stops.length : 0,
    );
  }

  /// Le indicazioni di un tratto a piedi, dalle istruzioni di MOTIS.
  /// Restituisce i metri di scale incontrati (non dovrebbero esserci con il
  /// profilo sedia a rotelle, ma se ci sono va detto).
  static double _walkSteps(
    Map<String, dynamic> raw,
    TransitLeg leg,
    List<RouteStep> out, {
    required bool first,
  }) {
    final rawSteps = raw['steps'];
    final instructions = rawSteps is List
        ? rawSteps.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];
    final seconds = leg.duration.inSeconds.toDouble();
    final meters = leg.distance > 0 ? leg.distance : _length(leg.points);
    var stairs = 0.0;
    if (instructions.isEmpty) {
      out.add(
        RouteStep(
          instruction: first ? 'depart||' : 'continue|straight|',
          location: leg.points.first,
          maneuverType: first ? 'depart' : 'continue',
          modifier: first ? '' : 'straight',
          distance: meters,
          duration: seconds,
        ),
      );
      return 0;
    }
    for (var i = 0; i < instructions.length; i++) {
      final step = instructions[i];
      final direction = step['relativeDirection'] as String? ?? 'CONTINUE';
      final street = (step['streetName'] as String? ?? '').trim();
      final length = (step['distance'] as num?)?.toDouble() ?? 0;
      if (direction == 'STAIRS') stairs += length;
      final stepPoints = _geometry(step['polyline']);
      final (type, modifier) = (first && i == 0)
          ? ('depart', '')
          : _maneuver(direction);
      out.add(
        RouteStep(
          instruction: '$type|$modifier|$street',
          location: stepPoints.isNotEmpty ? stepPoints.first : leg.points.first,
          maneuverType: type,
          modifier: modifier,
          streetName: street,
          distance: length,
          duration: meters > 0 ? seconds * length / meters : 0,
        ),
      );
    }
    return stairs;
  }

  static (String, String) _maneuver(String direction) => switch (direction) {
    'DEPART' => ('continue', 'straight'),
    'HARD_LEFT' => ('turn', 'sharp left'),
    'LEFT' => ('turn', 'left'),
    'SLIGHTLY_LEFT' => ('turn', 'slight left'),
    'SLIGHTLY_RIGHT' => ('turn', 'slight right'),
    'RIGHT' => ('turn', 'right'),
    'HARD_RIGHT' => ('turn', 'sharp right'),
    'CIRCLE_CLOCKWISE' || 'CIRCLE_COUNTERCLOCKWISE' => ('roundabout', ''),
    'UTURN_LEFT' || 'UTURN_RIGHT' => ('turn', 'uturn'),
    'ELEVATOR' => ('elevator', ''),
    'STAIRS' => ('stairs', ''),
    _ => ('continue', 'straight'),
  };

  static List<LatLng> _geometry(Object? raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final encoded = raw['points'];
    if (encoded is! String || encoded.isEmpty) return const [];
    final precision = (raw['precision'] as num?)?.toInt() ?? 6;
    return RoutingService.decodePolyline(encoded, precision);
  }

  static LatLng? _point(Map<String, dynamic> place) {
    final lat = place['lat'];
    final lon = place['lon'];
    if (lat is! num || lon is! num) return null;
    return LatLng(lat.toDouble(), lon.toDouble());
  }

  static DateTime? _time(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  static double _length(List<LatLng> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += haversineDistance(points[i - 1], points[i]);
    }
    return total;
  }

  void dispose() => _client.close();
}
