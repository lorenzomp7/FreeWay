import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_option.dart';
import 'geo_utils.dart';

/// Stato della navigazione passo-passo.
class NavigationUpdate {
  const NavigationUpdate({
    required this.position,
    required this.currentStep,
    required this.distanceToNextStep,
    required this.isOffRoute,
    required this.progress,
    required this.hasArrived,
    this.accuracy = 0,
  });

  final LatLng position;
  final RouteStep currentStep;
  final double distanceToNextStep;
  final bool isOffRoute;

  /// Avanzamento lungo il percorso, tra 0 e 1.
  final double progress;
  final bool hasArrived;

  /// Precisione della posizione in metri (raggio), 0 se non nota.
  final double accuracy;
}

/// Segue la posizione GPS durante la navigazione e calcola la manovra corrente.
class NavigationService {
  RouteOption? _route;
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<NavigationUpdate> _controller =
      StreamController<NavigationUpdate>.broadcast();

  Stream<NavigationUpdate> get updates => _controller.stream;

  void start(RouteOption route) {
    stop();
    _route = route;
    try {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(_onPosition, onError: _controller.addError);
    } catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    }
  }

  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _route = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _onPosition(Position position) {
    final route = _route;
    if (route == null || route.steps.isEmpty) return;

    final current = LatLng(position.latitude, position.longitude);

    // Punto del tracciato più vicino: serve per avanzamento e fuori percorso.
    var nearestPoint = 0;
    var distanceFromRoute = double.infinity;
    for (var i = 0; i < route.points.length; i++) {
      final d = haversineDistance(current, route.points[i]);
      if (d < distanceFromRoute) {
        nearestPoint = i;
        distanceFromRoute = d;
      }
    }

    final steps = route.steps;
    var stepIndex = 0;
    for (var i = steps.length - 1; i >= 0; i--) {
      if (haversineDistance(current, steps[i].location) < 30) {
        stepIndex = i;
        break;
      }
    }
    var nearestStepDistance = double.infinity;
    for (var i = 0; i < steps.length; i++) {
      final d = haversineDistance(current, steps[i].location);
      if (d < nearestStepDistance) {
        nearestStepDistance = d;
        stepIndex = i;
      }
    }
    if (stepIndex < steps.length - 1) {
      final currentDistance = haversineDistance(
        current,
        steps[stepIndex].location,
      );
      final nextDistance = haversineDistance(
        current,
        steps[stepIndex + 1].location,
      );
      if (nextDistance < currentDistance && currentDistance < 50) stepIndex++;
    }

    final distanceToNext = stepIndex < steps.length - 1
        ? haversineDistance(current, steps[stepIndex + 1].location)
        : 0.0;
    final progress = route.points.isEmpty
        ? 0.0
        : nearestPoint / route.points.length;
    final hasArrived =
        stepIndex == steps.length - 1 &&
        steps.last.maneuverType == 'arrive' &&
        haversineDistance(current, steps.last.location) < 20;

    _controller.add(
      NavigationUpdate(
        position: current,
        currentStep: steps[stepIndex],
        distanceToNextStep: distanceToNext,
        isOffRoute: distanceFromRoute > 50,
        progress: progress.clamp(0.0, 1.0),
        hasArrived: hasArrived,
        accuracy: position.accuracy.isFinite ? position.accuracy : 0,
      ),
    );
  }
}
