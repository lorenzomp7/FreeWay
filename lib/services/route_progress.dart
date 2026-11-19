import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/route_option.dart';
import 'geo_utils.dart';

/// Dove si trova una posizione rispetto al tracciato di un percorso.
class RouteFix {
  const RouteFix({
    required this.along,
    required this.offset,
    required this.segment,
    required this.snapped,
  });

  /// Metri percorsi lungo il tracciato dalla partenza fino al punto
  /// proiettato.
  final double along;

  /// Distanza in metri tra la posizione e il tracciato (il lato più vicino,
  /// non il vertice più vicino).
  final double offset;

  /// Indice del tratto `points[segment]` → `points[segment + 1]`.
  final int segment;

  /// Punto del tracciato più vicino alla posizione.
  final LatLng snapped;
}

/// Proiezione di un punto su un tratto, in coordinate locali in metri.
class _Projection {
  const _Projection(this.t, this.distance);

  /// Frazione del tratto tra 0 e 1.
  final double t;
  final double distance;
}

const double _earthRadius = 6371e3;
const double _toRad = math.pi / 180;

/// Proietta [p] sul tratto [a]→[b] usando un piano locale centrato su [a]:
/// per tratti di qualche centinaio di metri l'errore è trascurabile.
_Projection _project(LatLng p, LatLng a, LatLng b) {
  final cosLat = math.cos(a.latitude * _toRad);
  double x(LatLng q) => (q.longitude - a.longitude) * _toRad * cosLat;
  double y(LatLng q) => (q.latitude - a.latitude) * _toRad;
  final bx = x(b) * _earthRadius, by = y(b) * _earthRadius;
  final px = x(p) * _earthRadius, py = y(p) * _earthRadius;
  final len2 = bx * bx + by * by;
  var t = len2 == 0 ? 0.0 : (px * bx + py * by) / len2;
  t = t.clamp(0.0, 1.0);
  final dx = px - t * bx, dy = py - t * by;
  return _Projection(t, math.sqrt(dx * dx + dy * dy));
}

/// Segue l'avanzamento lungo un percorso.
///
/// La posizione GPS si proietta sul tratto più vicino del tracciato (non sul
/// vertice più vicino, che sui rettilinei lunghi può distare decine di
/// metri) e si cerca prima vicino all'ultimo tratto riconosciuto: così su
/// un percorso che torna su sé stesso, o che passa due volte per lo stesso
/// incrocio, l'avanzamento non salta indietro.
class RouteTracker {
  RouteTracker(this.points, this.steps)
    : _cumulative = _cumulativeDistances(points) {
    _stepAlong = _computeStepAlong();
  }

  final List<LatLng> points;
  final List<RouteStep> steps;
  final List<double> _cumulative;
  late final List<double> _stepAlong;
  int _lastSegment = 0;

  /// Quanti metri dietro l'ultimo tratto riconosciuto si accetta di tornare
  /// (chi cammina può fare qualche passo indietro).
  static const double backtrackWindow = 60;

  /// Quanti metri dopo l'ultimo tratto riconosciuto si cerca per primi.
  static const double forwardWindow = 400;

  /// Oltre questa distanza dal tratto trovato vicino all'ultimo si cerca su
  /// tutto il percorso.
  static const double globalSearchOffset = 40;

  double get totalLength => _cumulative.isEmpty ? 0 : _cumulative.last;

  /// Metri dalla partenza alla manovra [index].
  double stepAlong(int index) => _stepAlong[index];

