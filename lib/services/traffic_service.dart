import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_option.dart';
import 'geo_utils.dart';

/// Indirizzo del servizio intermedio del traffico (Cloudflare Worker in
/// `tools/traffic-worker/`), passato in fase di build con
/// `--dart-define=TRAFFIC_URL=...`. Vuoto: il traffico è spento.
///
/// La chiave di TomTom resta nel Worker: nell'app finirebbe nel codice
/// pubblico del sito.
const String kTrafficUrl = String.fromEnvironment('TRAFFIC_URL');

/// Traffico su una strada in un punto, come lo restituisce il Worker (dati
/// TomTom Flow Segment Data).
class TrafficSample {
  const TrafficSample({
    required this.position,
    required this.roadClass,
    required this.currentSpeed,
    required this.freeFlowSpeed,
    required this.confidence,
    required this.roadClosure,
    required this.distance,
  });

  final LatLng position;

  /// Importanza della strada (FRC di TomTom): 0 autostrada, 1–3 strade
  /// principali, 4–6 strade locali.
  final int roadClass;

  /// Velocità adesso e a strada libera, in km/h.
  final double currentSpeed;
  final double freeFlowSpeed;

  /// Affidabilità del dato, da 0 a 1.
  final double confidence;
  final bool roadClosure;

  /// Metri tra il punto chiesto e la strada trovata.
  final double distance;

  static TrafficSample? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'];
    final lon = json['lon'];
    final frc = json['frc'];
    final current = json['currentSpeed'];
    final free = json['freeFlowSpeed'];
    if (lat is! num ||
        lon is! num ||
        frc is! num ||
        current is! num ||
        free is! num) {
      return null;
    }
    return TrafficSample(
      position: LatLng(lat.toDouble(), lon.toDouble()),
      roadClass: frc.toInt(),
      currentSpeed: current.toDouble(),
      freeFlowSpeed: free.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      roadClosure: json['roadClosure'] == true,
      distance: (json['distance'] as num?)?.toDouble() ?? double.infinity,
    );
  }
}

/// Quanto è trafficata la strada in un punto, per chi va a piedi o in sedia a
/// rotelle.
enum TrafficLevel {
  /// Strada locale, chiusa, lontana dal percorso o dato poco affidabile.
  none,

  /// Strada principale con auto veloci (a strada libera almeno 50 km/h).
  busy,

  /// Strada principale con coda: le auto vanno a meno del 60% della velocità
  /// a strada libera.
  heavy,
}

/// Distanza oltre la quale la strada trovata non è quella del percorso.
const double kMaxTrafficDistance = 30;

TrafficLevel trafficLevelOf(TrafficSample sample) {
  if (sample.roadClosure ||
      sample.confidence < 0.5 ||
      sample.distance > kMaxTrafficDistance ||
      sample.roadClass > 3 ||
      sample.freeFlowSpeed <= 0) {
    return TrafficLevel.none;
  }
  if (sample.currentSpeed < 0.6 * sample.freeFlowSpeed) {
    return TrafficLevel.heavy;
  }
  if (sample.freeFlowSpeed >= 50) return TrafficLevel.busy;
  return TrafficLevel.none;
}

/// Punti in cui controllare il traffico: le manovre del percorso (incroci e
/// attraversamenti), senza partenza e arrivo, distanti almeno 40 m tra loro.
/// Con poche manovre si aggiungono punti lungo il tragitto.
List<LatLng> trafficSamplePoints(RouteOption route, {int max = 6}) {
  final points = <LatLng>[];
  void addPoint(LatLng p) {
    if (points.length >= max) return;
    if (haversineDistance(p, route.points.first) < 40 ||
        haversineDistance(p, route.points.last) < 40) {
      return;
    }
    if (points.any((q) => haversineDistance(p, q) < 40)) return;
    points.add(p);
  }

  for (final step in route.steps) {
    addPoint(step.location);
  }
  if (points.length < max && route.points.length > 2) {
    final missing = max - points.length;
    for (var i = 1; i <= missing; i++) {
      final index = (route.points.length - 1) * i ~/ (missing + 1);
      addPoint(route.points[index]);
    }
  }
  return points;
}

