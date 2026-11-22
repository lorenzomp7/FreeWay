import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/main.dart';
import 'package:freeway/screens/map_screen.dart';
import 'package:freeway/services/backend.dart';

void main() {
  tearDown(Backend.resetForTest);

  test('senza servizio dati non c\'è nessun utente', () {
    Backend.resetForTest();
    expect(Backend.available, isFalse);
    expect(Backend.userId, isNull);
  });

  test('senza servizio dati si apre subito la mappa, mai la manutenzione', () {
    expect(homeFor(backend: false), isA<MapScreen>());
    // Un link di un viaggio condiviso non può funzionare: si apre la mappa.
    expect(homeFor(backend: false, tripId: 'abc'), isA<MapScreen>());
  });

  test('con il servizio dati si passa dall\'accesso o dal viaggio', () {
    expect(homeFor(backend: true), isA<AuthGate>());
    expect(homeFor(backend: true, tripId: ''), isA<AuthGate>());
    expect(homeFor(backend: true, tripId: 'abc'), isA<Builder>());
  });

  test('l\'avviso spiega cosa funziona ancora', () {
    expect(kSharedFeaturesOff, contains('sospesi'));
    expect(kSharedFeaturesOff, contains('percorsi'));
  });
}
