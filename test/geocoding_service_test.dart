import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/geocoding_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

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

  test('favorisce i luoghi vicini alla zona inquadrata', () async {
    final origins = <String>[];
    final service = GeocodingService(
      client: MockClient((request) async {
        final q = request.url.queryParameters;
        origins.add('${q['lat']},${q['lon']}');
        return photonResult('Duomo');
      }),
    );
    addTearDown(service.dispose);

    await service.search('duomo', near: const LatLng(45.4642, 9.19));
    await service.search('duomo', near: const LatLng(45.4650, 9.191));
    await service.search('duomo', near: const LatLng(45.54, 10.22));

    // Due ricerche nella stessa zona usano la memoria, la terza no.
    expect(origins, ['45.4642,9.19', '45.54,10.22']);
  });

  test(
    'un luogo con nome mostra la via nel sottotitolo e il suo tipo',
    () async {
      final service = GeocodingService(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'Farmacia Centrale',
                    'street': 'Corso Zanardelli',
                    'housenumber': '12',
                    'city': 'Brescia',
                    'state': 'Lombardia',
                    'osm_key': 'amenity',
                    'osm_value': 'pharmacy',
                    'osm_type': 'N',
                    'osm_id': 42,
                  },
                  'geometry': {
                    'coordinates': [10.22, 45.54],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final place = (await service.search('farmacia')).single;
      expect(place['kind'], 'health');
      expect(place['osm_type'], 'N');
      expect(place['osm_id'], 42);
      final label = formatPlace(place);
      expect(label.title, 'Farmacia Centrale');
      expect(label.subtitle, 'Corso Zanardelli 12, Brescia, Lombardia');
    },
  );

  test('placeKind e formatDistance', () {
    expect(placeKind('place', 'city'), 'city');
    expect(placeKind('highway', 'residential'), 'street');
    expect(placeKind('highway', 'bus_stop'), 'transit');
    expect(placeKind('shop', 'bakery'), 'shop');
    expect(formatDistance(347), '350 m');
    expect(formatDistance(1234), '1,2 km');
    expect(formatDistance(23600), '24 km');
  });
}
