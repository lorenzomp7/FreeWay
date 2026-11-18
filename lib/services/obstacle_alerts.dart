import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import 'geo_utils.dart';

/// Distanza entro cui, durante la navigazione, si chiede se un ostacolo c'è
/// ancora (come "Is construction still there?" di Google Maps).
const double kVerifyRadius = 25;

/// Oltre questa distanza la domanda su un ostacolo superato sparisce.
const double kVerifyDismissRadius = 80;

/// Raggio entro cui un ostacolo è considerato sul percorso.
const double kOnRouteRadius = 30;

/// L'ostacolo più vicino entro [radius] su cui chiedere conferma a chi passa.
///
/// Esclude gli ostacoli già chiesti in questa navigazione, quelli segnalati
/// da [userId] e quelli che ha già confermato.
Obstacle? obstacleToVerify(
  LatLng position,
  List<Obstacle> obstacles,
  Set<String> alreadyAsked,
  String? userId, {
  double radius = kVerifyRadius,
}) {
  Obstacle? best;
  var bestDistance = double.infinity;
  for (final obstacle in obstacles) {
    if (alreadyAsked.contains(obstacle.id)) continue;
    if (obstacle.isReportedBy(userId)) continue;
    if (userId != null && obstacle.confirmedBy.contains(userId)) continue;
    final distance = haversineDistance(position, obstacle.position);
    if (distance <= radius && distance < bestDistance) {
      best = obstacle;
      bestDistance = distance;
    }
  }
  return best;
}

/// Indice del punto di [points] più vicino a [position].
int nearestPointIndex(List<LatLng> points, LatLng position) {
  var index = 0;
  var best = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final d = haversineDistance(points[i], position);
    if (d < best) {
      best = d;
      index = i;
    }
  }
  return index;
}

/// `true` se il tracciato [points] passa entro [radius] metri da [obstacle].
bool routePassesNear(
  List<LatLng> points,
  Obstacle obstacle, {
  double radius = kOnRouteRadius,
}) {
  return points.any((p) => haversineDistance(p, obstacle.position) <= radius);
}

/// Ostacoli di [obstacles] sul tratto di percorso ancora da fare, cioè dal
/// punto più vicino a [position] all'arrivo.
List<Obstacle> obstaclesAhead(
  List<LatLng> points,
  LatLng position,
  List<Obstacle> obstacles, {
  double radius = kOnRouteRadius,
}) {
  if (points.isEmpty) return const [];
  final remaining = points.sublist(nearestPointIndex(points, position));
  return obstacles
      .where((o) => routePassesNear(remaining, o, radius: radius))
      .toList();
}
