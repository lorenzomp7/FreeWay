import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/navigation_service.dart';
import 'package:freeway/services/obstacle_alerts.dart';
import 'package:freeway/widgets/navigation_prompts.dart';
import 'package:latlong2/latlong.dart';

LatLng east(double meters, {double north = 0}) =>
    LatLng(45.54 + north / 111195, 10.22 + meters / 77950);

void main() {
  test('chiede della deviazione solo se lì non c\'è già un ostacolo', () {
    final leftAt = east(100);
    expect(shouldAskAboutDeviation(leftAt, const []), isTrue);
    final near = Obstacle(id: 'n', position: east(120), type: 'Gradino');
    final far = Obstacle(id: 'f', position: east(300), type: 'Gradino');
    expect(shouldAskAboutDeviation(leftAt, [far]), isTrue);
    expect(shouldAskAboutDeviation(leftAt, [far, near]), isFalse);
  });

  test('la navigazione indica il punto del tracciato più vicino', () {
    final service = NavigationService()
      ..startWithoutGps(
        RouteOption(
          points: [east(0), east(300)],
          distance: 300,
          duration: 300,
          index: 0,
          steps: [
            RouteStep(
              instruction: 'depart||',
              location: east(0),
              maneuverType: 'depart',
              modifier: '',
            ),
            RouteStep(
              instruction: 'arrive||',
              location: east(300),
              maneuverType: 'arrive',
              modifier: '',
            ),
          ],
        ),
      );
    final update = service.handlePosition(east(150, north: 6), 5)!;
    final snapped = update.snappedPosition!;
    expect(snapped.latitude, closeTo(45.54, 1e-6));
    expect(snapped.longitude, closeTo(east(150).longitude, 1e-6));
    service.dispose();
  });

  testWidgets('"Sì, segnala" apre la segnalazione', (tester) async {
    var reported = false, dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviationObstacleCard(
            onReport: () => reported = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    expect(find.text('Hai cambiato strada per un ostacolo?'), findsOneWidget);
    await tester.tap(find.text('Sì, segnala'));
    await tester.tap(find.text('No'));
    expect(reported, isTrue);
    expect(dismissed, isTrue);
  });
}
