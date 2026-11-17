import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/geocoding_service.dart';
import 'package:freeway/services/instruction_translator.dart';
import 'package:freeway/widgets/navigation_panel.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('Mostra la prima manovra e Termina anche senza posizione GPS',
      (tester) async {
    var stopped = false;
    for (final gpsFailed in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: NavigationPanel(
            update: null,
            firstStep: RouteStep(
              instruction: 'turn|left|Via Roma',
              location: const LatLng(45.46, 9.19),
              maneuverType: 'turn',
              modifier: 'left',
            ),
            gpsFailed: gpsFailed,
            language: 'it',
            isMuted: false,
            onStop: () => stopped = true,
            onToggleMute: () {},
            onLanguageChanged: (_) {},
          ),
        ),
      ));
      expect(find.text('Svolta a sinistra su Via Roma'), findsOneWidget);
      expect(
        find.text(gpsFailed
            ? 'GPS non disponibile. Controlla i permessi di posizione.'
            : 'In attesa del GPS…'),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('Termina'));
    expect(stopped, isTrue);
  });

  group('InstructionTranslator', () {
    test('traduce una svolta in italiano', () {
      const translator = InstructionTranslator('it');
      expect(
        translator.translate('turn|left|Via Roma'),
        'Svolta a sinistra su Via Roma',
      );
    });

    test("traduce l'arrivo in inglese", () {
      const translator = InstructionTranslator('en');
      expect(
          translator.translate('arrive||'), 'You have arrived at destination');
    });
  });

  test('RouteOption formatta distanza, durata e punteggio', () {
    final route = RouteOption(
      points: const [LatLng(45.46, 9.19)],
      distance: 1530,
      duration: 3900,
      steps: const [],
      index: 0,
    )..obstacleCount = 1;
    expect(route.distanceText, '1.5 km');
    expect(route.durationText, '1h 5min');
    expect(route.accessibilityScore, 85);
  });

  test('formatPlace usa via e città di Nominatim', () {
    final label = formatPlace({
      'display_name': 'Via Roma, Brescia, Lombardia, Italia',
      'address': {'road': 'Via Roma', 'city': 'Brescia', 'county': 'Brescia'},
    });
    expect(label.title, 'Via Roma');
    expect(label.subtitle, 'Brescia, Brescia');
  });
}
