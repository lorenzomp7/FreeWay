import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/route_option.dart';
import 'geo_utils.dart';

/// Da che lato si trova la destinazione arrivando a piedi, come "X on your
/// left/right" delle indicazioni di Google Maps.
enum ArrivalSide { left, right, ahead }

/// Sotto questa distanza il percorso finisce proprio sulla destinazione.
const double _onTheSpotMeters = 4;

/// Lunghezza dell'ultimo tratto usata per capire la direzione di marcia.
const double _headingMeters = 10;

/// Lato di [destination] rispetto alla direzione con cui [points] finisce.
///
/// `null` se il percorso finisce sulla destinazione o se il lato non si
/// può stabilire (destinazione alle spalle, tracciato troppo corto).
ArrivalSide? arrivalSide(List<LatLng> points, LatLng destination) {
  if (points.length < 2) return null;
  final end = points.last;
  if (haversineDistance(end, destination) < _onTheSpotMeters) return null;

  // Un punto qualche metro prima dell'arrivo dà la direzione di marcia.
  var previous = points[points.length - 2];
  for (var i = points.length - 2; i >= 0; i--) {
    previous = points[i];
    if (haversineDistance(points[i], end) >= _headingMeters) break;
  }
  if (haversineDistance(previous, end) < 1) return null;

  // Coordinate piane locali: x verso est, y verso nord.
  final scale = math.cos(end.latitude * math.pi / 180);
  final vx = (end.longitude - previous.longitude) * scale;
  final vy = end.latitude - previous.latitude;
  final wx = (destination.longitude - end.longitude) * scale;
  final wy = destination.latitude - end.latitude;
  final angle =
      math.atan2(vx * wy - vy * wx, vx * wx + vy * wy) * 180 / math.pi;

  if (angle.abs() <= 25) return ArrivalSide.ahead;
  if (angle.abs() >= 155) return null;
  return angle > 0 ? ArrivalSide.left : ArrivalSide.right;
}

/// Mette il lato della destinazione nella manovra di arrivo del percorso,
/// che diventa `arrive|left|via`, `arrive|right|via` o `arrive|straight|via`.
void applyArrivalSide(RouteOption route, LatLng destination) {
  if (route.steps.isEmpty) return;
  final last = route.steps.last;
  if (last.maneuverType != 'arrive') return;
  final side = arrivalSide(route.points, destination);
  if (side == null) return;
  final modifier = switch (side) {
    ArrivalSide.left => 'left',
    ArrivalSide.right => 'right',
    ArrivalSide.ahead => 'straight',
  };
  route.steps[route.steps.length - 1] = RouteStep(
    instruction: 'arrive|$modifier|${last.streetName}',
    location: last.location,
    maneuverType: last.maneuverType,
    modifier: modifier,
    streetName: last.streetName,
    distance: last.distance,
    duration: last.duration,
  );
}
