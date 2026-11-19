import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/position_filter.dart';
import 'package:latlong2/latlong.dart';

final t0 = DateTime(2026, 11, 18, 10);

PositionFix fix(double eastMeters, double accuracy, int seconds) => PositionFix(
  LatLng(45.54, 10.22 + eastMeters / 77950),
  accuracy,
  t0.add(Duration(seconds: seconds)),
);

void main() {
  test('accetta posizioni normali a passo d\'uomo', () {
    final filter = PositionFilter();
    expect(filter.accept(fix(0, 8, 0)), isTrue);
    expect(filter.accept(fix(5, 10, 4)), isTrue);
    expect(filter.accept(fix(10, 6, 8)), isTrue);
  });

  test('scarta posizioni vecchie o ripetute', () {
    final filter = PositionFilter();
    expect(filter.accept(fix(0, 8, 10)), isTrue);
    expect(filter.accept(fix(2, 8, 10)), isFalse);
    expect(filter.accept(fix(2, 8, 5)), isFalse);
  });

  test('una stima dalla rete non sostituisce un buon GPS recente', () {
    final filter = PositionFilter();
    expect(filter.accept(fix(0, 10, 0)), isTrue);
    expect(filter.accept(fix(300, 1500, 3)), isFalse);
    expect(filter.last!.accuracy, 10);
    // Dopo che il GPS è vecchio, la stima si accetta.
    expect(filter.accept(fix(300, 1500, 30)), isTrue);
  });

  test('scarta i salti impossibili ma non resta bloccato', () {
    final filter = PositionFilter();
    expect(filter.accept(fix(0, 5, 0)), isTrue);
    // 200 m in 2 secondi: un rimbalzo del segnale.
    expect(filter.accept(fix(200, 5, 2)), isFalse);
    expect(filter.accept(fix(205, 5, 3)), isFalse);
    expect(filter.accept(fix(210, 5, 4)), isFalse);
    // Alla quarta di fila ci si fida: ci si è davvero spostati.
    expect(filter.accept(fix(215, 5, 5)), isTrue);
    expect(filter.accept(fix(218, 5, 7)), isTrue);
  });

  test('remember prende la posizione senza controllarla', () {
    final filter = PositionFilter()..accept(fix(0, 5, 0));
    filter.remember(fix(500, 5, 1));
    expect(filter.accept(fix(502, 5, 2)), isTrue);
  });
}
