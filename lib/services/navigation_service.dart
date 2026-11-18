import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/route_option.dart';
import 'geo_utils.dart';
import 'route_progress.dart';

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
    this.stepIndex = 0,
    this.followingStep,
    this.distanceBetweenSteps = double.infinity,
    this.remainingDistance = 0,
    this.distanceFromRoute = 0,
    this.snappedPosition,
  });

  final LatLng position;

  /// Prossima manovra da fare (all'arrivo, la manovra di arrivo).
  final RouteStep currentStep;

  /// Metri da percorrere lungo il tracciato fino a [currentStep].
  final double distanceToNextStep;
  final bool isOffRoute;

  /// Avanzamento lungo il percorso, tra 0 e 1, in base ai metri fatti.
  final double progress;
  final bool hasArrived;

  /// Precisione della posizione in metri (raggio), 0 se non nota.
  final double accuracy;

  /// Indice di [currentStep] tra le manovre del percorso.
  final int stepIndex;

  /// La manovra dopo [currentStep], se c'è.
  final RouteStep? followingStep;

  /// Metri tra [currentStep] e [followingStep] lungo il tracciato.
  final double distanceBetweenSteps;

  /// Metri che mancano all'arrivo.
  final double remainingDistance;

  /// Distanza dal tracciato in metri.
  final double distanceFromRoute;

  /// Punto del tracciato più vicino alla posizione.
  final LatLng? snappedPosition;
}

/// Segue la posizione GPS durante la navigazione e calcola la manovra corrente.
class NavigationService {
  RouteOption? _route;
  RouteTracker? _tracker;
  final OffRouteDetector _offRoute = OffRouteDetector();
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<NavigationUpdate> _controller =
      StreamController<NavigationUpdate>.broadcast();

  Stream<NavigationUpdate> get updates => _controller.stream;

  /// Il percorso seguito, proiettabile per misurare distanze lungo il
  /// tracciato (per esempio fino a un ostacolo).
  RouteTracker? get tracker => _tracker;

  void start(RouteOption route) {
    stop();
    _route = route;
    _tracker = RouteTracker(route.points, route.steps);
    _offRoute.reset();
    try {
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            ),
          ).listen(
            (position) => handlePosition(
              LatLng(position.latitude, position.longitude),
              position.accuracy.isFinite ? position.accuracy : 0,
            ),
            onError: _controller.addError,
          );
    } catch (error, stackTrace) {
      _controller.addError(error, stackTrace);
    }
  }

  /// Prepara il percorso senza ascoltare il GPS: per i test.
  @visibleForTesting
  void startWithoutGps(RouteOption route) {
    stop();
    _route = route;
    _tracker = RouteTracker(route.points, route.steps);
    _offRoute.reset();
  }

  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _route = null;
    _tracker = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  /// Distanza dall'arrivo entro cui si è arrivati.
  static const double arrivalRadius = 20;

  /// Calcola lo stato per una nuova posizione e lo manda su [updates].
  @visibleForTesting
  NavigationUpdate? handlePosition(LatLng current, double accuracy) {
    final route = _route;
    final tracker = _tracker;
    if (route == null || tracker == null || route.steps.isEmpty) return null;

    final fix = tracker.locate(current);
    final steps = route.steps;
    final total = tracker.totalLength;
    final remaining = math.max(0.0, total - fix.along);
    final hasArrived =
        steps.last.maneuverType == 'arrive' &&
        (haversineDistance(current, steps.last.location) < arrivalRadius ||
            (remaining < arrivalRadius / 2 && fix.offset < arrivalRadius));

    final index = hasArrived
        ? steps.length - 1
        : tracker.upcomingStep(fix.along);
    final distanceToNext = hasArrived
        ? 0.0
        : math.max(0.0, tracker.stepAlong(index) - fix.along);
    final following = index + 1 < steps.length ? steps[index + 1] : null;
    final between = following == null
        ? double.infinity
        : tracker.stepAlong(index + 1) - tracker.stepAlong(index);

    final update = NavigationUpdate(
      position: current,
      currentStep: steps[index],
      distanceToNextStep: distanceToNext,
      isOffRoute: !hasArrived && _offRoute.update(fix.offset, accuracy),
      progress: total <= 0 ? 0.0 : (fix.along / total).clamp(0.0, 1.0),
      hasArrived: hasArrived,
      accuracy: accuracy,
      stepIndex: index,
      followingStep: following,
      distanceBetweenSteps: between,
      remainingDistance: remaining,
      distanceFromRoute: fix.offset,
      snappedPosition: fix.snapped,
    );
    _controller.add(update);
    return update;
  }
}