  static List<double> _cumulativeDistances(List<LatLng> points) {
    final result = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) total += haversineDistance(points[i - 1], points[i]);
      result.add(total);
    }
    return result;
  }

  List<double> _computeStepAlong() {
    final result = <double>[];
    var from = 0;
    for (final step in steps) {
      if (points.length < 2) {
        result.add(0);
        continue;
      }
      // Le manovre sono in ordine: si cerca solo in avanti.
      final fix = _bestIn(step.location, from, points.length - 2);
      from = fix.segment;
      result.add(math.max(fix.along, result.isEmpty ? 0 : result.last));
    }
    return result;
  }

  RouteFix _fixOn(LatLng position, int segment) {
    final a = points[segment], b = points[segment + 1];
    final p = _project(position, a, b);
    final length = _cumulative[segment + 1] - _cumulative[segment];
    return RouteFix(
      along: _cumulative[segment] + p.t * length,
      offset: p.distance,
      segment: segment,
      snapped: LatLng(
        a.latitude + (b.latitude - a.latitude) * p.t,
        a.longitude + (b.longitude - a.longitude) * p.t,
      ),
    );
  }

  RouteFix _bestIn(LatLng position, int first, int last) {
    RouteFix? best;
    for (var i = first; i <= last; i++) {
      final fix = _fixOn(position, i);
      if (best == null || fix.offset < best.offset - 0.01) best = fix;
    }
    return best!;
  }

  /// Proietta [position] sul percorso e ricorda il tratto trovato.
  RouteFix locate(LatLng position) {
    if (points.isEmpty) {
      return RouteFix(along: 0, offset: 0, segment: 0, snapped: position);
    }
    if (points.length == 1) {
      return RouteFix(
        along: 0,
        offset: haversineDistance(position, points.first),
        segment: 0,
        snapped: points.first,
      );
    }
    final lastIndex = points.length - 2;
    var first = _lastSegment;
    final floor = _cumulative[_lastSegment] - backtrackWindow;
    while (first > 0 && _cumulative[first] > floor) {
      first--;
    }
    var last = _lastSegment;
    final ceiling = _cumulative[_lastSegment + 1] + forwardWindow;
    while (last < lastIndex && _cumulative[last + 1] < ceiling) {
      last++;
    }
    var fix = _bestIn(position, first, last);
    if (fix.offset > globalSearchOffset && (first > 0 || last < lastIndex)) {
      final global = _bestIn(position, 0, lastIndex);
      if (global.offset < fix.offset) fix = global;
    }
    _lastSegment = fix.segment;
    return fix;
  }

  /// Proietta [point] sul tratto di percorso tra [fromAlong] e
  /// [fromAlong] + [ahead] metri, senza cambiare il tratto riconosciuto.
  ///
  /// Restituisce `null` se il tracciato non ha tratti in quell'intervallo.
  RouteFix? projectAhead(LatLng point, double fromAlong, double ahead) {
    if (points.length < 2) return null;
    RouteFix? best;
    for (var i = 0; i < points.length - 1; i++) {
      if (_cumulative[i + 1] < fromAlong) continue;
      if (_cumulative[i] > fromAlong + ahead) break;
      final fix = _fixOn(point, i);
      if (fix.along < fromAlong || fix.along > fromAlong + ahead) continue;
      if (best == null || fix.offset < best.offset) best = fix;
    }
    return best;
  }

  /// Indice della prossima manovra da fare quando si è a [along] metri
  /// dalla partenza: la prima che sta più avanti di [passedMargin].
  ///
  /// Una manovra a meno di [passedMargin] metri alle spalle conta come
  /// fatta. Restituisce l'ultima manovra se sono state fatte tutte.
  int upcomingStep(double along, {double passedMargin = 8}) {
    for (var i = 1; i < steps.length; i++) {
      if (_stepAlong[i] > along + passedMargin) return i;
    }
    return steps.length - 1;
  }
}

/// Decide quando si è davvero usciti dal percorso.
///
/// Un solo punto GPS lontano dal tracciato non basta: in città il segnale
/// rimbalza sui palazzi. Servono [requiredFixes] posizioni di fila oltre la
/// soglia, che cresce con l'incertezza del GPS; con una posizione troppo
/// imprecisa non si decide nulla. Molto lontano dal percorso basta una
/// posizione sola.
class OffRouteDetector {
  OffRouteDetector({
    this.baseThreshold = 30,
    this.maxThreshold = 70,
    this.requiredFixes = 2,
    this.unreliableAccuracy = 60,
  });

  final double baseThreshold;
  final double maxThreshold;
  final int requiredFixes;

  /// Oltre questa incertezza (in metri) la posizione non decide.
  final double unreliableAccuracy;

  int _count = 0;
  bool _offRoute = false;

  bool get isOffRoute => _offRoute;

  /// Soglia in metri per una posizione con incertezza [accuracy].
  double threshold(double accuracy) => (baseThreshold + accuracy.clamp(0, 40))
      .clamp(baseThreshold, maxThreshold)
      .toDouble();

  /// Aggiorna lo stato con una nuova distanza dal percorso e lo restituisce.
  bool update(double offset, double accuracy) {
    if (accuracy > unreliableAccuracy) return _offRoute;
    final limit = threshold(accuracy);
    if (offset <= limit) {
      _count = 0;
      _offRoute = false;
    } else {
      _count++;
      if (_count >= requiredFixes || offset > limit * 2.5) _offRoute = true;
    }
    return _offRoute;
  }

  void reset() {
    _count = 0;
    _offRoute = false;
  }
}
