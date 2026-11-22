import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/models/transit.dart';
import 'package:freeway/widgets/route_options_sheet.dart';
import 'package:latlong2/latlong.dart';

const a = LatLng(45.53, 10.22);
const b = LatLng(45.54, 10.23);
const c = LatLng(45.56, 10.25);

TransitLeg leg(
  TransitVehicle vehicle,
  int fromMin,
  int toMin, {
  String line = '',
  TransitAccess access = TransitAccess.unknown,
}) => TransitLeg(
  vehicle: vehicle,
  line: line,
  headsign: vehicle == TransitVehicle.walk ? '' : 'Centro',
  fromName: 'Fermata A',
  toName: 'Fermata B',
  departure: DateTime(2026, 11, 23, 8, fromMin),
  arrival: DateTime(2026, 11, 23, 8, toMin),
  points: const [a, b],
  access: access,
);

RouteOption transitRoute(TransitAccess access) =>
    RouteOption(
        points: const [a, b, c],
        distance: 2000,
        duration: 1500,
        steps: const [],
        index: 0,
      )
      ..transitLegs = [
        leg(TransitVehicle.walk, 0, 4),
        leg(TransitVehicle.bus, 6, 20, line: '10', access: access),
        leg(TransitVehicle.walk, 20, 25),
      ]
      ..departureTime = DateTime(2026, 11, 23, 8)
      ..arrivalTime = DateTime(2026, 11, 23, 8, 25);

Widget wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('la scheda mostra orari, mezzi e accessibilità', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          height: 150,
          child: RouteCard(
            route: transitRoute(TransitAccess.accessible),
            isSelected: true,
            onTap: () {},
            departure: DateTime(2026, 11, 23, 7, 50),
          ),
        ),
      ),
    );
    expect(find.text('8:00–8:25'), findsOneWidget);
    expect(find.text('🚶 4 min › 🚌 10 › 🚶 5 min'), findsOneWidget);
    expect(find.text('Mezzi accessibili'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('riga dell\'accessibilità', () {
    expect(
      TransitAccessLine.label(
        transitRoute(TransitAccess.notAccessible).transitLegs,
      ),
      '1 mezzo non accessibile',
    );
    expect(
      TransitAccessLine.label(transitRoute(TransitAccess.unknown).transitLegs),
      'Accessibilità non indicata',
    );
  });

  testWidgets('elenco dei mezzi e link obbligatorio alle fonti', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(TransitInfo(route: transitRoute(TransitAccess.notAccessible))),
    );
    expect(
      find.textContaining('Bus 10 → Centro da Fermata A a Fermata B'),
      findsOneWidget,
    );
    expect(find.textContaining('non accessibile'), findsOneWidget);
    expect(find.textContaining('Transitous'), findsOneWidget);
    expect(find.textContaining('non evitano gli ostacoli'), findsOneWidget);
    // Fuori dal browser il link non apre nulla ma non deve rompersi.
    await tester.tap(find.textContaining('Transitous'));
  });
}
