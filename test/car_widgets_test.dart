import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/disabled_parking.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/widgets/map_widgets.dart';
import 'package:freeway/widgets/route_options_sheet.dart';
import 'package:latlong2/latlong.dart';

RouteOption carRoute({DisabledParking? parking}) {
  return RouteOption(
      points: const [LatLng(45.54, 10.22), LatLng(45.541, 10.225)],
      distance: 1200,
      duration: 300,
      steps: const [],
      index: 0,
    )
    ..driveEndIndex = 1
    ..parking = parking
    ..walkDistance = 80
    ..walkDuration = 70
    ..label = 'Altro parcheggio';
}

void main() {
  Widget sheet(RouteOption route) => MaterialApp(
    home: Scaffold(
      body: RouteOptionsSheet(
        routes: [route],
        selectedIndex: 0,
        onSelect: (_) {},
        onStart: () {},
        onClose: () {},
      ),
    ),
  );

  testWidgets('in auto la scheda dice dove parcheggiare', (tester) async {
    await tester.pumpWidget(
      sheet(
        carRoute(
          parking: const DisabledParking(
            id: 'node/1',
            position: LatLng(45.541, 10.225),
            name: 'Parcheggio Ospedale',
            spaces: 2,
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Parcheggio Ospedale · 2 posti riservati'),
      findsOneWidget,
    );
    expect(find.textContaining('80 m'), findsWidgets);
    expect(find.textContaining('contrassegno'), findsOneWidget);
  });

  testWidgets('senza parcheggi vicini lo dice', (tester) async {
    await tester.pumpWidget(sheet(carRoute()));
    expect(
      find.textContaining('non risultano posti per disabili'),
      findsOneWidget,
    );
  });

  testWidgets('pulsante dei parcheggi sulla mappa', (tester) async {
    var toggled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapControls(
            onZoomIn: () {},
            onZoomOut: () {},
            onLocate: () {},
            isLocating: false,
            onToggleParking: () => toggled++,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Mostra i parcheggi per disabili'));
    expect(toggled, 1);
  });
}
