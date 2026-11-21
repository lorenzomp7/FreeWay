import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/models/travel_mode.dart';
import 'package:freeway/services/geo_utils.dart';
import 'package:freeway/services/routing_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const start = LatLng(45.5400, 10.2200);
const end = LatLng(45.5400, 10.2260);

/// Ostacolo sulla linea retta tra partenza e arrivo.
final obstacle = Obstacle(
  id: 'o1',
  position: const LatLng(45.5400, 10.2230),
  type: 'Gradino che rende impossibile il passaggio',
);

/// Risposta GeoJSON di OpenRouteService con un solo percorso.
Map<String, dynamic> orsResponse(List<List<double>> lngLat, double distance) {
  return {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Feature',
        'geometry': {'type': 'LineString', 'coordinates': lngLat},
        'properties': {
          'summary': {'distance': distance, 'duration': distance / 1.1},
          'segments': [
            {
              'distance': distance,
              'duration': distance / 1.1,
              'steps': [
                {
                  'distance': distance,
                  'duration': distance / 1.1,
                  'type': 11,
                  'instruction': 'Head east',
                  'name': 'Via Branze',
                  'way_points': [0, lngLat.length - 1],
                },
                {
                  'distance': 0,
                  'duration': 0,
                  'type': 10,
                  'instruction': 'Arrive',
                  'name': '-',
                  'way_points': [lngLat.length - 1, lngLat.length - 1],
                },
              ],
            },
          ],
        },
      },
    ],
  };
}

/// Percorso dritto con un punto ogni 8 m circa, che passa sopra l'ostacolo.
final straight = orsResponse([
  for (var i = 0; i <= 60; i++) [10.2200 + i * 0.0001, 45.5400],
], 470);

/// Percorso che passa un isolato più a nord.
final detour = orsResponse([
  [10.2200, 45.5400],
  [10.2200, 45.5410],
  [10.2230, 45.5410],
  [10.2260, 45.5410],
  [10.2260, 45.5400],
], 690);

