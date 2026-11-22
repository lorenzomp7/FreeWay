import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/models/transit.dart';
import 'package:freeway/services/instruction_translator.dart';
import 'package:freeway/services/routing_service.dart';
import 'package:freeway/services/transit_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

// Dati di prova inventati: nessuna linea o fermata reale è necessaria.
const home = LatLng(45.5389, 10.2200);
const stopA = LatLng(45.5400, 10.2210);
const stopB = LatLng(45.5600, 10.2500);
const office = LatLng(45.5610, 10.2515);

/// Codifica Google Polyline, per costruire le risposte di prova.
String encode(List<LatLng> points, int precision) {
  final factor = 1.0 * _pow10(precision);
  final out = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  void write(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  for (final p in points) {
    final lat = (p.latitude * factor).round();
    final lng = (p.longitude * factor).round();
    write(lat - lastLat);
    write(lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return out.toString();
}

int _pow10(int n) => n == 0 ? 1 : 10 * _pow10(n - 1);

Map<String, dynamic> geometry(List<LatLng> points, [int precision = 6]) => {
  'points': encode(points, precision),
  'precision': precision,
  'length': points.length,
};

Map<String, dynamic> place(String name, LatLng p) => {
  'name': name,
  'lat': p.latitude,
  'lon': p.longitude,
};

Map<String, dynamic> walk(
  LatLng from,
  LatLng to,
  String start,
  String end, {
  List<Map<String, dynamic>> steps = const [],
  String fromName = 'START',
  String toName = 'END',
}) => {
  'mode': 'WALK',
  'from': place(fromName, from),
  'to': place(toName, to),
  'startTime': start,
  'endTime': end,
  'distance': 150,
  'legGeometry': geometry([from, to]),
  'steps': steps,
};

Map<String, dynamic> ride({
  String mode = 'BUS',
  String line = '10',
  String? access = 'ACCESSIBLE',
  String start = '2026-11-23T08:05:00Z',
  String end = '2026-11-23T08:20:00Z',
  int precision = 6,
}) => {
  'mode': mode,
  'from': place('Fermata A', stopA),
  'to': place('Fermata B', stopB),
  'startTime': start,
  'endTime': end,
  'routeShortName': line,
  'headsign': 'Centro',
  'agencyName': 'Azienda di prova',
  'intermediateStops': [{}, {}, {}],
  'legGeometry': geometry([
    stopA,
    const LatLng(45.55, 10.235),
    stopB,
  ], precision),
  'wheelchairAccessible': ?access,
};

Map<String, dynamic> itinerary({
  String? access = 'ACCESSIBLE',
  String mode = 'BUS',
  String line = '10',
  String arrival = '2026-11-23T08:25:00Z',
  int precision = 6,
}) => {
  'duration': 1500,
  'startTime': '2026-11-23T08:00:00Z',
  'endTime': arrival,
  'transfers': 0,
  'id': 'x',
  'legs': [
    walk(
      home,
      stopA,
      '2026-11-23T08:00:00Z',
      '2026-11-23T08:05:00Z',
      steps: [
        {
          'relativeDirection': 'DEPART',
          'distance': 100,
          'streetName': 'Via Prova',
          'polyline': geometry([home, stopA]),
        },
        {
          'relativeDirection': 'LEFT',
          'distance': 50,
          'streetName': 'Via Seconda',
          'polyline': geometry([stopA, stopA]),
        },
      ],
      toName: 'Fermata A',
    ),
    ride(mode: mode, line: line, access: access, precision: precision),
    walk(
      stopB,
      office,
      '2026-11-23T08:20:00Z',
      arrival,
      fromName: 'Fermata B',
      toName: 'Ufficio',
    ),
  ],
};

void main() {
  test('chiede a Transitous il profilo sedia a rotelle, in italiano', () {
    final uri = TransitService.requestUri(home, office);
    expect(uri.host, 'api.transitous.org');
    expect(uri.path, '/api/v5/plan');
    expect(uri.queryParameters['fromPlace'], '45.538900,10.220000');
    expect(uri.queryParameters['toPlace'], '45.561000,10.251500');
    expect(uri.queryParameters['pedestrianProfile'], 'WHEELCHAIR');
    expect(uri.queryParameters['language'], 'it');
    expect(uri.host, isNot(contains('staging')));
  });

  test('legge tratti, orari, linee e accessibilità', () {
    final routes = TransitService.parse({
      'itineraries': [itinerary()],
    });
    expect(routes, hasLength(1));
    final route = routes.single;
    expect(route.usesTransit, isTrue);
    expect(route.provider, 'transitous');
    expect(route.transitLegs.map((l) => l.vehicle), [
      TransitVehicle.walk,
      TransitVehicle.bus,
      TransitVehicle.walk,
    ]);
    final bus = route.transitLegs[1];
    expect(bus.title, 'Bus 10');
    expect(bus.headsign, 'Centro');
    expect(bus.stops, 3);
    expect(bus.access, TransitAccess.accessible);
    expect(bus.points.first.latitude, closeTo(stopA.latitude, 1e-6));
    expect(route.departureTime, DateTime.utc(2026, 11, 23, 8).toLocal());
    expect(route.arrivalTime, DateTime.utc(2026, 11, 23, 8, 25).toLocal());
    expect(route.duration, 1500);
    expect(route.isRecommended, isTrue);
    expect(route.label, 'Consigliato');
  });

  test('decodifica le geometrie con la precisione indicata (6 o 7)', () {
    for (final precision in [6, 7]) {
      final route = TransitService.parse({
        'itineraries': [itinerary(precision: precision)],
      }).single;
      final bus = route.transitLegs[1];
      expect(bus.points, hasLength(3));
      expect(bus.points.last.longitude, closeTo(stopB.longitude, 1e-6));
    }
  });

  test('crea le indicazioni: a piedi, sali, scendi, arrivo', () {
    final route = TransitService.parse({
      'itineraries': [itinerary()],
    }).single;
    final types = route.steps.map((s) => s.maneuverType).toList();
    expect(types, ['depart', 'turn', 'board', 'alight', 'continue', 'arrive']);
    const it = InstructionTranslator('it');
    final texts = route.steps.map((s) => it.translate(s.instruction)).toList();
    expect(texts[0], 'Parti da Via Prova');
    expect(texts[1], 'Svolta a sinistra su Via Seconda');
    expect(texts[2], 'Sali sul bus 10 direzione Centro alla fermata Fermata A');
    expect(texts[3], 'Scendi a Fermata B');
    expect(texts.last, contains('Ufficio'));
    const en = InstructionTranslator('en');
    expect(
      en.translate(route.steps[2].instruction),
      'Board the bus 10 towards Centro at Fermata A',
    );
    expect(maneuverEmoji('board', 'bus'), '🚌');
  });

  test('la metro è femminile: "sulla metro"', () {
    const it = InstructionTranslator('it');
    expect(
      it.translate('board|metro|M1\tPrealpino\tStazione'),
      'Sali sulla metro M1 direzione Prealpino alla fermata Stazione',
    );
    expect(it.translate('elevator||'), 'Prendi l\'ascensore');
  });

  test(
    'prima i viaggi accessibili, in fondo quelli con un mezzo che non lo è',
    () {
      final routes = TransitService.parse({
        'itineraries': [
          itinerary(access: 'NOT_ACCESSIBLE', arrival: '2026-11-23T08:22:00Z'),
          itinerary(access: null, arrival: '2026-11-23T08:24:00Z'),
          itinerary(access: 'ACCESSIBLE', arrival: '2026-11-23T08:30:00Z'),
        ],
      });
      expect(routes.map((r) => overallAccess(r.transitLegs)), [
        TransitAccess.accessible,
        TransitAccess.unknown,
        TransitAccess.notAccessible,
      ]);
      expect(routes.map((r) => r.index), [0, 1, 2]);
      expect(routes.first.isRecommended, isTrue);
      expect(routes.last.isRecommended, isFalse);
    },
  );

  test('con soli mezzi non accessibili niente "Consigliato"', () {
    final routes = TransitService.parse({
      'itineraries': [itinerary(access: 'NOT_ACCESSIBLE')],
    });
    expect(routes.single.isRecommended, isFalse);
  });

  test('conta gli ostacoli segnalati sui tratti a piedi', () {
    final obstacle = Obstacle(id: 'o', position: home, type: 'Gradino');
    final route = TransitService.parse(
      {
        'itineraries': [itinerary()],
      },
      obstacles: [obstacle],
    ).single;
    expect(route.obstacleCount, 1);
  });

  test('modalità di MOTIS', () {
    expect(TransitVehicle.fromMode('SUBWAY'), TransitVehicle.metro);
    expect(TransitVehicle.fromMode('REGIONAL_RAIL'), TransitVehicle.train);
    expect(TransitVehicle.fromMode('TRAM'), TransitVehicle.tram);
    expect(TransitVehicle.fromMode('???'), TransitVehicle.other);
  });

  test('risposte vuote o strane non rompono nulla', () {
    expect(TransitService.parse(null), isEmpty);
    expect(TransitService.parse({'itineraries': []}), isEmpty);
    expect(
      TransitService.parse({
        'itineraries': [
          {'legs': []},
        ],
      }),
      isEmpty,
    );
  });

  group('richieste', () {
    test('una seconda ricerca uguale usa la cache', () async {
      var calls = 0;
      final service = TransitService(
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'itineraries': [itinerary()],
            }),
            200,
          );
        }),
      );
      final first = await service.plan(home, office);
      final second = await service.plan(home, office);
      expect(calls, 1);
      expect(identical(first, second), isTrue);
    });

    test('troppe richieste: un messaggio chiaro', () async {
      for (final code in [429, 403]) {
        final service = TransitService(
          client: MockClient((_) async => http.Response('no', code)),
        );
        await expectLater(
          service.plan(home, office),
          throwsA(
            isA<TransitException>().having(
              (e) => e.message,
              'message',
              contains('Troppe richieste'),
            ),
          ),
        );
      }
    });

    test('server che non risponde', () async {
      final service = TransitService(
        client: MockClient((_) async => http.Response('boom', 500)),
      );
      await expectLater(
        service.plan(home, office),
        throwsA(isA<TransitException>()),
      );
    });
  });

  test('RouteOption.withPace non cambia gli orari dei mezzi', () {
    final route = TransitService.parse({
      'itineraries': [itinerary()],
    }).single;
    final slow = route.withPace(0.75);
    expect(slow.transitLegs, same(route.transitLegs));
    expect(slow.arrivalTime, route.arrivalTime);
  });

  test('il decodificatore delle polilinee è condiviso', () {
    expect(
      RoutingService.decodePolyline(encode([home, office], 6), 6).last.latitude,
      closeTo(office.latitude, 1e-6),
    );
    expect(RouteOption, isNotNull);
  });
}
