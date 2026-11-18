import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/along_route_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

/// Percorso verso est di circa 400 m, un punto ogni 10 m.
final route = [
  for (var i = 0; i <= 40; i++) LatLng(45.54, 10.22 + i * 0.000128),
];

final overpass = {
  'elements': [
    {
      'type': 'node',
      'id': 2,
      'lat': 45.5401,
      'lon': 10.2245,
      'tags': {
        'amenity': 'cafe',
        'name': 'Bar Duomo',
        'toilets:wheelchair': 'yes',
      },
    },
    {
      'type': 'way',
      'id': 1,
      'center': {'lat': 45.5399, 'lon': 10.2210},
      'tags': {'amenity': 'toilets', 'wheelchair': 'limited'},
    },
    // Doppione: stesso elemento trovato da tutte e due le ricerche.
    {
      'type': 'node',
      'id': 2,
      'lat': 45.5401,
      'lon': 10.2245,
      'tags': {
        'amenity': 'cafe',
        'name': 'Bar Duomo',
        'toilets:wheelchair': 'yes',
      },
    },
  ],
};

void main() {
  test('i bagni sono in ordine lungo il percorso, senza doppioni', () {
    final toilets = AlongRouteService.parse(overpass, route);
    expect(toilets.map((t) => t.name), ['Bagno pubblico', 'Bar Duomo']);
    expect(toilets.first.isLimited, isTrue);
    expect(toilets.first.metersFromStart, closeTo(80, 10));
    expect(toilets.last.metersFromStart, closeTo(350, 10));
  });

  test('la query usa un corridoio intorno a pochi punti del percorso', () {
    final long = [
      for (var i = 0; i < 500; i++) LatLng(45.5, 10.2 + i * 0.0001),
    ];
    final sampled = AlongRouteService.samplePoints(long, 40);
    expect(sampled, hasLength(40));
    expect(sampled.first, long.first);
    expect(sampled.last, long.last);
    final query = AlongRouteService.buildQuery(route);
    expect(query, contains('around:80,45.540000,10.220000'));
    expect(query, contains('"amenity"="toilets"'));
    expect(query, contains('"toilets:wheelchair"'));
  });

  test('chiede a Overpass e se non risponde restituisce null', () async {
    final ok = AlongRouteService(
      client: MockClient((request) async {
        expect(request.url.host, 'overpass-api.de');
        expect(request.bodyFields['data'], contains('around:80'));
        return http.Response(jsonEncode(overpass), 200);
      }),
    );
    expect(await ok.accessibleToilets(route), hasLength(2));

    final down = AlongRouteService(
      client: MockClient((_) async => http.Response('busy', 504)),
    );
    expect(await down.accessibleToilets(route), isNull);
  });
}