void main() {
  group('parseOrsRoutes', () {
    test('converte geometria, distanze e manovre', () {
      final routes = RoutingService.parseOrsRoutes(straight);
      expect(routes, hasLength(1));
      final route = routes.single;
      expect(route.points.first, start);
      expect(route.points.last, end);
      expect(route.distance, 470);
      expect(route.steps.first.maneuverType, 'depart');
      expect(route.steps.first.instruction, 'depart||Via Branze');
      expect(route.steps.last.maneuverType, 'arrive');
      expect(route.steps.last.streetName, '');
      expect(route.steps.last.location, end);
    });

    test('ignora risposte senza percorsi', () {
      expect(RoutingService.parseOrsRoutes({'features': []}), isEmpty);
      expect(RoutingService.parseOrsRoutes({}), isEmpty);
    });
  });

  test('avoidPolygons crea un quadrato chiuso di circa 30 m', () {
    final polygons = RoutingService.avoidPolygons([obstacle]);
    expect(polygons['type'], 'MultiPolygon');
    final ring = (polygons['coordinates'] as List).single.single as List;
    expect(ring, hasLength(5));
    expect(ring.first, ring.last);
    final sw = LatLng(ring[0][1] as double, ring[0][0] as double);
    final se = LatLng(ring[1][1] as double, ring[1][0] as double);
    final ne = LatLng(ring[2][1] as double, ring[2][0] as double);
    expect(haversineDistance(sw, se), closeTo(30, 1));
    expect(haversineDistance(se, ne), closeTo(30, 1));
  });

  test('obstaclesNear esclude gli ostacoli lontani dal tragitto', () {
    final far = Obstacle(
      id: 'far',
      position: const LatLng(45.60, 10.30),
      type: 'Tratto con sassi/ghiaia',
    );
    final near = RoutingService.obstaclesNear(start, end, [far, obstacle]);
    expect(near.map((o) => o.id), ['o1']);
  });

  group('getRoutes', () {
    test(
      'con la chiave usa il profilo sedia a rotelle ed evita gli ostacoli',
      () async {
        final requests = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          expect(request.url.host, 'api.openrouteservice.org');
          expect(request.url.path, '/v2/directions/wheelchair/geojson');
          expect(request.headers['Authorization'], 'test-key');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          final avoids = body['options']?['avoid_polygons'] != null;
          return http.Response(jsonEncode(avoids ? detour : straight), 200);
        });
        final service = RoutingService(client: client, orsApiKey: 'test-key');

        final routes = await service.getRoutes(start, end, [obstacle]);

        expect(requests, hasLength(2));
        expect(
          requests.where((b) => b['alternative_routes'] != null),
          hasLength(1),
        );
        expect(routes, hasLength(2));
        expect(routes.first.obstacleCount, 0);
        expect(routes.first.distance, 690);
        expect(routes.first.label, 'Evita ostacoli');
        expect(routes.first.isRecommended, isTrue);
        expect(routes.last.obstacleCount, 1);
      },
    );

    test('senza ostacoli vicini fa una sola richiesta', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(jsonEncode(straight), 200);
      });
      final service = RoutingService(client: client, orsApiKey: 'test-key');

      final routes = await service.getRoutes(start, end, []);

      expect(calls, 1);
      expect(routes.single.label, 'Consigliato');
    });

    test('se OpenRouteService fallisce ripiega su OSRM', () async {
      final hosts = <String>[];
      final client = MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'api.openrouteservice.org') {
          return http.Response('{"error":"quota"}', 403);
        }
        return http.Response(jsonEncode(osrmResponse), 200);
      });
      final service = RoutingService(client: client, orsApiKey: 'test-key');

      final routes = await service.getRoutes(start, end, []);

      // Prima Valhalla (qui risponde senza percorsi), poi OSRM pedonale.
      expect(hosts, contains('valhalla1.openstreetmap.de'));
      expect(hosts.last, 'routing.openstreetmap.de');
      expect(routes.single.distance, 470);
      expect(routes.single.provider, 'osrm');
    });

    test('senza chiave non chiama OpenRouteService', () async {
      final hosts = <String>[];
      final client = MockClient((request) async {
        hosts.add(request.url.host);
        return http.Response(jsonEncode(osrmResponse), 200);
      });
      final service = RoutingService(client: client, orsApiKey: '');

      expect(service.usesWheelchairProfile, isFalse);
      await service.getRoutes(start, end, []);
      expect(hosts, isNot(contains('api.openrouteservice.org')));
      expect(hosts, contains('routing.openstreetmap.de'));
    });

    test('a piedi usa foot-walking e non chiede zone da evitare', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(straight), 200);
      });
      final service = RoutingService(client: client, orsApiKey: 'test-key');

      final routes = await service.getRoutes(start, end, [
        obstacle,
      ], mode: TravelMode.walking);

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/v2/directions/foot-walking/geojson');
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['options'], isNull);
      // L'ostacolo non viene evitato, ma resta contato sul percorso.
      expect(routes.single.obstacleCount, 1);
      expect(routes.single.label, 'Più veloce');
    });

    test('a piedi senza chiave usa OSRM senza deviazioni', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        // Il server con il profilo pedonale: il server dimostrativo di
        // OSRM ha solo l'auto. A piedi Valhalla non serve.
        expect(request.url.host, 'routing.openstreetmap.de');
        expect(request.url.path, startsWith('/routed-foot/route/v1/foot/'));
        return http.Response(jsonEncode(osrmResponse), 200);
      });
      final service = RoutingService(client: client, orsApiKey: '');

      final routes = await service.getRoutes(start, end, [
        obstacle,
      ], mode: TravelMode.walking);

      // Nessuna richiesta in più per girare intorno all'ostacolo.
      expect(calls, 1);
      expect(routes.single.label, 'Più veloce');
    });
  });

  group('tappe intermedie', () {
    RouteStep step(String type, String street) => RouteStep(
          instruction: '$type||$street',
          location: start,
          maneuverType: type,
          modifier: '',
          streetName: street,
        );

    test("l'arrivo a una tappa diventa \"Hai raggiunto la tappa\"", () {
      final legs = [
        [step('depart', 'Via A'), step('turn', 'Via B'), step('arrive', 'Via B')],
        [step('depart', 'Via B'), step('arrive', 'Via C')],
      ];
      final joined = RoutingService.joinLegs(legs, keepStops: true);
      expect(joined.map((s) => s.maneuverType),
          ['depart', 'turn', 'stop', 'continue', 'arrive']);
      final detour = RoutingService.joinLegs(legs, keepStops: false);
      expect(detour.map((s) => s.maneuverType),
          ['depart', 'turn', 'continue', 'arrive']);
    });

    test('OpenRouteService riceve le tappe e non chiede alternative', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(straight), 200);
      });
      final service = RoutingService(client: client, orsApiKey: 'test-key');
      const stop = LatLng(45.5402, 10.2230);
      await service.getRoutes(start, end, [], via: [stop]);
      expect(bodies.single['coordinates'], [
        [start.longitude, start.latitude],
        [stop.longitude, stop.latitude],
        [end.longitude, end.latitude],
      ]);
      expect(bodies.single['alternative_routes'], isNull);
    });
  });
}

/// Risposta OSRM minima con un percorso dritto.
final osrmResponse = {
  'code': 'Ok',
  'routes': [
    {
      'distance': 470,
      'duration': 340,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [10.2200, 45.5400],
          [10.2260, 45.5400],
        ],
      },
      'legs': [
        {
          'steps': [
            {
              'distance': 470,
              'duration': 340,
              'name': 'Via Branze',
              'maneuver': {
                'type': 'depart',
                'modifier': '',
                'location': [10.2200, 45.5400],
              },
            },
          ],
        },
      ],
    },
  ],
};
