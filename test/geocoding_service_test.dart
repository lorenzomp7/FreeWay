import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/geocoding_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<Map<String, dynamic>> place(String name) => [
      {
        'display_name': name,
        'lat': '45.54',
        'lon': '10.22',
        'address': {'road': name, 'city': 'Brescia'},
      },
    ];

void main() {
  test('una ricerca già fatta non chiama di nuovo Nominatim', () async {
    var calls = 0;
    final service = GeocodingService(
      minInterval: Duration.zero,
      client: MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['accept-language'], 'it');
        return http.Response(jsonEncode(place('Via Branze')), 200);
      }),
    );

    expect((await service.search('via branze')).single['display_name'],
        'Via Branze');
    await service.search('  Via Branze ');
    expect(calls, 1);
  });

  test('se in Italia non trova nulla cerca ovunque', () async {
    final countries = <String?>[];
    final service = GeocodingService(
      minInterval: Duration.zero,
      client: MockClient((request) async {
        final country = request.url.queryParameters['countrycodes'];
        countries.add(country);
        return http.Response(
          jsonEncode(country == null ? place('Paris') : []),
          200,
        );
      }),
    );

    final results = await service.search('Paris');
    expect(countries, ['it', null]);
    expect(results.single['display_name'], 'Paris');
  });

  test('le richieste sono distanziate di almeno minInterval', () async {
    final times = <DateTime>[];
    final service = GeocodingService(
      minInterval: const Duration(milliseconds: 200),
      client: MockClient((request) async {
        times.add(DateTime.now());
        return http.Response(jsonEncode(place('x')), 200);
      }),
    );

    await Future.wait([
      service.search('uno'),
      service.search('due'),
      service.search('tre'),
    ]);

    expect(times, hasLength(3));
    for (var i = 1; i < times.length; i++) {
      expect(
        times[i].difference(times[i - 1]).inMilliseconds,
        greaterThanOrEqualTo(190),
      );
    }
  });

  test('i risultati di una ricerca superata vengono scartati', () async {
    final slow = Completer<void>();
    final service = GeocodingService(
      minInterval: Duration.zero,
      client: MockClient((request) async {
        final q = request.url.queryParameters['q'];
        if (q == 'bres') await slow.future;
        return http.Response(jsonEncode(place(q!)), 200);
      }),
    );

    final received = <String>[];
    service.searchDebounced(
        'bres', (r) => received.add(r.first['display_name'] as String));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    service.searchDebounced(
        'brescia', (r) => received.add(r.first['display_name'] as String));
    slow.complete();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(received, ['brescia']);
  });
}
