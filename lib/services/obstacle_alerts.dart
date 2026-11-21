import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import 'geo_utils.dart';
import 'route_progress.dart';

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

/// Fin dove, lungo il percorso, si avvisa di un ostacolo segnalato.
const double kAheadWarningDistance = 80;

/// Secondi di anticipo con cui avvisare di un ostacolo, alla velocità
/// attuale.
const double kAheadWarningSeconds = 45;

/// Distanza a cui avvisare di un ostacolo andando a [speed] metri al
/// secondo: circa [kAheadWarningSeconds] secondi prima, tra 35 e 80 m.
/// Chi va piano (in sedia a rotelle, su una salita) non sente l'avviso
/// un minuto e mezzo prima di arrivarci. Senza velocità nota: 80 m.
double aheadWarningDistance(double speed) {
  if (!speed.isFinite || speed < 0.3) return kAheadWarningDistance;
  return (speed * kAheadWarningSeconds)
      .clamp(kVerifyRadius + 10, kAheadWarningDistance)
      .toDouble();
}

/// Un ostacolo segnalato sul percorso davanti a chi naviga.
class ObstacleAhead {
  const ObstacleAhead(this.obstacle, this.distance);

  final Obstacle obstacle;

  /// Metri lungo il percorso fino all'ostacolo.
  final double distance;
}

/// Il primo ostacolo sul percorso tra [kVerifyRadius] e [maxAhead] metri
/// davanti, di cui avvisare prima di arrivarci.
///
/// Si misura lungo il tracciato a partire da [along] (i metri già fatti),
/// quindi un ostacolo già superato o su una via parallela non conta. Gli
/// ostacoli più vicini di [kVerifyRadius] li gestisce la domanda "C'è
/// ancora?". Esclude quelli in [alreadyAnnounced] e quelli segnalati da
/// [userId], che li conosce già.
ObstacleAhead? obstacleAheadToAnnounce(
  RouteTracker tracker,
  double along,
  List<Obstacle> obstacles,
  Set<String> alreadyAnnounced,
  String? userId, {
  double maxAhead = kAheadWarningDistance,
  double radius = kOnRouteRadius,
}) {
  ObstacleAhead? best;
  for (final obstacle in obstacles) {
    if (alreadyAnnounced.contains(obstacle.id)) continue;
    if (obstacle.isReportedBy(userId)) continue;
    final fix = tracker.projectAhead(obstacle.position, along, maxAhead);
    if (fix == null || fix.offset > radius) continue;
    final distance = fix.along - along;
    if (distance < kVerifyRadius) continue;
    if (best == null || distance < best.distance) {
      best = ObstacleAhead(obstacle, distance);
    }
  }
  return best;
}

/// Raggio entro cui un ostacolo già segnalato spiega una deviazione.
const double kDeviationExplainedRadius = 40;

/// Se dopo un'uscita dal percorso in [leftAt] conviene chiedere "Hai
/// cambiato strada per un ostacolo?".
///
/// Non serve se lì vicino c'è già un ostacolo segnalato: la deviazione è
/// spiegata e semmai lo si conferma con "C'è ancora?".
bool shouldAskAboutDeviation(
  LatLng leftAt,
  List<Obstacle> obstacles, {
  double radius = kDeviationExplainedRadius,
}) {
  return !obstacles.any((o) => haversineDistance(o.position, leftAt) <= radius);
}
