import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/contributions.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/services/contribution_log_service.dart';
import 'package:freeway/widgets/contributions_sheet.dart';
import 'package:freeway/widgets/weekly_review_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const me = 'io';
final monday = DateTime(2026, 11, 9, 10);
final now = DateTime(2026, 11, 18, 9);

Obstacle report(
  String id, {
  String by = me,
  String type = 'Gradino che rende impossibile il passaggio',
  DateTime? when,
  List<String> confirmedBy = const [],
  DateTime? lastConfirmedAt,
  List<String> thankedBy = const [],
  List<String> passYesBy = const [],
  bool hasPhoto = false,
}) => Obstacle(
  id: id,
  position: const LatLng(45.54, 10.22),
  type: type,
  userId: by,
  reportedAt: when ?? monday,
  confirmedBy: confirmedBy,
  lastConfirmedAt: lastConfirmedAt,
  thankedBy: thankedBy,
  passYesBy: passYesBy,
  hasPhoto: hasPhoto,
);

void main() {
  test('settimana da lunedì a domenica, scritta in italiano', () {
    final week = DateRange.previousWeek(now);
    expect(week.start, DateTime(2026, 11, 9));
    expect(week.end, DateTime(2026, 11, 16));
    expect(week.label, 'dal 9 al 15 novembre 2026');
    expect(week.contains(DateTime(2026, 11, 15, 23, 59)), isTrue);
    expect(week.contains(DateTime(2026, 11, 16)), isFalse);
    expect(
      DateRange.weekOf(DateTime(2026, 12, 31)).label,
      'dal 28 dicembre 2026 al 3 gennaio 2027',
    );
    expect(
      DateRange.weekOf(DateTime(2026, 10, 1)).label,
      'dal 28 settembre al 4 ottobre 2026',
    );
  });

  test('il prossimo badge è quello più vicino', () {
    final none = Contributions.of(const [], me);
    expect(none.earnedBadges, isEmpty);
    expect(none.nextBadge!.id, 'first-report');

    final c = Contributions.of([
      report('a', hasPhoto: true),
      for (var i = 0; i < 8; i++) report('c$i', by: 'altro', confirmedBy: [me]),
    ], me);
    expect(c.earnedBadges.map((b) => b.id), ['first-report']);
    expect(c.nextBadge!.id, 'verifier');
    expect(c.nextBadge!.progress(c), 8);
  });

  test('il grazie dice i punti, il livello raggiunto o il nuovo badge', () {
    final empty = Contributions.of(const [], me);
    final one = Contributions.of([report('a')], me);
    final first = ContributionReward.between(empty, one);
    expect(first.points, 3);
    expect(first.levelReached, ContributorLevel.explorer);
    expect(first.message, '+3 punti. Nuovo badge: «Primo passo»!');

    final confirmed = Contributions.of([
      report('a'),
      report('b', by: 'altro', confirmedBy: [me]),
    ], me);
    final help = ContributionReward.between(one, confirmed);
    expect(help.message, '+1 punto. Ancora 6 punti per «Guida».');
    expect(help.isMilestone, isFalse);

    final guide = Contributions.of([
      for (var i = 0; i < 3; i++) report('r$i'),
      report('b', by: 'altro', confirmedBy: [me]),
    ], me);
    final level = ContributionReward.between(
      Contributions.of([for (var i = 0; i < 3; i++) report('r$i')], me),
      guide,
    );
    expect(level.message, '+1 punto. Ora sei al livello «Guida»!');

    // Senza punti nuovi (per esempio prima che arrivi la segnalazione)
    // non si aggiunge nulla.
    expect(ContributionReward.between(one, one).message, isEmpty);
  });

  test('la settimana conta segnalazioni, foto, aiuti e conferme ricevute', () {
    final c = Contributions.of([
      report(
        'a',
        hasPhoto: true,
        confirmedBy: ['x'],
        lastConfirmedAt: monday.add(const Duration(days: 1)),
      ),
      report('vecchia', when: DateTime(2026, 10, 1)),
      report('b', by: 'altro', confirmedBy: [me]),
    ], me);
    final review = WeeklyReview.of(
      c,
      [
        HelpEntry(HelpKind.confirm, 'b', monday),
        HelpEntry(HelpKind.pass, 'z', DateTime(2026, 11, 2)),
      ],
      DateRange.previousWeek(now),
      me,
    );
    expect(review.reports.map((o) => o.id), ['a']);
    expect(review.photos, 1);
    expect(review.count(HelpKind.confirm), 1);
    expect(review.count(HelpKind.pass), 0);
    expect(review.reportsConfirmed, 1);
    expect(review.total, 2);
  });

  test('suggerisce l\'ostacolo vicino non confermato da più tempo', () {
    final old = report('vecchio', by: 'altro', when: DateTime(2026, 9, 1));
    final distances = {'vecchio': 300.0, 'lontano': 3000.0, 'nuovo': 50.0};
    final suggestion = findVerifySuggestion(
      [
        old,
        report('lontano', by: 'altro', when: DateTime(2026, 9, 1)),
        report('nuovo', by: 'altro', when: DateTime(2026, 11, 17)),
        report('mio', when: DateTime(2026, 9, 1)),
        report(
          'confermato',
          by: 'altro',
          when: DateTime(2026, 9, 1),
          confirmedBy: [me],
        ),
      ],
      me,
      now,
      (o) => distances[o.id] ?? 10,
    );
    expect(suggestion?.obstacle.id, 'vecchio');
    expect(suggestion?.distance, 300);
  });

  group('registro sul dispositivo', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('resta dopo il riavvio, per utente e senza doppioni', () async {
      final log = ContributionLogService();
      final help = HelpEntry(HelpKind.confirm, 'b', monday);
      await log.add(me, help);
      await log.add(me, help);
      final reloaded = await ContributionLogService().load(me);
      expect(reloaded, hasLength(1));
      expect(reloaded.single.at, monday);
      expect(await ContributionLogService().load('altro'), isEmpty);
    });

    test('il riepilogo di una settimana si mostra una volta', () async {
      final log = ContributionLogService();
      final week = DateRange.previousWeek(now);
      expect(await log.wasWeekShown(me, week), isFalse);
      await log.markWeekShown(me, week);
      expect(await log.wasWeekShown(me, week), isTrue);
      expect(await log.wasWeekShown(me, DateRange.weekOf(now)), isFalse);
    });

    test('dati rovinati non bloccano l\'app', () async {
      SharedPreferences.setMockInitialValues({
        ContributionLogService.helpsKey(me): '[{"kind":"x"}, 3',
      });
      expect(await ContributionLogService().load(me), isEmpty);
    });
  });

  testWidgets('"La tua settimana" come "Your week in review"', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = Contributions.of([
      report(
        'a',
        hasPhoto: true,
        confirmedBy: ['x'],
        lastConfirmedAt: monday.add(const Duration(days: 1)),
        thankedBy: ['y'],
      ),
      report('b', by: 'altro', confirmedBy: [me]),
    ], me);
    final review = WeeklyReview.of(
      c,
      [HelpEntry(HelpKind.confirm, 'b', monday)],
      DateRange.previousWeek(now),
      me,
    );
    final suggestion = VerifySuggestion(
      report(
        'z',
        by: 'altro',
        type: 'Tornelli non accessibili',
        when: DateTime(2026, 8, 1),
      ),
      120,
    );
    WeeklyReviewAction? action;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => action = await showWeeklyReviewSheet(
                context,
                review: review,
                contributions: c,
                suggestion: suggestion,
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(find.text('La tua settimana'), findsOneWidget);
    expect(
      find.text('Hai fatto 2 contributi dal 9 al 15 novembre 2026'),
      findsOneWidget,
    );
    expect(find.text('La tua segnalazione più recente'), findsOneWidget);
    expect(
      find.textContaining('hanno confermato una tua segnalazione'),
      findsOneWidget,
    );
    expect(find.text('Una persona ti ha detto grazie.'), findsOneWidget);
    // 3 punti per la segnalazione + 1 per la conferma data.
    expect(find.text('Ancora 6 punti per «Guida»'), findsOneWidget);
    expect(find.text('Tornelli non accessibili'), findsOneWidget);
    expect(find.text('Il tuo prossimo badge è vicino!'), findsOneWidget);

    await tester.tap(find.text('Verifica'));
    await tester.pumpAndSettle();
    expect(action, WeeklyReviewAction.verify);
  });

  testWidgets('"Le tue segnalazioni" mostra badge e ostacolo da verificare', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Obstacle? opened;
    final old = report('z', by: 'altro', when: DateTime(2026, 8, 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContributionsView(
            contributions: Contributions.of([report('a')], me),
            suggestion: VerifySuggestion(old, 240),
            now: now,
            onOpen: (o) => opened = o,
          ),
        ),
      ),
    );
    expect(
      find.text('Badge (1 su ${contributionBadges.length})'),
      findsOneWidget,
    );
    expect(find.text('Primo passo'), findsOneWidget);
    expect(find.textContaining('a 240 m da te'), findsOneWidget);
    await tester.tap(find.text('Verifica'));
    expect(opened?.id, 'z');
  });
}
