import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Distanza in metri tra due coordinate (formula dell'haversine).
double haversineDistance(LatLng a, LatLng b) {
  const toRad = math.pi / 180;
  final dLat = (b.latitude - a.latitude) * toRad / 2;
  final dLng = (b.longitude - a.longitude) * toRad / 2;
  final h = math.sin(dLat) * math.sin(dLat) +
      math.cos(a.latitude * toRad) *
          math.cos(b.latitude * toRad) *
          math.sin(dLng) *
          math.sin(dLng);
  return 6371e3 * (2 * math.atan2(math.sqrt(h), math.sqrt(1 - h)));
}
