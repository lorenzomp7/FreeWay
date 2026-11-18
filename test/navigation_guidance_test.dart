import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/navigation_service.dart';
import 'package:freeway/services/obstacle_alerts.dart';
import 'package:freeway/services/route_progress.dart';
import 'package:freeway/services/voice_guidance.dart';
import 'package:latlong2/latlong.dart';

/// Gradi di longitudine per 1 m a questa latitudine (45.54°).
const double lngPerMeter = 1 / 77950;

/// Gradi di latitudine per 1 m.
const double latPerMeter = 1 / 111195;

const double lat0 = 45.54;
const double lng0 = 10.22;

LatLng east(double meters, {double north = 0}) =>
    LatLng(lat0 + north * latPerMeter, lng0 + meters * lngPerMeter);

RouteStep step(String type, String modifier, LatLng at, {String street = ''}) =>
    RouteStep(
      instruction: '$type|$modifier|$street',
      location: at,
      maneuverType: type,
      modifier: modifier,
      streetName: street,
    );

/// 300 m verso est (solo due vertici: un rettilineo lungo), svolta a
/// sinistra, 30 m verso nord, svolta a destra, 50 m verso est e arrivo.
RouteOption lRoute() {
  final corner = east(300);
  final corner2 = east(300, north: 30);
  final end = east(350, north: 30);
  return RouteOption(
    points: [east(0), corner, corner2, end],
    distance: 380,
    duration: 380,
    index: 0,
    steps: [
      step('depart', '', east(0), street: 'Via Roma'),
      step('turn', 'left', corner, street: 'Via Verdi'),
      step('turn', 'right', corner2, street: 'Via Bianchi'),
      step('arrive', 'left', end),
    ],
  );
}

