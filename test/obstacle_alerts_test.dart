import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/services/obstacle_alerts.dart';
import 'package:freeway/widgets/navigation_prompts.dart';
import 'package:latlong2/latlong.dart';

Obstacle obstacle(String id, double lng, {String? by, List<String>? ok}) =>
    Obstacle(
      id: id,
      position: LatLng(45.54, lng),
      type: 'Cantiere sul marciapiede',
      userId: by,
      confirmedBy: ok ?? const [],
    );

/// Percorso dritto verso est, un punto ogni 10 m circa.
final route = [
  for (var i = 0; i <= 40; i++) LatLng(45.54, 10.22 + i * 0.000128),
];

void main() {
  group("C'è ancora?", () {
    const here = LatLng(45.54, 10.2200);

    test("chiede dell'ostacolo più vicino entro 25 m", () {
      final near = obstacle('near', 10.2201); // ~8 m
      final close = obstacle('close', 10.2202); // ~16 m
      final far = obstacle('far', 10.2210); // ~80 m
      final asked = obstacleToVerify(here, [far, close, near], {}, 'me');
      expect(asked?.id, 'near');
      expect(obstacleToVerify(here, [far], {}, 'me'), isNull);
    });

    test('non chiede due volte, né delle proprie o già confermate', () {
      final o = obstacle('o', 10.2201);
      expect(obstacleToVerify(here, [o], {'o'}, 'me'), isNull);
      expect(
        obstacleToVerify(here, [obstacle('o', 10.2201, by: 'me')], {}, 'me'),
        isNull,
      );
      expect(
        obstacleToVerify(
          here,
          [
            obstacle('o', 10.2201, ok: ['me']),
          ],
          {},
          'me',
        ),
        isNull,
      );
    });
  });

  group('ostacoli sul percorso', () {
    test('conta solo il tratto ancora da fare', () {
      final behind = obstacle('behind', 10.2205); // ~40 m dalla partenza
      final ahead = obstacle('ahead', 10.2245); // più avanti
      final offRoute = Obstacle(
        id: 'off',
        position: const LatLng(45.5410, 10.2245), // ~110 m a nord
        type: 'Gradino',
      );
      final position = route[15]; // ~150 m dalla partenza
      final found = obstaclesAhead(route, position, [behind, ahead, offRoute]);
      expect(found.map((o) => o.id), ['ahead']);
      expect(routePassesNear(route, offRoute), isFalse);
      expect(nearestPointIndex(route, position), 15);
    });
  });

  group('riquadri della navigazione', () {
    Widget wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets("C'è ancora? con le tre risposte", (tester) async {
      final answers = <String>[];
      await tester.pumpWidget(
        wrap(
          ObstacleVerifyCard(
            obstacle: obstacle('o', 10.22),
            canRemove: true,
            onStillThere: () => answers.add('si'),
            onGone: () => answers.add('no'),
            onSkip: () => answers.add('boh'),
          ),
        ),
      );
      expect(find.text("C'è ancora?"), findsOneWidget);
      await tester.tap(find.text("C'è ancora"));
      await tester.tap(find.text("Non c'è più"));
      await tester.tap(find.text('Non so'));
      expect(answers, ['si', 'no', 'boh']);
    });

    testWidgets(
      "un ospite non vede \"Non c'è più\" sulle segnalazioni altrui",
      (tester) async {
        await tester.pumpWidget(
          wrap(
            ObstacleVerifyCard(
              obstacle: obstacle('o', 10.22),
              canRemove: false,
              onStillThere: () {},
              onGone: () {},
              onSkip: () {},
            ),
          ),
        );
        expect(find.text("Non c'è più"), findsNothing);
      },
    );

    testWidgets('nuovo ostacolo: alternativa con il tempo in più', (
      tester,
    ) async {
      var used = false;
      await tester.pumpWidget(
        wrap(
          RouteAlertCard(
            obstacle: obstacle('o', 10.22),
            isSearching: false,
            hasAlternative: true,
            extraMinutes: 2,
            onUseAlternative: () => used = true,
            onKeepRoute: () {},
          ),
        ),
      );
      expect(find.textContaining('2 min in più'), findsOneWidget);
      await tester.tap(find.text('Usa il nuovo percorso'));
      expect(used, isTrue);

      await tester.pumpWidget(
        wrap(
          RouteAlertCard(
            obstacle: obstacle('o', 10.22),
            isSearching: false,
            hasAlternative: false,
            extraMinutes: 0,
            onUseAlternative: () {},
            onKeepRoute: () {},
          ),
        ),
      );
      expect(find.textContaining('Nessun altro percorso'), findsOneWidget);
    });
  });
}
