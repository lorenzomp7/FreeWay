import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/heading.dart';
import 'package:freeway/widgets/map_widgets.dart';
import 'package:latlong2/latlong.dart';

const origin = LatLng(45.5389, 10.2200);
LatLng north(double m) =>
    LatLng(origin.latitude + m / 111320, origin.longitude);
LatLng east(double m, [LatLng from = origin]) =>
    LatLng(from.latitude, from.longitude + m / 78000);

void main() {
  test('direzione tra due punti', () {
    expect(bearingBetween(origin, north(100)), closeTo(0, 0.5));
    expect(bearingBetween(origin, east(100)), closeTo(90, 0.5));
    expect(bearingBetween(north(100), origin), closeTo(180, 0.5));
    expect(bearingBetween(east(100), origin), closeTo(270, 0.5));
  });

  test('differenza tra angoli passando per il nord', () {
    expect(angleDifference(350, 10), 20);
    expect(angleDifference(10, 350), -20);
    expect(angleDifference(90, 270).abs(), 180);
    expect(normalizeDegrees(-30), 330);
    expect(normalizeDegrees(720), 0);
  });

  test('direzione del percorso dove ci si trova', () {
    // Prima verso nord per 100 m, poi verso est.
    final corner = north(100);
    final route = [origin, north(50), corner, east(100, corner)];
    expect(routeBearingAt(route, north(10), lookAhead: 10), closeTo(0, 3));
    expect(
      routeBearingAt(route, east(60, corner), lookAhead: 10),
      closeTo(90, 3),
    );
    expect(routeBearingAt([origin], origin), isNull);
  });

  test('la bussola smorzata non salta tra 359 e 1 gradi', () {
    final smoother = HeadingSmoother(factor: 0.5);
    smoother.add(359);
    final value = smoother.add(1);
    expect(angleDifference(value, 0).abs(), lessThan(1));
    smoother.reset();
    expect(smoother.value, isNull);
  });

  test('punti cardinali per i lettori di schermo', () {
    expect(compassPointName(0), 'nord');
    expect(compassPointName(44), 'nord-est');
    expect(compassPointName(181), 'sud');
    expect(compassPointName(350), 'nord');
  });

  testWidgets('il pallino con la direzione lo dice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: UserLocationDot(heading: 90))),
    );
    expect(
      find.bySemanticsLabel('La tua posizione, guardi verso est'),
      findsOneWidget,
    );
  });

  testWidgets('pulsante della bussola', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CompassButton(
            mapRotation: -90,
            headingUp: false,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CompassButton));
    expect(taps, 1);
    expect(find.bySemanticsLabel(RegExp('nord in alto')), findsOneWidget);
  });
}
