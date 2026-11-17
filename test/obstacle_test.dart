import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/widgets/obstacle_sheets.dart';

Map<String, dynamic> report({Map<String, dynamic> extra = const {}}) => {
      'lat': 45.54,
      'lng': 10.22,
      'type': 'Gradino che rende impossibile il passaggio',
      'timestamp': Timestamp.fromDate(DateTime(2025, 3, 1, 10, 30)),
      'userId': 'alice',
      ...extra,
    };

void main() {
  group('Obstacle.fromMap', () {
    test('legge i campi della segnalazione', () {
      final obstacle = Obstacle.fromMap('o1', report());
      expect(obstacle.id, 'o1');
      expect(obstacle.position.latitude, 45.54);
      expect(obstacle.userId, 'alice');
      expect(obstacle.reportedAt, DateTime(2025, 3, 1, 10, 30));
      expect(obstacle.confirmationCount, 0);
    });

    test('usa la categoria salvata se valida', () {
      final obstacle = Obstacle.fromMap(
        'o1',
        report(extra: {'category': 'Sicurezza'}),
      );
      expect(obstacle.category, 'Sicurezza');
    });

    test('senza categoria salvata la ricava dal tipo', () {
      expect(Obstacle.fromMap('o1', report()).category,
          'Dislivello e pavimentazione');
      final invalid = Obstacle.fromMap('o1', report(extra: {'category': 'x'}));
      expect(invalid.category, 'Dislivello e pavimentazione');
    });

    test('legge le conferme', () {
      final obstacle = Obstacle.fromMap(
        'o1',
        report(extra: {
          'confirmedBy': ['bob', 'carla'],
          'lastConfirmedAt': Timestamp.fromDate(DateTime(2025, 3, 5)),
        }),
      );
      expect(obstacle.confirmationCount, 2);
      expect(obstacle.lastConfirmedAt, DateTime(2025, 3, 5));
    });
  });

  test('chi può confermare un ostacolo', () {
    final obstacle =
        Obstacle.fromMap('o1', report(extra: {'confirmedBy': ['bob']}));
    expect(obstacle.canBeConfirmedBy('alice'), isFalse, reason: 'autrice');
    expect(obstacle.canBeConfirmedBy('bob'), isFalse, reason: 'già confermato');
    expect(obstacle.canBeConfirmedBy('carla'), isTrue);
    expect(obstacle.canBeConfirmedBy(null), isFalse);
  });

  test('obstacleCategoryOf riconosce i tipi della lista e quelli vecchi', () {
    for (final entry in obstacleTypesByCategory.entries) {
      for (final type in entry.value) {
        expect(obstacleCategoryOf(type), entry.key);
      }
    }
    expect(obstacleCategoryOf('Cantieri sul marciapiede'), 'Ostacoli temporanei');
    expect(obstacleCategoryOf('Qualcos\'altro'), 'Altro');
  });

  test('timeAgo', () {
    final now = DateTime(2025, 3, 10, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
        'proprio ora');
    expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        '5 min fa');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), 'ieri');
    expect(timeAgo(now.subtract(const Duration(days: 65)), now: now),
        '2 mesi fa');
  });

  group('scadenza degli ostacoli temporanei', () {
    final reported = DateTime(2025, 3, 1);
    Obstacle make(String type, {DateTime? confirmed}) => Obstacle.fromMap('o', {
          'lat': 45.54,
          'lng': 10.22,
          'type': type,
          'timestamp': Timestamp.fromDate(reported),
          if (confirmed != null)
            'lastConfirmedAt': Timestamp.fromDate(confirmed),
        });

    test('gli ostacoli permanenti non scadono', () {
      final step = make('Gradino che rende impossibile il passaggio');
      expect(step.expiresAt, isNull);
      expect(step.isExpired(DateTime(2030)), isFalse);
    });

    test('un ostacolo temporaneo scade dopo 14 giorni', () {
      final car = make('Auto parcheggiata su scivolo o marciapiede');
      expect(car.expiresAt, DateTime(2025, 3, 15));
      expect(car.isExpired(DateTime(2025, 3, 14)), isFalse);
      expect(car.isExpired(DateTime(2025, 3, 16)), isTrue);
    });

    test('una conferma sposta la scadenza', () {
      final works = make(
        'Cantieri con percorsi accessibili bloccati',
        confirmed: DateTime(2025, 3, 10),
      );
      expect(works.expiresAt, DateTime(2025, 3, 24));
      expect(works.isExpired(DateTime(2025, 3, 20)), isFalse);
    });

    test('senza data (scrittura non ancora confermata) non scade', () {
      final pending = Obstacle.fromMap('o', {
        'lat': 1,
        'lng': 1,
        'type': 'Rifiuti o ingombri che ostruiscono il passaggio',
        'timestamp': null,
      });
      expect(pending.isExpired(DateTime(2030)), isFalse);
    });
  });
}