/// Avviso "strade trafficate" per i campioni di un percorso, o `null` se il
/// traffico non dà fastidio.
RouteWarning? busyRoadWarning(Iterable<TrafficSample?> samples) {
  var busy = 0;
  var heavy = 0;
  for (final sample in samples) {
    if (sample == null) continue;
    switch (trafficLevelOf(sample)) {
      case TrafficLevel.heavy:
        heavy++;
      case TrafficLevel.busy:
        busy++;
      case TrafficLevel.none:
        break;
    }
  }
  final count = busy + heavy;
  if (count == 0) return null;
  return RouteWarning(
    RouteWarningKind.busyRoad,
    0,
    count: count,
    detail: heavy == 0 ? '' : (heavy == 1 ? '1 con coda' : '$heavy con coda'),
  );
}

/// Riordina i percorsi tenendo conto del traffico: uno con meno punti
/// trafficati passa davanti se non è più lungo del 15% (in tempo) del primo.
/// Restituisce `true` se il primo percorso è cambiato.
bool rankByTraffic(List<RouteOption> routes, {required bool walking}) {
  if (routes.length < 2) return false;
  final first = routes.first;
  RouteOption? better;
  for (final route in routes.skip(1)) {
    if (route.busyRoadCount >= first.busyRoadCount) continue;
    if (route.duration > first.duration * 1.15) continue;
    // In sedia a rotelle gli ostacoli e le barriere contano di più.
    if (!walking &&
        (route.obstacleCount > first.obstacleCount ||
            route.hardWarningCount > first.hardWarningCount)) {
      continue;
    }
    if (better == null || route.busyRoadCount < better.busyRoadCount) {
      better = route;
    }
  }
  if (better == null) return false;
  routes
    ..remove(better)
    ..insert(0, better);
  first
    ..isRecommended = false
    ..label = walking ? 'Più veloce' : 'Alternativa';
  better
    ..isRecommended = true
    ..label = 'Meno traffico';
  return true;
}

/// Chiede al Worker il traffico lungo i percorsi a piedi e in sedia a rotelle
/// e aggiunge l'avviso "strade trafficate".
class TrafficService {
  TrafficService({String baseUrl = kTrafficUrl, http.Client? client})
    : _baseUrl = baseUrl,
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  bool get isEnabled => _baseUrl.isNotEmpty;

  /// Al massimo tanti punti per richiesta, come accetta il Worker.
  static const int maxPoints = 18;

  /// Aggiunge gli avvisi ai primi tre percorsi e li riordina. Se il servizio
  /// è spento, lento o non risponde, i percorsi restano come sono.
  Future<bool> annotate(
    List<RouteOption> routes, {
    required bool walking,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!isEnabled || routes.isEmpty) return false;
    final checked = routes.take(3).toList();
    final perRoute = [for (final r in checked) trafficSamplePoints(r)];
    final all = [for (final points in perRoute) ...points];
    if (all.isEmpty) return false;
    final List<TrafficSample?> samples;
    try {
      samples = await fetch(all.take(maxPoints).toList()).timeout(timeout);
    } catch (_) {
      return false;
    }
    var offset = 0;
    for (var i = 0; i < checked.length; i++) {
      final count = perRoute[i].length;
      final mine = [
        for (var j = offset; j < offset + count && j < samples.length; j++)
          samples[j],
      ];
      offset += count;
      final warning = busyRoadWarning(mine);
      final route = checked[i];
      route.warnings = [
        ...route.warnings.where((w) => w.kind != RouteWarningKind.busyRoad),
        ?warning,
      ];
    }
    return rankByTraffic(routes, walking: walking);
  }

  /// Traffico nei [points], nello stesso ordine; `null` dove non c'è dato.
  Future<List<TrafficSample?>> fetch(List<LatLng> points) async {
    final query = points
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(5)},'
              '${p.longitude.toStringAsFixed(5)}',
        )
        .join('|');
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'points': query});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Traffico non disponibile (${response.statusCode})');
    }
    final data = jsonDecode(response.body);
    final list = data is Map ? data['points'] : null;
    if (list is! List) throw const FormatException('Risposta non valida');
    return [for (final item in list) TrafficSample.fromJson(item)];
  }

  void dispose() => _client.close();
}
