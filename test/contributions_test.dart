import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/contributions.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/services/opening_hours.dart';
import 'package:freeway/widgets/contributions_sheet.dart';
import 'package:latlong2/latlong.dart';

const me = 'io';
const at = LatLng(45.54, 10.22);
final now = DateTime(2026, 11, 23, 12);

Obstacle report(
  String id, {
  String by = me,
  String type = 'Gradino che rende impossibile il passaggio',
  DateTime? when,
  List<String> confirmedBy = const [],
  List<String> thankedBy = const [],
  List<String> notThereBy = const [],
  List<String> passYesBy = const [],
  DateTime? lastNotThereAt,
}) => Obstacle(
  id: id,
  position: at,
  type: type,
  userId: by,
  reportedAt: when ?? now.subtract(const Duration(days: 3)),
  confirmedBy: confirmedBy,
  thankedBy: thankedBy,
  notThereBy: notThereBy,
  lastNotThereAt: lastNotThereAt,
  passYesBy: passYesBy,
);

void main() {
  test('conta le proprie segnalazioni e gli aiuti dati agli altri', () {
    final c = Contributions.of([
      report(
        'a',
        when: now.subtract(const Duration(days: 10)),
        confirmedBy: ['x', 'y'],
        thankedBy: ['x'],
      ),
      report('b', passYesBy: ['z']),
      report('c', by: 'altro', confirmedBy: [me], thankedBy: [me]),
      report('d', by: 'altro', passYesBy: [me]),
      report('e', by: 'altro'),
    ], me);
    expect(c.reports.map((o) => o.id), ['b', 'a']);
    expect(c.confirmationsReceived, 2);
    expect(c.thanksReceived, 1);
    expect(c.passVotesReceived, 1);
    expect(c.confirmationsGiven, 1);
    expect(c.passVotesGiven, 1);
    expect(c.thanksGiven, 1);
    // 2 segnalazioni × 3 + 2 aiuti.
    expect(c.points, 8);
    expect(c.level, ContributorLevel.explorer);
    expect(c.pointsToNextLevel, 2);
  });

  test('livelli', () {
    expect(ContributorLevel.forPoints(0), ContributorLevel.newcomer);
    expect(ContributorLevel.forPoints(10), ContributorLevel.guide);
    expect(ContributorLevel.forPoints(500), ContributorLevel.ambassador);
    expect(ContributorLevel.ambassador.next, isNull);
  });

  test('dice perché una segnalazione non si vede più', () {
    final dismissed = report(
      'a',
      notThereBy: ['x', 'y'],
      lastNotThereAt: now.subtract(const Duration(days: 1)),
    );
    final oldCar = report(
      'b',
      type: 'Auto parcheggiata su scivolo o marciapiede',
      when: now.subtract(const Duration(days: 30)),
    );
    expect(ReportStatus.of(dismissed, now), ReportStatus.dismissed);
    expect(ReportStatus.of(oldCar, now), ReportStatus.expired);
    expect(ReportStatus.of(report('c'), now), ReportStatus.visible);
    expect(Contributions.of([dismissed, oldCar], me).visibleReports(now), 0);
  });

  testWidgets('la scheda mostra livello e segnalazioni', (tester) async {
    Obstacle? opened;
    final c = Contributions.of([
      report('a', confirmedBy: ['x'], thankedBy: ['x', 'y']),
    ], me);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContributionsView(
            contributions: c,
            now: now,
            onOpen: (o) => opened = o,
          ),
        ),
      ),
    );
    expect(find.text('Le tue segnalazioni'), findsOneWidget);
    expect(find.text('Nuovo arrivo'), findsNothing);
    expect(find.text('Esploratore'), findsOneWidget);
    expect(find.text('3 punti'), findsOneWidget);
    expect(find.text('1 di 1 visibili sulla mappa'), findsOneWidget);
    expect(find.textContaining('1 conferma · 2 grazie'), findsOneWidget);
    await tester.tap(find.text('Gradino che rende impossibile il passaggio'));
    expect(opened?.id, 'a');
  });

  testWidgets('senza segnalazioni spiega come iniziare', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContributionsView(
            contributions: Contributions.of(const [], me),
            onOpen: (_) {},
          ),
        ),
      ),
    );
    expect(
      find.textContaining('Non hai ancora fatto segnalazioni'),
      findsOneWidget,
    );
    expect(find.text('Nuovo arrivo'), findsOneWidget);
  });

  test('formatClock', () {
    expect(formatClock(DateTime(2026, 1, 1, 9, 5)), '9:05');
  });
}
