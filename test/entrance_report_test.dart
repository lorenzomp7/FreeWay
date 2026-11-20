import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/entrance_report.dart';
import 'package:freeway/services/entrance_report_service.dart';
import 'package:freeway/widgets/navigation_prompts.dart';
import 'package:freeway/widgets/place_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const place = LatLng(45.54, 10.22);
final now = DateTime(2026, 11, 18, 12);

EntranceReport report(
  EntranceAnswer answer, {
  double eastMeters = 0,
  DateTime? at,
}) => EntranceReport(
  position: LatLng(place.latitude, place.longitude + eastMeters / 77950),
  answer: answer,
  reportedAt: at ?? now.subtract(const Duration(days: 3)),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Risposte sull\'ingresso', () {
    test('conta solo quelle vicine e dell\'ultimo anno', () {
      final reports = [
        report(EntranceAnswer.accessible),
        report(EntranceAnswer.accessible, eastMeters: 20),
        report(EntranceAnswer.steps, eastMeters: 10),
        report(EntranceAnswer.steps, eastMeters: 200),
        report(
          EntranceAnswer.notFound,
          at: now.subtract(const Duration(days: 400)),
        ),
      ];
      final summary = EntranceSummary.of(
        nearbyRecent(reports, place, now: now),
      );
      expect(summary.accessible, 2);
      expect(summary.steps, 1);
      expect(summary.notFound, 0);
      expect(
        summary.label,
        'Ingresso secondo chi è arrivato qui: accessibile per 2 persone, '
        'con gradini per 1 persona',
      );
    });

    test('valori salvati e riletti', () {
      for (final answer in EntranceAnswer.values) {
        expect(EntranceAnswer.fromValue(answer.value), answer);
      }
      expect(EntranceAnswer.fromValue('forse'), isNull);
    });
  });

  group('Quante volte chiedere', () {
    test('al massimo 2 al giorno e 5 alla settimana', () {
      expect(ArrivalQuestionPolicy.allowed(const [], now), isTrue);
      final today = [
        now.subtract(const Duration(hours: 1)),
        now.subtract(const Duration(hours: 5)),
      ];
      expect(ArrivalQuestionPolicy.allowed(today, now), isFalse);
      final week = [
        for (var d = 1; d <= 5; d++) now.subtract(Duration(days: d, hours: 1)),
      ];
      expect(ArrivalQuestionPolicy.allowed(week, now), isFalse);
      expect(ArrivalQuestionPolicy.allowed(week.sublist(1), now), isTrue);
    });

    test('ricorda le domande fatte sul dispositivo', () async {
      final policy = ArrivalQuestionPolicy();
      expect(await policy.tryAsk(now: now), isTrue);
      expect(
        await policy.tryAsk(now: now.add(const Duration(hours: 1))),
        isTrue,
      );
      expect(
        await policy.tryAsk(now: now.add(const Duration(hours: 2))),
        isFalse,
      );
      expect(
        await ArrivalQuestionPolicy().tryAsk(
          now: now.add(const Duration(days: 1, hours: 1)),
        ),
        isTrue,
      );
    });
  });

  testWidgets('la domanda all\'arrivo manda la risposta scelta', (
    tester,
  ) async {
    EntranceAnswer? chosen;
    var skipped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArrivalEntranceCard(
            onAnswer: (a) => chosen = a,
            onSkip: () => skipped = true,
          ),
        ),
      ),
    );
    expect(find.text("Com'era l'ingresso?"), findsOneWidget);
    await tester.tap(find.text('Con gradini'));
    expect(chosen, EntranceAnswer.steps);
    await tester.tap(find.byTooltip('Chiudi'));
    expect(skipped, isTrue);
  });

  testWidgets('la scheda del luogo mostra le risposte', (tester) async {
    Widget sheet(EntranceSummary summary) => MaterialApp(
      home: Scaffold(
        body: PlaceSheet(
          title: 'Biblioteca',
          subtitle: 'Brescia',
          distanceText: null,
          nearbyObstacles: 0,
          entranceSummary: summary,
          onDirections: () {},
          onStart: () {},
          onShare: () {},
          onClose: () {},
        ),
      ),
    );
    await tester.pumpWidget(sheet(const EntranceSummary()));
    expect(find.textContaining('Ingresso secondo'), findsNothing);
    await tester.pumpWidget(
      sheet(const EntranceSummary(accessible: 3, notFound: 1)),
    );
    expect(
      find.text(
        'Ingresso secondo chi è arrivato qui: accessibile per 3 persone, '
        'non trovato da 1 persona',
      ),
      findsOneWidget,
    );
  });
}
