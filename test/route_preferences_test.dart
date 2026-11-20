import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/models/route_preferences.dart';
import 'package:freeway/models/travel_mode.dart';
import 'package:freeway/services/routing_service.dart';
import 'package:freeway/widgets/route_details_sheets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const start = LatLng(45.5400, 10.2200);
const end = LatLng(45.5400, 10.2260);

Map<String, dynamic> orsResponse(double distance) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [10.2200, 45.5400],
          [10.2260, 45.5400],
        ],
      },
      'properties': {
        'summary': {'distance': distance, 'duration': 600},
        'segments': [
          {
            'distance': distance,
            'duration': 600,
            'steps': [
              {
                'distance': distance,
                'duration': 600,
                'type': 11,
                'instruction': 'Head east',
                'name': 'Via Branze',
                'way_points': [0, 1],
              },
              {
                'distance': 0,
                'duration': 0,
                'type': 10,
                'instruction': 'Arrive',
                'name': '-',
                'way_points': [1, 1],
              },
            ],
          },
        ],
      },
    },
  ],
};

const strict = RoutePreferences(
  maxIncline: MaxIncline.three,
  maxKerb: MaxKerb.three,
  avoidRoughSurfaces: true,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('i limiti scelti arrivano al profilo carrozzina', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = RoutingService(
      orsApiKey: 'test-key',
      client: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(orsResponse(500)), 200);
      }),
    );
    final routes = await service.getRoutes(start, end, [], preferences: strict);

    final restrictions =
        bodies.single['options']['profile_params']['restrictions'] as Map;
    expect(restrictions['maximum_incline'], 3);
    expect(restrictions['maximum_sloped_kerb'], 0.03);
    expect(restrictions['smoothness_type'], 'good');
    expect(routes.single.ignoresPreferences, isFalse);
  });

  test('con le opzioni predefinite non si mandano limiti', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = RoutingService(
      orsApiKey: 'test-key',
      client: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(jsonEncode(orsResponse(500)), 200);
      }),
    );
    await service.getRoutes(start, end, []);
    expect(bodies.single.containsKey('options'), isFalse);
  });

  test(
    'se nessun percorso rispetta i limiti si ripiega e lo si dice',
    () async {
      final service = RoutingService(
        orsApiKey: 'test-key',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          // OpenRouteService risponde 404 "Route could not be found".
          if (body['options']?['profile_params'] != null) {
            return http.Response('{"error":{"code":2009}}', 404);
          }
          return http.Response(jsonEncode(orsResponse(500)), 200);
        }),
      );
      final routes = await service.getRoutes(
        start,
        end,
        [],
        preferences: strict,
      );
      expect(routes.single.ignoresPreferences, isTrue);
    },
  );

  test('la velocità personale corregge i tempi, non le distanze', () async {
    final service = RoutingService(
      orsApiKey: 'test-key',
      client: MockClient(
        (_) async => http.Response(jsonEncode(orsResponse(500)), 200),
      ),
    );
    final slow = await service.getRoutes(
      start,
      end,
      [],
      mode: TravelMode.walking,
      preferences: const RoutePreferences(pace: TravelPace.slow),
    );
    expect(slow.single.distance, 500);
    expect(slow.single.duration, 800);
    expect(slow.single.steps.first.duration, 800);
    expect(slow.single.withPace(0.5).duration, 1600);
  });

  test('le opzioni restano sul dispositivo', () async {
    await strict.copyWith(pace: TravelPace.fast).save();
    final loaded = await RoutePreferences.load();
    expect(loaded.maxIncline, MaxIncline.three);
    expect(loaded.maxKerb, MaxKerb.three);
    expect(loaded.avoidRoughSurfaces, isTrue);
    expect(loaded.pace, TravelPace.fast);
    expect(loaded.sameRestrictions(strict), isTrue);
    expect(RoutePreferences.defaults.hasDefaultRestrictions, isTrue);
  });

  testWidgets('il pannello delle opzioni restituisce le scelte', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    RoutePreferences? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showRoutePreferencesSheet(
              context,
              RoutePreferences.defaults,
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3%'));
    await tester.tap(find.text('Evita ciottoli, ghiaia e sterrato'));
    await tester.tap(find.text('Lenta'));
    await tester.pump();
    await tester.tap(find.text('Applica'));
    await tester.pumpAndSettle();
    expect(chosen?.maxIncline, MaxIncline.three);
    expect(chosen?.avoidRoughSurfaces, isTrue);
    expect(chosen?.pace, TravelPace.slow);
    expect(chosen?.maxKerb, MaxKerb.six);
  });

  testWidgets('l\'elenco delle indicazioni legge ogni passo', (tester) async {
    final route = RouteOption(
      points: const [start, end],
      distance: 500,
      duration: 600,
      index: 0,
      steps: [
        RouteStep(
          instruction: 'depart||Via Mazzini',
          location: start,
          maneuverType: 'depart',
          modifier: '',
          distance: 200,
        ),
        RouteStep(
          instruction: 'turn|left|Via Musei',
          location: start,
          maneuverType: 'turn',
          modifier: 'left',
          distance: 300,
        ),
        RouteStep(
          instruction: 'arrive||',
          location: end,
          maneuverType: 'arrive',
          modifier: '',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RouteStepsList(route: route)),
      ),
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Passo 1 di 3: .*Via Mazzini, poi per 200 m$'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'^Passo 2 di 3: .*Via Musei')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'^Passo 3 di 3: ')), findsOneWidget);
  });
}
