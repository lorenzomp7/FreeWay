import 'package:latlong2/latlong.dart';

/// Singola manovra restituita da OSRM.
///
/// [instruction] è codificata come `tipo|modificatore|nome via` e viene
/// tradotta da `InstructionTranslator`.
class RouteStep {
  RouteStep({
    required this.instruction,
    required this.location,
    required this.maneuverType,
    required this.modifier,
    this.streetName = '',
    this.distance = 0,
    this.duration = 0,
  });

  final String instruction;
  final LatLng location;
  final String maneuverType;
  final String modifier;
  final String streetName;
  final double distance;
  final double duration;
}

/// Percorso pedonale proposto all'utente.
class RouteOption {
  RouteOption({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
    required this.index,
  });

  final List<LatLng> points;

  /// Distanza in metri.
  final double distance;

  /// Durata in secondi.
  final double duration;
  final List<RouteStep> steps;
  final int index;

  int obstacleCount = 0;
  bool isRecommended = false;
  String label = '';

  String get distanceText {
    if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(1)} km';
    return '${distance.round()} m';
  }

  String get durationText {
    final minutes = (duration / 60).round();
    if (minutes >= 60) return '${minutes ~/ 60}h ${minutes % 60}min';
    return '$minutes min';
  }

  /// Punteggio di accessibilità (0-100) in base agli ostacoli sul tragitto.
  int get accessibilityScore {
    switch (obstacleCount) {
      case 0:
        return 100;
      case 1:
        return 85;
      case 2:
        return 65;
      case 3:
        return 45;
      default:
        return 30;
    }
  }
}
