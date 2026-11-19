import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/widgets/navigation_prompts.dart';
import 'package:freeway/widgets/obstacle_sheets.dart';
import 'package:latlong2/latlong.dart';

Obstacle obstacle({
  List<String> yes = const [],
  List<String> hard = const [],
  List<String> no = const [],
  String? by,
}) => Obstacle(
  id: 'o',
  position: const LatLng(45.54, 10.22),
  type: 'Gradino',
  userId: by,
  passYesBy: yes,
  passHardBy: hard,
  passNoBy: no,
);

void main() {
  test('legge le risposte da Firestore', () {
    final o = Obstacle.fromMap('o', {
      'lat': 45.54,
      'lng': 10.22,
      'type': 'Gradino',
      'passYesBy': ['a', 'b'],
      'passNoBy': ['c'],
    });
    expect(o.passYesBy, ['a', 'b']);
    expect(o.passHardBy, isEmpty);
    expect(o.passNoBy, ['c']);
    expect(o.passVoteCount, 3);
  });

  test('superabile con almeno due "sì" in maggioranza', () {
    expect(obstacle(yes: ['a']).isWheelchairPassable, isFalse);
    expect(obstacle(yes: ['a', 'b']).isWheelchairPassable, isTrue);
    expect(
      obstacle(yes: ['a', 'b'], hard: ['c'], no: ['d']).isWheelchairPassable,
      isFalse,
    );
    expect(
      obstacle(yes: ['a', 'b', 'c'], no: ['d']).isWheelchairPassable,
      isTrue,
    );
  });

  test('si risponde una volta sola e non sulla propria segnalazione', () {
    expect(obstacle().canVotePassBy('me'), isTrue);
    expect(obstacle().canVotePassBy(null), isFalse);
    expect(obstacle(by: 'me').canVotePassBy('me'), isFalse);
    expect(obstacle(hard: ['me']).canVotePassBy('me'), isFalse);
  });

  test('riassunto delle risposte', () {
    expect(obstacle().passLabel, isNull);
    expect(
      obstacle(yes: ['a', 'b'], no: ['c']).passLabel,
      'In sedia a rotelle: si passa per 2 persone, non si passa per 1 persona',
    );
  });

  test('azioni della scheda e risposte', () {
    for (final vote in PassVote.values) {
      expect(ObstacleAction.forVote(vote).passVote, vote);
    }
    expect(ObstacleAction.confirm.passVote, isNull);
  });

  testWidgets('la scheda dell\'ostacolo chiede se si passa', (tester) async {
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
                    obstacle(yes: ['a']),
                    currentUserId: 'me',
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
    expect(
      find.text('Si riesce a passare in sedia a rotelle?'),
      findsOneWidget,
    );
    expect(
      find.text('In sedia a rotelle: si passa per 1 persona'),
      findsOneWidget,
    );
    await tester.tap(find.text('A fatica'));
    await tester.pumpAndSettle();
    expect(action, ObstacleAction.passHard);
  });

  testWidgets('la domanda in navigazione manda la risposta', (tester) async {
    PassVote? voted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PassabilityCard(
            obstacle: obstacle(),
            onVote: (v) => voted = v,
            onSkip: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('No'));
    expect(voted, PassVote.no);
  });
}
