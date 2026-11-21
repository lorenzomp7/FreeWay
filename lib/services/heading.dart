import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Direzione da [from] a [to] in gradi, in senso orario dal nord (0-360).
double bearingBetween(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final dLon = (to.longitude - from.longitude) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
}

/// Angolo tra 0 (compreso) e 360 (escluso).
double normalizeDegrees(double degrees) {
  final value = degrees % 360;
  return value < 0 ? value + 360 : value;
}

/// Differenza più breve da [from] a [to], tra -180 e 180.
double angleDifference(double from, double to) {
  final diff = normalizeDegrees(to - from);
  return diff > 180 ? diff - 360 : diff;
}

/// Direzione del percorso nel punto [at]: quella del tratto più vicino,
/// guardando un po' avanti (circa [lookAhead] metri) perché sulle curve
/// strette la mappa non giri a scatti. `null` se il percorso è troppo corto.
double? routeBearingAt(List<LatLng> route, LatLng at, {double lookAhead = 25}) {
  if (route.length < 2) return null;
  const distance = Distance();
  var bestIndex = 0;
  var best = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    final d = _distanceToSegment(at, route[i], route[i + 1]);
    if (d < best) {
      best = d;
      bestIndex = i;
    }
  }
  // Un punto un po' più avanti lungo il percorso.
  var target = route[bestIndex + 1];
  var travelled = distance(at, target);
  for (var i = bestIndex + 1; travelled < lookAhead && i < route.length - 1;) {
    i++;
    travelled += distance(route[i - 1], route[i]);
    target = route[i];
  }
  if (distance(at, target) < 1) {
    return bearingBetween(route[bestIndex], route[bestIndex + 1]);
  }
  return bearingBetween(at, target);
}

/// Distanza approssimata (metri) di [p] dal segmento [a]-[b], su un piano
/// locale: basta per scegliere il tratto più vicino.
double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
  final cosLat = math.cos(p.latitude * math.pi / 180);
  double x(LatLng q) => (q.longitude - p.longitude) * 111320 * cosLat;
  double y(LatLng q) => (q.latitude - p.latitude) * 110540;
  final ax = x(a), ay = y(a), bx = x(b), by = y(b);
  final dx = bx - ax, dy = by - ay;
  final length2 = dx * dx + dy * dy;
  var t = length2 == 0 ? 0.0 : -(ax * dx + ay * dy) / length2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt(cx * cx + cy * cy);
}

/// Smorza le letture della bussola, che nel telefono tremano di qualche
/// grado: media esponenziale sul cerchio (così 359° e 1° fanno 0°, non
/// 180°).
class HeadingSmoother {
  HeadingSmoother({this.factor = 0.25});

  /// Peso della lettura nuova, tra 0 e 1.
  final double factor;
  double? _x;
  double? _y;

  double? get value {
    final x = _x, y = _y;
    if (x == null || y == null) return null;
    return normalizeDegrees(math.atan2(y, x) * 180 / math.pi);
  }

  double add(double heading) {
    final rad = heading * math.pi / 180;
    final nx = math.cos(rad), ny = math.sin(rad);
    _x = _x == null ? nx : _x! + (nx - _x!) * factor;
    _y = _y == null ? ny : _y! + (ny - _y!) * factor;
    return value!;
  }

  void reset() {
    _x = null;
    _y = null;
  }
}
