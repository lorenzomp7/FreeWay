import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/arrival_side.dart';
import 'package:freeway/services/instruction_translator.dart';
import 'package:freeway/services/navigation_service.dart';
import 'package:freeway/widgets/navigation_panel.dart';
import 'package:latlong2/latlong.dart';

/// Percorso verso nord, un punto ogni 10 m circa.
final north = [for (var i = 0; i <= 5; i++) LatLng(45.54 + i * 0.00009, 10.22)];
final end = north.last;

void main() {
  group('lato della destinazione', () {
    test(
      'a destra, a sinistra o davanti rispetto alla direzione di marcia',
      () {
        expect(
          arrivalSide(north, LatLng(end.latitude, 10.2202)),
          ArrivalSide.right,
        );
        expect(
          arrivalSide(north, LatLng(end.latitude, 10.2198)),
          ArrivalSide.left,
        );
        expect(
          arrivalSide(north, LatLng(end.latitude + 0.0002, 10.22)),
          ArrivalSide.ahead,
        );
      },
    );

    test(
      'nessun lato se il percorso finisce sulla destinazione o alle spalle',
      () {
        expect(arrivalSide(north, end), isNull);
        expect(
          arrivalSide(north, LatLng(end.latitude - 0.0003, 10.22)),
          isNull,
        );
        expect(arrivalSide([end], LatLng(end.latitude, 10.23)), isNull);
      },
    );

    test(
      "la manovra d'arrivo prende il lato e lo dice in italiano e inglese",
      () {
        final route = RouteOption(
          points: north,
          distance: 50,
          duration: 40,
          steps: [
            RouteStep(
              instruction: 'depart||Via Roma',
              location: north.first,
              maneuverType: 'depart',
              modifier: '',
            ),
            RouteStep(
              instruction: 'arrive||Via Roma',
              location: end,
              maneuverType: 'arrive',
              modifier: '',
              streetName: 'Via Roma',
            ),
          ],
          index: 0,
        );
        applyArrivalSide(route, LatLng(end.latitude, 10.2198));
        expect(route.steps.last.instruction, 'arrive|left|Via Roma');
        expect(
          const InstructionTranslator(
            'it',
          ).translate(route.steps.last.instruction),
          'Sei arrivato/a su Via Roma: la destinazione è sulla sinistra',
        );
        expect(
          const InstructionTranslator('en').translate('arrive|right|'),
          'You have arrived: your destination is on the right',
        );
        // Senza lato resta il testo di prima.
        expect(
          const InstructionTranslator('it').translate('arrive||'),
          'Sei arrivato/a a destinazione',
        );
      },
    );
  });

  group('stato del GPS nel pannello di navigazione', () {
    final step = RouteStep(
      instruction: 'arrive|right|',
      location: end,
      maneuverType: 'arrive',
      modifier: 'right',
    );

    Widget panel(NavigationUpdate update, {bool lost = false}) => MaterialApp(
      home: Scaffold(
        body: NavigationPanel(
          update: update,
          firstStep: step,
          gpsFailed: false,
          signalLost: lost,
          language: 'it',
          isMuted: false,
          onStop: () {},
          onToggleMute: () {},
          onLanguageChanged: (_) {},
        ),
      ),
    );

    NavigationUpdate update({double accuracy = 5, bool arrived = false}) =>
        NavigationUpdate(
          position: end,
          currentStep: step,
          distanceToNextStep: 0,
          isOffRoute: false,
          progress: 1,
          hasArrived: arrived,
          accuracy: accuracy,
        );

    testWidgets('segnale perso e posizione poco precisa', (tester) async {
      await tester.pumpWidget(panel(update(), lost: true));
      expect(
        find.text('Segnale GPS perso — cerco la posizione…'),
        findsOneWidget,
      );

      await tester.pumpWidget(panel(update(accuracy: 85)));
      expect(
        find.text("Posizione poco precisa (±85 m): spostati all'aperto"),
        findsOneWidget,
      );

      await tester.pumpWidget(panel(update()));
      expect(find.textContaining('GPS'), findsNothing);
      expect(find.textContaining('poco precisa'), findsNothing);
    });

    testWidgets("all'arrivo dice da che lato è la destinazione", (
      tester,
    ) async {
      await tester.pumpWidget(panel(update(arrived: true)));
      expect(
        find.text('Sei arrivato/a: la destinazione è sulla destra'),
        findsOneWidget,
      );
    });
  });
}
