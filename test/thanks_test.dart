import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/services/thanks_notifier.dart';
import 'package:freeway/widgets/obstacle_sheets.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

Obstacle obstacle(String id, {String? by, List<String> thanks = const []}) =>
    Obstacle(
      id: id,
      position: const LatLng(45.54, 10.22),
      type: 'Gradino',
      userId: by,
      thankedBy: thanks,
    );

Future<ObstacleAction?> openSheet(
  WidgetTester tester,
  Obstacle o,
  String? userId,
) async {
  ObstacleAction? action;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                action = await showObstacleDetailsSheet(
                  context,
                  o,
                  currentUserId: userId,
                );
              },
              child: const Text('Apri'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Apri'));
  await tester.pumpAndSettle();
  return action;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('si ringrazia una volta, solo chi è noto e non se stessi', () {
    expect(obstacle('a', by: 'bob').canBeThankedBy('me'), isTrue);
    expect(
      obstacle('a', by: 'bob', thanks: ['me']).canBeThankedBy('me'),
      isFalse,
    );
    expect(obstacle('a', by: 'me').canBeThankedBy('me'), isFalse);
    expect(obstacle('a').canBeThankedBy('me'), isFalse);
    expect(obstacle('a', by: 'bob').canBeThankedBy(null), isFalse);
  });

  test('conta i grazie ricevuti dalle proprie segnalazioni', () {
    final all = [
      obstacle('a', by: 'me', thanks: ['x', 'y']),
      obstacle('b', by: 'me', thanks: ['z']),
      obstacle('c', by: 'bob', thanks: ['me']),
    ];
    expect(thanksReceived(all, 'me'), 3);
    expect(thanksReceived(all, null), 0);
  });

  test('annuncia solo i grazie nuovi, non alla prima lettura', () async {
    final notifier = ThanksNotifier();
    expect(await notifier.newThanks('me', 3), 0);
    expect(await notifier.newThanks('me', 3), 0);
    expect(await notifier.newThanks('me', 5), 2);
    expect(await ThanksNotifier().newThanks('me', 5), 0);
    expect(await notifier.newThanks('other', 1), 0);
  });

  test('testo dei grazie', () {
    expect(thanksText(1, mine: false), 'Ringraziato da 1 persona');
    expect(
      thanksText(4, mine: true),
      '4 persone ti hanno ringraziato per questa segnalazione',
    );
  });

  testWidgets('la scheda manda il grazie', (tester) async {
    late Future<ObstacleAction?> pending;
    await tester.pumpWidget(const SizedBox());
    pending = openSheet(tester, obstacle('a', by: 'bob', thanks: ['x']), 'me');
    await pending;
    expect(find.text('Ringraziato da 1 persona'), findsOneWidget);
    expect(find.text("Grazie a chi l'ha segnalato"), findsOneWidget);
  });

  testWidgets('chi ha segnalato vede i grazie ma non il pulsante', (
    tester,
  ) async {
    await openSheet(tester, obstacle('a', by: 'me', thanks: ['x', 'y']), 'me');
    expect(
      find.text('2 persone ti hanno ringraziato per questa segnalazione'),
      findsOneWidget,
    );
    expect(find.text("Grazie a chi l'ha segnalato"), findsNothing);
  });
}
