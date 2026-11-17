import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/geocoding_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response photonResult(String name) => http.Response(
  jsonEncode({
    'features': [
      {
        'properties': {'name': name, 'city': name, 'state': 'Lombardia'},
        'geometry': {
          'coordinates': [10.22, 45.54],
        },
      },
    ],
  }),
  200,
);

void main() {
  test('cerca una città su Photon e riusa i risultati dalla cache', () async {
    var calls = 0;
    final service = GeocodingService(
      client: MockClient((request) async {
        calls++;
        expect(request.url.host, 'photon.komoot.io');
        expect(request.url.queryParameters['q'], 'brescia');
        expect(request.url.queryParameters, isNot(contains('countrycodes')));
        return photonResult('Brescia');
      }),
    );
    addTearDown(service.dispose);

    final result = (await service.search('brescia')).single;
    expect(result['lat'], 45.54);
    expect(result['lon'], 10.22);
    expect(formatPlace(result).title, 'Brescia');
    expect(formatPlace(result).subtitle, 'Lombardia');
    await service.search('  Brescia ');
    expect(calls, 1);
  });

  test(
    'una ricerca lenta non blocca né sostituisce quella successiva',
    () async {
      final slow = Completer<http.Response>();
      final slowStarted = Completer<void>();
      final latest = Completer<String>();
      final received = <String>[];
      final service = GeocodingService(
        client: MockClient((request) async {
          final query = request.url.queryParameters['q'];
          if (query == 'bres') {
            slowStarted.complete();
            return slow.future;
          }
          return photonResult('Brescia');
        }),
      );
      addTearDown(service.dispose);

      service.searchDebounced(
        'bres',
        (results) => received.add(formatPlace(results.single).title),
        onError: () => fail('La prima ricerca è fallita'),
      );
      await slowStarted.future;
      service.searchDebounced(
        'brescia',
        (results) => latest.complete(formatPlace(results.single).title),
        onError: () => latest.completeError(StateError('Ricerca fallita')),
      );
      expect(
        await latest.future.timeout(const Duration(seconds: 2)),
        'Brescia',
      );
      slow.complete(photonResult('Risultato superato'));
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
    },
  );

  test(
    'un errore HTTP viene segnalato e la ricerca può essere ripetuta',
    () async {
      var calls = 0;
      final service = GeocodingService(
        client: MockClient((_) async {
          calls++;
          return calls == 1 ? http.Response('', 503) : photonResult('Brescia');
        }),
      );
      addTearDown(service.dispose);

      await expectLater(
        service.search('Brescia'),
        throwsA(isA<http.ClientException>()),
      );
      expect((await service.search('Brescia')).single['name'], 'Brescia');
    },
  );
}
