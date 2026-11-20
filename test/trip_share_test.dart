import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/screens/trip_viewer_screen.dart';
import 'package:freeway/services/trip_share_service.dart';
import 'package:latlong2/latlong.dart';

final now = DateTime(2026, 11, 20, 10);

SharedTrip trip({bool arrived = false, DateTime? updated, DateTime? expires}) =>
    SharedTrip(
      position: const LatLng(45.54, 10.22),
      destination: const LatLng(45.55, 10.23),
      destinationName: 'Piazza Loggia',
      remainingMeters: 650,
      remainingSeconds: 470,
      arrived: arrived,
      updatedAt: updated ?? now.subtract(const Duration(seconds: 10)),
      expiresAt: expires ?? now.add(const Duration(hours: 2)),
    );

Future<void> pumpViewer(WidgetTester tester, Stream<SharedTrip?> trips) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TripViewerScreen(
        tripId: 'abc',
        trips: trips,
        clock: () => now,
        showTiles: false,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('il link apre la pagina dell\'app con ?viaggio=id', () {
    final link = TripShareService.linkFor(
      'Tr1pAbCdEfGhIjKlMnOp',
      Uri.parse('https://lorenzomp7.github.io/FreeWay/?x=1#/mappa'),
    );
    expect(
      link.toString(),
      'https://lorenzomp7.github.io/FreeWay/?viaggio=Tr1pAbCdEfGhIjKlMnOp',
    );
  });

  test('il documento si legge, quello incompleto no', () {
    final read = SharedTrip.fromMap({
      'lat': 45.54,
      'lng': 10.22,
      'destLat': 45.55,
      'destLng': 10.23,
      'destName': 'Piazza Loggia',
      'arrived': false,
      'remainingMeters': 650,
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 1))),
    })!;
    expect(read.destinationName, 'Piazza Loggia');
    expect(read.remainingMeters, 650);
    expect(read.isExpired(now), isFalse);
    expect(SharedTrip.fromMap({'lat': 1}), isNull);
    expect(SharedTrip.fromMap(null), isNull);
  });

  test('senza aggiornamenti da oltre 2 minuti il viaggio è fermo', () {
    expect(trip().isStale(now), isFalse);
    expect(
      trip(updated: now.subtract(const Duration(minutes: 3))).isStale(now),
      isTrue,
    );
    expect(
      trip(
        arrived: true,
        updated: now.subtract(const Duration(minutes: 9)),
      ).isStale(now),
      isFalse,
    );
  });

  testWidgets('chi riceve il link vede destinazione e arrivo previsto', (
    tester,
  ) async {
    await pumpViewer(tester, Stream.value(trip()));
    expect(find.text('In viaggio verso Piazza Loggia'), findsOneWidget);
    expect(find.textContaining('Arrivo previsto tra 8 minuti'), findsOneWidget);
    expect(find.text('Posizione aggiornata adesso'), findsOneWidget);
  });

  testWidgets('all\'arrivo lo dice', (tester) async {
    await pumpViewer(tester, Stream.value(trip(arrived: true)));
    expect(find.text('Arrivo a destinazione'), findsOneWidget);
  });

  testWidgets('a condivisione finita o scaduta non mostra la posizione', (
    tester,
  ) async {
    await pumpViewer(tester, Stream.value(null));
    expect(find.text('La condivisione è terminata'), findsOneWidget);
    expect(find.bySemanticsLabel('Posizione di chi viaggia'), findsNothing);

    await pumpViewer(
      tester,
      Stream.value(trip(expires: now.subtract(const Duration(minutes: 1)))),
    );
    expect(find.text('La condivisione è terminata'), findsOneWidget);
  });
}