void main() {
  group('RouteTracker', () {
    test('misura la distanza dal tratto, non dal vertice', () {
      final tracker = RouteTracker(lRoute().points, lRoute().steps);
      // A metà del rettilineo, 5 m a nord: i vertici sono a 150 m.
      final fix = tracker.locate(east(150, north: 5));
      expect(fix.offset, closeTo(5, 0.5));
      expect(fix.along, closeTo(150, 1));
      expect(tracker.totalLength, closeTo(380, 1));
    });

    test('trova le manovre lungo il tracciato', () {
      final tracker = RouteTracker(lRoute().points, lRoute().steps);
      expect(tracker.stepAlong(1), closeTo(300, 1));
      expect(tracker.stepAlong(2), closeTo(330, 1));
      expect(tracker.upcomingStep(100), 1);
      expect(tracker.upcomingStep(305), 2);
      expect(tracker.upcomingStep(379), 3);
    });

    test("non torna indietro su un percorso che ripassa dall'incrocio", () {
      // Andata e ritorno sulla stessa via: 200 m a est e di nuovo indietro.
      final points = [
        east(0),
        east(200),
        east(200, north: 1),
        east(0, north: 1),
      ];
      final tracker = RouteTracker(points, [
        step('depart', '', points.first),
        step('arrive', '', points.last),
      ]);
      expect(tracker.locate(east(150)).along, closeTo(150, 1));
      expect(tracker.locate(east(199)).along, closeTo(199, 1));
      // Sulla via del ritorno, a 150 m dalla partenza: siamo a ~251 m.
      expect(tracker.locate(east(150, north: 1)).along, closeTo(251, 2));
    });

    test('proietta un punto solo nel tratto davanti', () {
      final tracker = RouteTracker(lRoute().points, lRoute().steps);
      expect(tracker.projectAhead(east(100), 0, 80), isNull);
      final fix = tracker.projectAhead(east(100, north: 3), 50, 80);
      expect(fix!.along, closeTo(100, 1));
      expect(fix.offset, closeTo(3, 0.5));
    });
  });

  group('OffRouteDetector', () {
    test('serve più di un punto lontano', () {
      final detector = OffRouteDetector();
      expect(detector.update(45, 5), isFalse);
      expect(detector.update(45, 5), isTrue);
      expect(detector.update(10, 5), isFalse);
    });

    test('molto lontano basta un punto, impreciso non decide', () {
      final detector = OffRouteDetector();
      expect(detector.update(200, 5), isTrue);
      detector.reset();
      expect(detector.update(200, 90), isFalse);
      expect(detector.update(200, 90), isFalse);
    });

    test('la soglia cresce con l’incertezza del GPS', () {
      final detector = OffRouteDetector();
      expect(detector.threshold(0), 30);
      expect(detector.threshold(25), 55);
      expect(detector.threshold(50), 70);
    });
  });

  group('NavigationService', () {
    late NavigationService service;
    setUp(() {
      service = NavigationService()..startWithoutGps(lRoute());
    });
    tearDown(() => service.dispose());

    test('mostra la prossima manovra con i metri lungo il percorso', () {
      final update = service.handlePosition(east(100, north: 4), 5)!;
      expect(update.currentStep.modifier, 'left');
      expect(update.distanceToNextStep, closeTo(200, 1));
      expect(update.isOffRoute, isFalse);
      expect(update.progress, closeTo(100 / 380, 0.01));
      expect(update.remainingDistance, closeTo(280, 1));
      expect(update.followingStep?.modifier, 'right');
      expect(update.distanceBetweenSteps, closeTo(30, 1));
    });

    test('dopo la svolta passa alla manovra seguente', () {
      final update = service.handlePosition(east(301, north: 12), 5)!;
      expect(update.currentStep.modifier, 'right');
      expect(update.distanceToNextStep, closeTo(18, 2));
    });

    test('arriva vicino alla destinazione', () {
      service.handlePosition(east(300, north: 30), 5);
      final update = service.handlePosition(east(345, north: 30), 5)!;
      expect(update.hasArrived, isTrue);
      expect(update.currentStep.maneuverType, 'arrive');
      expect(update.isOffRoute, isFalse);
    });

    test('esce dal percorso solo dopo due punti lontani', () {
      expect(
        service.handlePosition(east(100, north: 50), 5)!.isOffRoute,
        isFalse,
      );
      expect(
        service.handlePosition(east(105, north: 50), 5)!.isOffRoute,
        isTrue,
      );
    });
  });

  group('VoiceGuidance', () {
    NavigationUpdate at(
      RouteStep current,
      double distance, {
      int index = 1,
      RouteStep? following,
      double between = double.infinity,
      bool offRoute = false,
      bool arrived = false,
    }) => NavigationUpdate(
      position: east(0),
      currentStep: current,
      distanceToNextStep: distance,
      isOffRoute: offRoute,
      progress: 0,
      hasArrived: arrived,
      stepIndex: index,
      followingStep: following,
      distanceBetweenSteps: between,
    );

    final left = step('turn', 'left', east(300), street: 'Via Verdi');
    final right = step('turn', 'right', east(330), street: 'Via Bianchi');

    test('annuncia ogni fase una volta sola', () {
      final guidance = VoiceGuidance();
      final said = <String?>[
        for (final d in <double>[300, 295, 250, 120, 99, 95, 60, 19, 15, 5])
          guidance.next(at(left, d), 'it'),
      ].whereType<String>().toList();
      expect(said, [
        'Prosegui per 300 metri',
        'Tra 100 metri, svolta a sinistra su Via Verdi',
        'Svolta a sinistra su Via Verdi',
      ]);
    });

    test('con due manovre vicine dice anche la seconda', () {
      final guidance = VoiceGuidance();
      expect(
        guidance.next(at(left, 18, following: right, between: 30), 'it'),
        'Svolta a sinistra su Via Verdi, poi svolta a destra su Via Bianchi',
      );
      expect(
        VoiceGuidance().next(at(left, 18, following: right, between: 30), 'en'),
        'Turn left on Via Verdi, then turn right on Via Bianchi',
      );
    });

    test('ricomincia alla manovra seguente e all’arrivo', () {
      final guidance = VoiceGuidance();
      guidance.next(at(left, 15), 'it');
      expect(
        guidance.next(at(right, 25, index: 2), 'it'),
        'Tra 30 metri, svolta a destra su Via Bianchi',
      );
      final arrive = step('arrive', 'left', east(350));
      expect(
        guidance.next(at(arrive, 60, index: 3), 'it'),
        'Tra 60 metri arrivi a destinazione',
      );
      expect(guidance.next(at(arrive, 10, index: 3), 'it'), isNull);
      expect(
        guidance.next(at(arrive, 0, index: 3, arrived: true), 'it'),
        'Sei arrivato/a: la destinazione è sulla sinistra',
      );
      expect(
        guidance.next(at(arrive, 0, index: 3, arrived: true), 'it'),
        isNull,
      );
    });

    test('dice una volta che si è fuori percorso', () {
      final guidance = VoiceGuidance();
      expect(
        guidance.next(at(left, 200, offRoute: true), 'it'),
        'Sei fuori percorso. Ricalcolo.',
      );
      expect(guidance.next(at(left, 200, offRoute: true), 'it'), isNull);
    });

    test('arrotonda le distanze come si dicono', () {
      expect(VoiceGuidance.spokenDistance(43, 'it'), '40 metri');
      expect(VoiceGuidance.spokenDistance(4, 'it'), '10 metri');
      expect(VoiceGuidance.spokenDistance(276, 'it'), '300 metri');
      expect(VoiceGuidance.spokenDistance(1000, 'it'), '1 chilometro');
      expect(VoiceGuidance.spokenDistance(1260, 'it'), '1,3 chilometri');
      expect(VoiceGuidance.spokenDistance(1260, 'en'), '1.3 kilometers');
    });
  });

  group('Ostacoli in arrivo', () {
    Obstacle obstacle(String id, LatLng at, {String? by}) =>
        Obstacle(id: id, position: at, type: 'Gradino', userId: by);

    test('avvisa del primo ostacolo davanti sul percorso', () {
      final route = lRoute();
      final tracker = RouteTracker(route.points, route.steps);
      final behind = obstacle('behind', east(50, north: 3));
      final near = obstacle('near', east(160, north: 3));
      final far = obstacle('far', east(260, north: 3));
      final parallel = obstacle('parallel', east(150, north: 60));
      final ahead = obstacleAheadToAnnounce(
        tracker,
        100,
        [behind, far, parallel, near],
        {},
        'me',
      );
      expect(ahead!.obstacle.id, 'near');
      expect(ahead.distance, closeTo(60, 1));
    });

    test('non ripete, non avvisa dei propri né di quelli già vicini', () {
      final route = lRoute();
      final tracker = RouteTracker(route.points, route.steps);
      final o = obstacle('o', east(160));
      expect(obstacleAheadToAnnounce(tracker, 100, [o], {'o'}, 'me'), isNull);
      expect(
        obstacleAheadToAnnounce(
          tracker,
          100,
          [obstacle('mine', east(160), by: 'me')],
          {},
          'me',
        ),
        isNull,
      );
      // A 10 m ci pensa la domanda "C'è ancora?".
      expect(obstacleAheadToAnnounce(tracker, 150, [o], {}, 'me'), isNull);
    });
  });
}
