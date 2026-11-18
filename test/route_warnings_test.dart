import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/route_warnings.dart';
import 'package:freeway/services/routing_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

/// Punti in fila verso est, a circa 10 m l'uno dall'altro.
final points = [
  for (var i = 0; i <= 20; i++) LatLng(45.54, 10.22 + i * 0.000128),
];

Map<String, dynamic> extra(List<List<int>> values) => {'values': values};

void main() {
  test('trova gradini, salite ripide e fondo sconnesso con i metri', () {
    final warnings = parseRouteWarnings({
      'waytype': extra([
        [0, 2, 3],
        [2, 3, 8], // gradini, circa 10 m
        [3, 20, 7],
      ]),
      'steepness': extra([
        [0, 5, 0],
        [5, 13, 4], // salita del 10-15%, circa 80 m
        [13, 15, -2], // 20 m al 4-6%: sotto la soglia
        [15, 20, 0],
      ]),
      'surface': extra([
        [0, 10, 3],
        [10, 12, 10], // ghiaia
        [12, 14, 5], // ciottoli
        [14, 20, 3],
      ]),
    }, points);

    expect(warnings.map((w) => w.kind), [
      RouteWarningKind.steps,
      RouteWarningKind.steepUp,
      RouteWarningKind.roughSurface,
    ]);
    expect(warnings[0].meters, closeTo(10, 0.5));
    expect(warnings[1].meters, closeTo(80, 1));
    expect(warnings[1].label, 'Salita ripida (oltre il 7%) per 80 m');
    expect(warnings[2].label, 'Fondo sconnesso (ghiaia, ciottoli) per 40 m');
    expect(warnings.where((w) => w.isHard), hasLength(2));
  });

  test('dati mancanti o malformati non producono avvisi', () {
    expect(parseRouteWarnings({}, points), isEmpty);
    expect(
      parseRouteWarnings({
        'steepness': {'values': 'boh'},
        'surface': extra([
          [0, 99, 3],
        ]),
      }, points),
      isEmpty,
    );
  });

  test('il punteggio scende con le difficoltà gravi', () {
    final route = RouteOption(
      points: points,
      distance: 200,
      duration: 160,
      steps: const [],
      index: 0,
    )..warnings = const [RouteWarning(RouteWarningKind.steps, 10)];
    expect(route.accessibilityScore, 85);
    route.warnings = const [RouteWarning(RouteWarningKind.roughSurface, 30)];
    expect(route.accessibilityScore, 100);
  });

  test('OpenRouteService riceve extra_info e i percorsi con gradini scendono '
      'in classifica', () async {
    Map<String, dynamic> feature(double distance, {bool steps = false}) => {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [10.2200, 45.5400],
          [10.2230, 45.5400],
          [10.2260, 45.5400],
        ],
      },
      'properties': {
        'summary': {'distance': distance, 'duration': distance},
        'segments': [],
        'extras': {
          'waytype': extra([
            [0, 2, steps ? 8 : 7],
          ]),
          'steepness': extra([
            [0, 2, 0],
          ]),
          'surface': extra([
            [0, 2, 3],
          ]),
        },
      },
    };
    Map<String, dynamic>? body;
    final client = MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'type': 'FeatureCollection',
          'features': [feature(400, steps: true), feature(520)],
        }),
        200,
      );
    });
    final routes = await RoutingService(
      client: client,
      orsApiKey: 'k',
    ).getRoutes(const LatLng(45.54, 10.22), const LatLng(45.54, 10.226), []);

    expect(body?['extra_info'], kOrsExtraInfo);
    expect(routes.first.distance, 520);
    expect(routes.first.hasTerrainData, isTrue);
    expect(routes.first.warnings, isEmpty);
    expect(routes.last.warnings.single.kind, RouteWarningKind.steps);
  });
}
