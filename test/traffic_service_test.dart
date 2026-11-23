import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/traffic_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

TrafficSample sample({
  int frc = 2,
  double current = 50,
  double free = 50,
  double confidence = 0.9,
  bool closed = false,
  double distance = 5,
}) => TrafficSample(
  position: const LatLng(45.54, 10.22),
  roadClass: frc,
  currentSpeed: current,
  freeFlowSpeed: free,
  confidence: confidence,
  roadClosure: closed,
  distance: distance,
);

/// Percorso dritto di circa 1 km verso nord, con una manovra ogni 200 m.
RouteOption route({
  double duration = 600,
  int obstacles = 0,
  List<RouteWarning> warnings = const [],
  String label = '',
}) {
  final points = [
    for (var i = 0; i <= 10; i++) LatLng(45.5300 + i * 0.0009, 10.2200),
  ];
  return RouteOption(
      points: points,
      distance: 1000,
      duration: duration,
      steps: [
        for (var i = 0; i <= 10; i += 2)
          RouteStep(
            instruction: 'turn|left|',
            location: points[i],
            maneuverType: 'turn',
            modifier: 'left',
          ),
      ],
      index: 0,
    )
    ..obstacleCount = obstacles
    ..warnings = warnings
    ..label = label;
}

void main() {
  group('trafficLevelOf', () {
    test('strada principale veloce: trafficata', () {
      expect(trafficLevelOf(sample(frc: 2, free: 60)), TrafficLevel.busy);
    });

    test('strada principale con coda: traffico intenso', () {
      expect(
        trafficLevelOf(sample(frc: 3, current: 15, free: 40)),
        TrafficLevel.heavy,
      );
    });

    test('strade locali, chiuse, lontane o dati incerti non contano', () {
      expect(trafficLevelOf(sample(frc: 5, current: 5)), TrafficLevel.none);
      expect(trafficLevelOf(sample(closed: true)), TrafficLevel.none);
      expect(trafficLevelOf(sample(distance: 80)), TrafficLevel.none);
      expect(trafficLevelOf(sample(confidence: 0.2)), TrafficLevel.none);
      // Strada principale lenta ma scorrevole (zona 30).
      expect(trafficLevelOf(sample(free: 30, current: 30)), TrafficLevel.none);
    });
  });

  test('i punti da controllare sono le manovre, senza partenza e arrivo', () {
    final r = route();
    final points = trafficSamplePoints(r);
    expect(points, isNotEmpty);
    expect(points.length, lessThanOrEqualTo(6));
    expect(points, isNot(contains(r.points.first)));
    expect(points, isNot(contains(r.points.last)));
  });

  test('l\'avviso conta i punti trafficati e quelli con coda', () {
    expect(busyRoadWarning([sample(frc: 6), null]), isNull);
    final warning = busyRoadWarning([
      sample(free: 60),
      sample(current: 10, free: 50),
      sample(frc: 6),
    ])!;
    expect(warning.kind, RouteWarningKind.busyRoad);
    expect(warning.count, 2);
    expect(warning.isHard, isFalse);
    expect(warning.label, 'Strade trafficate in 2 punti, adesso (1 con coda)');
  });

  group('rankByTraffic', () {
    RouteWarning busy(int n) =>
        RouteWarning(RouteWarningKind.busyRoad, 0, count: n);

    test('preferisce il percorso tranquillo se è poco più lungo', () {
      final fast = route(duration: 600, warnings: [busy(3)])
        ..isRecommended = true;
      final calm = route(duration: 660, warnings: [busy(0)]);
      final routes = [fast, calm];
      expect(rankByTraffic(routes, walking: true), isTrue);
      expect(routes.first, same(calm));
      expect(calm.isRecommended, isTrue);
      expect(calm.label, 'Meno traffico');
      expect(fast.isRecommended, isFalse);
    });

    test('non allunga troppo il tragitto', () {
      final routes = [
        route(duration: 600, warnings: [busy(3)]),
        route(duration: 800),
      ];
      expect(rankByTraffic(routes, walking: true), isFalse);
    });

    test('in sedia a rotelle non sceglie un percorso con più ostacoli', () {
      final routes = [
        route(duration: 600, warnings: [busy(2)]),
        route(duration: 620, obstacles: 1),
      ];
      expect(rankByTraffic(routes, walking: false), isFalse);
    });
  });

  group('TrafficService', () {
    test('senza indirizzo del Worker il traffico è spento', () async {
      final service = TrafficService(baseUrl: '');
      expect(service.isEnabled, isFalse);
      final routes = [route()];
      expect(await service.annotate(routes, walking: true), isFalse);
      expect(routes.first.warnings, isEmpty);
    });

    test('chiede i punti al Worker e aggiunge l\'avviso', () async {
      Uri? asked;
      final service = TrafficService(
        baseUrl: 'https://traffico.example.workers.dev/flow',
        client: MockClient((request) async {
          asked = request.url;
          final count = request.url.queryParameters['points']!
              .split('|')
              .length;
          return http.Response(
            jsonEncode({
              'points': [
                for (var i = 0; i < count; i++)
                  {
                    'lat': 45.54,
                    'lon': 10.22,
                    'frc': 1,
                    'currentSpeed': 20,
                    'freeFlowSpeed': 60,
                    'confidence': 1,
                    'roadClosure': false,
                    'distance': 4,
                  },
              ],
            }),
            200,
          );
        }),
      );
      final routes = [route()];
      await service.annotate(routes, walking: true);
      expect(asked!.host, 'traffico.example.workers.dev');
      expect(routes.first.busyRoadCount, greaterThan(0));
    });

    test('se il Worker non risponde i percorsi restano come sono', () async {
      final service = TrafficService(
        baseUrl: 'https://traffico.example.workers.dev/flow',
        client: MockClient((_) async => http.Response('errore', 500)),
      );
      final routes = [route(), route(duration: 700)];
      expect(await service.annotate(routes, walking: true), isFalse);
      expect(routes.every((r) => r.warnings.isEmpty), isTrue);
    });
  });
}
