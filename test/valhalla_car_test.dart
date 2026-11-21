import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/disabled_parking.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/models/travel_mode.dart';
import 'package:freeway/services/disabled_parking_service.dart';
import 'package:freeway/services/instruction_translator.dart';
import 'package:freeway/services/routing_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const start = LatLng(45.5400, 10.2200);
const end = LatLng(45.5400, 10.2260);

/// Codifica una polilinea come Valhalla (precisione 6).
String encodePolyline(List<LatLng> points, {int precision = 6}) {
  final factor = _pow10(precision);
  final buffer = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  void write(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    buffer.writeCharCode(v + 63);
  }

  for (final p in points) {
    final lat = (p.latitude * factor).round();
    final lng = (p.longitude * factor).round();
    write(lat - lastLat);
    write(lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return buffer.toString();
}

double _pow10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// Risposta `/route` di Valhalla con un tratto e tre manovre.
Map<String, dynamic> valhallaTrip(List<LatLng> points, {double km = 0.47}) => {
  'legs': [
    {
      'shape': encodePolyline(points),
      'summary': {'length': km, 'time': 420.0},
      'maneuvers': [
        {
          'type': 1,
          'instruction': 'Cammina verso est su Via Branze.',
          'street_names': ['Via Branze'],
          'length': km / 2,
          'time': 210.0,
          'begin_shape_index': 0,
          'end_shape_index': 1,
        },
        {
          'type': 15,
          'instruction': 'Svolta a sinistra su Via Valotti.',
          'street_names': ['Via Valotti'],
          'length': km / 2,
          'time': 210.0,
          'begin_shape_index': 1,
          'end_shape_index': points.length - 1,
        },
        {
          'type': 4,
          'instruction': 'Sei arrivato a destinazione.',
          'length': 0.0,
          'time': 0.0,
          'begin_shape_index': points.length - 1,
          'end_shape_index': points.length - 1,
        },
      ],
    },
  ],
  'summary': {'length': km, 'time': 420.0},
  'status': 0,
  'status_message': 'Found route between points',
  'units': 'kilometers',
  'language': 'it-IT',
};

/// Risposta OSRM minima.
Map<String, dynamic> osrm(List<LatLng> points, double meters) => {
  'code': 'Ok',
  'routes': [
    {
      'distance': meters,
      'duration': meters / 10,
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          for (final p in points) [p.longitude, p.latitude],
        ],
      },
      'legs': [
        {
          'steps': [
            {
              'distance': meters,
              'duration': meters / 10,
              'name': 'Via Milano',
              'maneuver': {
                'type': 'depart',
                'location': [points.first.longitude, points.first.latitude],
              },
            },
            {
              'distance': 0,
              'duration': 0,
              'name': 'Via Milano',
              'maneuver': {
                'type': 'arrive',
                'location': [points.last.longitude, points.last.latitude],
              },
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  group('polilinea', () {
    test('decodifica la precisione 6 di Valhalla', () {
      const points = [
        LatLng(45.540012, 10.220034),
        LatLng(45.541, 10.2231),
        LatLng(45.5399, 10.2260),
      ];
      final decoded = RoutingService.decodePolyline(encodePolyline(points), 6);
      expect(decoded, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(decoded[i].latitude, closeTo(points[i].latitude, 1e-6));
        expect(decoded[i].longitude, closeTo(points[i].longitude, 1e-6));
      }
    });

    test('una polilinea rovinata dà una lista vuota', () {
      expect(RoutingService.decodePolyline('_', 6), isEmpty);
    });
  });

  group('Valhalla', () {
    test('la richiesta chiede la sedia a rotelle ed evita gli ostacoli', () {
      final obstacle = Obstacle(
        id: 'o1',
        position: const LatLng(45.54, 10.223),
        type: 'Gradino',
      );
      final request = RoutingService.valhallaRequest([start, end], [obstacle]);
      expect(request['costing'], 'pedestrian');
      expect(request['costing_options'], {
        'pedestrian': {'type': 'wheelchair'},
      });
      expect(request['alternates'], 2);
      final polygons = request['exclude_polygons'] as List;
      expect(polygons, hasLength(1));
      final ring = polygons.single as List;
      // Anello chiuso di coppie [lon, lat].
      expect(ring.first, ring.last);
      final first = ring.first as List;
      expect(first[0], closeTo(10.223, 0.001));
      expect(first[1], closeTo(45.54, 0.001));
      expect((request['locations'] as List).first, {
        'lat': start.latitude,
        'lon': start.longitude,
        'type': 'break',
      });
    });

    test('con le tappe non chiede alternative', () {
      final request = RoutingService.valhallaRequest([
        start,
        const LatLng(45.5402, 10.223),
        end,
      ], const []);
      expect(request.containsKey('alternates'), isFalse);
      expect(request.containsKey('exclude_polygons'), isFalse);
    });

    test('legge percorso principale e alternative in metri', () {
      const points = [start, LatLng(45.5405, 10.223), end];
      final routes = RoutingService.parseValhallaRoutes({
        'trip': valhallaTrip(points),
        'alternates': [
          {'trip': valhallaTrip(points, km: 0.6)},
        ],
      });
      expect(routes, hasLength(2));
      final route = routes.first;
      expect(route.provider, 'valhalla');
      expect(route.distance, closeTo(470, 0.01));
      expect(route.duration, 420);
      expect(route.points, hasLength(3));
      expect(route.steps.map((s) => s.maneuverType), [
        'depart',
        'turn',
        'arrive',
      ]);
      expect(route.steps[1].modifier, 'left');
      expect(route.steps[1].streetName, 'Via Valotti');
      expect(route.steps[1].location.latitude, closeTo(45.5405, 1e-6));
      expect(route.steps[1].distance, closeTo(235, 0.01));
      expect(routes[1].distance, closeTo(600, 0.01));
    });

    test('i tratti tra le tappe si uniscono senza ripetere i punti', () {
      const a = [start, LatLng(45.5402, 10.223)];
      const b = [LatLng(45.5402, 10.223), end];
      Map<String, dynamic> leg(List<LatLng> pts) =>
          (valhallaTrip(pts)['legs'] as List).first as Map<String, dynamic>;
      final routes = RoutingService.parseValhallaRoutes({
        'trip': {
          'legs': [leg(a), leg(b)],
          'summary': {'length': 1.0, 'time': 800},
          'status': 0,
        },
      });
      final route = routes.single;
      expect(route.points, hasLength(3));
      expect(route.steps.map((s) => s.maneuverType), contains('stop'));
      expect(route.steps.last.location.longitude, closeTo(end.longitude, 1e-6));
    });

    test('senza chiave OpenRouteService usa Valhalla prima di OSRM', () async {
      final hosts = <String>[];
      final client = MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'valhalla1.openstreetmap.de') {
          // GET semplice con il parametro json, niente preflight CORS.
          expect(request.method, 'GET');
          final json = jsonDecode(request.url.queryParameters['json']!);
          expect(json['costing_options']['pedestrian']['type'], 'wheelchair');
          return http.Response(
            jsonEncode({
              'trip': valhallaTrip(const [start, LatLng(45.5405, 10.223), end]),
            }),
            200,
          );
        }
        fail('Non doveva chiamare ${request.url.host}');
      });
      final service = RoutingService(client: client, orsApiKey: '');
      final routes = await service.getRoutes(start, end, const []);
      expect(hosts, ['valhalla1.openstreetmap.de']);
      expect(routes.single.provider, 'valhalla');
      expect(routes.single.label, 'Consigliato');
    });

    test('manovre di Valhalla in tipi OSRM', () {
      expect(RoutingService.valhallaManeuver(1), ('depart', ''));
      expect(RoutingService.valhallaManeuver(10), ('turn', 'right'));
      expect(RoutingService.valhallaManeuver(16), ('turn', 'slight left'));
      expect(RoutingService.valhallaManeuver(26), ('roundabout', ''));
      expect(RoutingService.valhallaManeuver(6), ('arrive', ''));
      expect(RoutingService.valhallaManeuver(8), ('continue', 'straight'));
      expect(RoutingService.valhallaManeuver(null), ('continue', 'straight'));
    });
  });

  group('in auto fino al parcheggio per disabili', () {
    const parkingPoint = LatLng(45.5402, 10.2255);
    const parking = DisabledParking(
      id: 'node/1',
      position: parkingPoint,
      name: 'Parcheggio Ospedale',
      spaces: 2,
      isSingleSpace: false,
    );

    test('guida fino al parcheggio e poi va in sedia a rotelle', () async {
      final hosts = <String>[];
      final client = MockClient((request) async {
        hosts.add(request.url.host);
        if (request.url.host == 'router.project-osrm.org') {
          expect(request.url.path, contains('/route/v1/driving/'));
          return http.Response(
            jsonEncode(osrm(const [start, parkingPoint], 900)),
            200,
          );
        }
        if (request.url.host == 'valhalla1.openstreetmap.de') {
          return http.Response(
            jsonEncode({
              'trip': valhallaTrip(const [parkingPoint, end], km: 0.05),
            }),
            200,
          );
        }
        fail('Non doveva chiamare ${request.url.host}');
      });
      final service = RoutingService(client: client, orsApiKey: '');
      final routes = await service.getCarRoutes(
        start,
        end,
        const [],
        parkings: const [parking],
      );
      final route = routes.single;
      expect(route.usesCar, isTrue);
      expect(route.parking, parking);
      expect(route.driveEndIndex, 1);
      expect(route.walkDistance, closeTo(50, 0.01));
      expect(route.distance, closeTo(950, 0.01));
      final types = route.steps.map((s) => s.maneuverType).toList();
      expect(types.first, 'depart');
      expect(types, contains('park'));
      expect(types.last, 'arrive');
      expect(types.where((t) => t == 'arrive'), hasLength(1));
      expect(hosts.first, 'router.project-osrm.org');
    });

    test('senza parcheggi porta in auto fino alla destinazione', () async {
      final client = MockClient(
        (request) async =>
            http.Response(jsonEncode(osrm(const [start, end], 700)), 200),
      );
      final service = RoutingService(client: client, orsApiKey: '');
      final routes = await service.getCarRoutes(start, end, const []);
      expect(routes.single.usesCar, isTrue);
      expect(routes.single.parking, isNull);
    });

    test('stalli vicini contano come un solo parcheggio', () async {
      var drives = 0;
      final client = MockClient((request) async {
        if (request.url.host == 'router.project-osrm.org') drives++;
        return http.Response(
          jsonEncode(
            request.url.host == 'valhalla1.openstreetmap.de'
                ? {
                    'trip': valhallaTrip(const [parkingPoint, end], km: 0.05),
                  }
                : osrm(const [start, parkingPoint], 900),
          ),
          200,
        );
      });
      final service = RoutingService(client: client, orsApiKey: '');
      await service.getCarRoutes(
        start,
        end,
        const [],
        parkings: const [
          parking,
          DisabledParking(id: 'node/2', position: LatLng(45.54021, 10.22552)),
        ],
      );
      expect(drives, 1);
    });

    test('la modalità auto ha la sua etichetta', () {
      expect(TravelMode.car.label, 'In auto');
    });

    test('istruzione "Parcheggia" in italiano e in inglese', () {
      final step = RouteStep(
        instruction: 'park||Parcheggio Ospedale',
        location: parkingPoint,
        maneuverType: 'park',
        modifier: '',
      );
      expect(
        const InstructionTranslator('it').translate(step.instruction),
        startsWith('Parcheggia nel posto riservato'),
      );
      expect(
        const InstructionTranslator('en').translate(step.instruction),
        startsWith('Park in the accessible parking space'),
      );
      expect(maneuverEmoji('park', ''), '🅿️');
    });
  });

  group('parcheggi per disabili da OpenStreetMap', () {
    test('riconosce stalli e parcheggi con posti riservati', () {
      expect(
        DisabledParkingService.isDisabledParking({
          'amenity': 'parking_space',
          'parking_space': 'disabled',
        }),
        isTrue,
      );
      expect(
        DisabledParkingService.isDisabledParking({
          'amenity': 'parking',
          'capacity:disabled': '3',
        }),
        isTrue,
      );
      expect(
        DisabledParkingService.isDisabledParking({
          'amenity': 'parking',
          'capacity:disabled': '0',
        }),
        isFalse,
      );
      expect(
        DisabledParkingService.isDisabledParking({
          'amenity': 'parking',
          'capacity:disabled': 'no',
        }),
        isFalse,
      );
    });

    test('legge posizione, posti, tariffa e toglie i doppioni', () {
      final parkings = DisabledParkingService.parse({
        'elements': [
          {
            'type': 'way',
            'id': 7,
            'center': {'lat': 45.54, 'lon': 10.22},
            'tags': {
              'amenity': 'parking',
              'capacity:disabled': '4',
              'fee': 'yes',
              'name': 'Parcheggio Stazione',
            },
          },
          {
            'type': 'way',
            'id': 7,
            'center': {'lat': 45.54, 'lon': 10.22},
            'tags': {'amenity': 'parking', 'capacity:disabled': '4'},
          },
          {
            'type': 'node',
            'id': 8,
            'lat': 45.541,
            'lon': 10.221,
            'tags': {'amenity': 'parking_space', 'parking_space': 'disabled'},
          },
          {
            'type': 'node',
            'id': 9,
            'lat': 45.542,
            'lon': 10.222,
            'tags': {'amenity': 'parking'},
          },
        ],
      });
      expect(parkings, hasLength(2));
      expect(parkings.first.spaces, 4);
      expect(
        parkings.first.summary,
        'Parcheggio Stazione · 4 posti riservati · a pagamento',
      );
      expect(parkings.last.isSingleSpace, isTrue);
      expect(parkings.last.summary, 'Posto riservato');
    });

    test('la query chiede i tag giusti nell\'area', () {
      final query = DisabledParkingService.buildQuery('around:500,45.5,10.2');
      expect(
        query,
        contains('nwr(around:500,45.5,10.2)["parking_space"="disabled"]'),
      );
      expect(query, contains('["capacity:disabled"]'));
      expect(query, contains('out center'));
    });

    test('vicino alla destinazione: dal più vicino', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'overpass-api.de');
        expect(request.bodyFields['data'], contains('around:500,'));
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'node',
                'id': 1,
                'lat': 45.545,
                'lon': 10.226,
                'tags': {'parking_space': 'disabled'},
              },
              {
                'type': 'node',
                'id': 2,
                'lat': 45.5401,
                'lon': 10.2261,
                'tags': {'parking_space': 'disabled'},
              },
            ],
          }),
          200,
        );
      });
      final service = DisabledParkingService(client: client);
      final found = await service.near(end);
      expect(found!.map((p) => p.id), ['node/2', 'node/1']);
    });

    test('se Overpass non risponde il risultato è null', () async {
      final service = DisabledParkingService(
        client: MockClient((_) async => http.Response('busy', 429)),
      );
      expect(await service.near(end), isNull);
    });
  });
}
