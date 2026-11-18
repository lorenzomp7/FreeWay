import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/place_accessibility.dart';
import 'package:freeway/services/place_accessibility_service.dart';
import 'package:freeway/widgets/place_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const place = LatLng(45.5398, 10.2195);

/// Risposta Overpass per un negozio (nodo 42) dentro un edificio.
final overpass = {
  'elements': [
    {
      'type': 'node',
      'id': 42,
      'lat': 45.5398,
      'lon': 10.2195,
      'tags': {
        'name': 'Farmacia',
        'wheelchair': 'limited',
        'toilets:wheelchair': 'yes',
        'wheelchair:description:it': 'Rampa sul lato di via Mazzini',
      },
    },
    {
      'type': 'node',
      'id': 7,
      'lat': 45.5399,
      'lon': 10.2196,
      'tags': {'entrance': 'main', 'wheelchair': 'no'},
    },
    {
      'type': 'node',
      'id': 8,
      'lat': 45.5397,
      'lon': 10.2194,
      'tags': {'entrance': 'yes', 'wheelchair': 'yes', 'ref': 'B'},
    },
    // Lo stesso ingresso arriva due volte (edificio e "around").
    {
      'type': 'node',
      'id': 8,
      'lat': 45.5397,
      'lon': 10.2194,
      'tags': {'entrance': 'yes', 'wheelchair': 'yes', 'ref': 'B'},
    },
    {
      'type': 'way',
      'id': 99,
      'center': {'lat': 45.5405, 'lon': 10.2195},
      'tags': {'amenity': 'parking', 'capacity:disabled': '2'},
    },
    {
      'type': 'way',
      'id': 100,
      'center': {'lat': 45.5400, 'lon': 10.2195},
      'tags': {'amenity': 'parking', 'capacity:disabled': '0'},
    },
  ],
};

void main() {
  test('legge accessibilità, ingressi senza doppioni e parcheggio', () {
    final info = PlaceAccessibilityService.parse(overpass, 'N', 42, place);
    expect(info.wheelchair, 'limited');
    expect(info.toilets, 'yes');
    expect(info.description, 'Rampa sul lato di via Mazzini');
    expect(info.entrances, hasLength(2));
    // L'ingresso principale ha gradini: il percorso va a quello accessibile.
    expect(info.bestEntrance?.name, 'B');
    expect(info.disabledParkingMeters, closeTo(78, 2));
  });

  test("senza ingressi accessibili si usa il principale se non e' vietato", () {
    PlaceAccessibility with_(List<PlaceEntrance> e) =>
        PlaceAccessibility(entrances: e);
    const main = PlaceEntrance(position: place, type: 'main');
    const service = PlaceEntrance(position: place, type: 'service');
    const steps = PlaceEntrance(
      position: place,
      type: 'main',
      wheelchair: 'no',
    );
    expect(with_([service, main]).bestEntrance, main);
    expect(with_([service]).bestEntrance, isNull);
    expect(with_([steps]).bestEntrance, isNull);
    expect(with_([steps]).allEntrancesInaccessible, isTrue);
  });

  test('la query dipende dal tipo di elemento', () {
    expect(PlaceAccessibilityService.buildQuery('N', 1), contains('node(1)'));
    expect(PlaceAccessibilityService.buildQuery('N', 1), contains('is_in'));
    expect(
      PlaceAccessibilityService.buildQuery('W', 2),
      contains('node(w.p)["entrance"]'),
    );
    expect(
      PlaceAccessibilityService.buildQuery('R', 3),
      contains('relation(3)'),
    );
    expect(PlaceAccessibilityService.buildQuery('X', 4), isNull);
  });

  test('chiede a Overpass una volta sola e salta città e vie', () async {
    var calls = 0;
    final service = PlaceAccessibilityService(
      client: MockClient((request) async {
        calls++;
        expect(request.url.host, 'overpass-api.de');
        expect(request.bodyFields['data'], contains('node(42)'));
        return http.Response(jsonEncode(overpass), 200);
      }),
    );
    final shop = {'osm_type': 'N', 'osm_id': 42, 'kind': 'health'};
    expect((await service.load(shop, place))?.toilets, 'yes');
    await service.load(shop, place);
    expect(calls, 1);

    expect(
      await service.load({'osm_type': 'R', 'osm_id': 5, 'kind': 'city'}, place),
      isNull,
    );
    expect(await service.load({'name': 'Punto sulla mappa'}, place), isNull);
    expect(calls, 1);
  });

  test('se Overpass non risponde la scheda resta senza dati', () async {
    final service = PlaceAccessibilityService(
      client: MockClient((_) async => http.Response('busy', 429)),
    );
    expect(
      await service.load({'osm_type': 'W', 'osm_id': 1, 'kind': 'poi'}, place),
      isNull,
    );
  });

  testWidgets('la scheda mostra le voci di accessibilità', (tester) async {
    final info = PlaceAccessibilityService.parse(overpass, 'N', 42, place);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AccessibilityFacts(info: info)),
      ),
    );
    expect(
      find.text('Parzialmente accessibile in sedia a rotelle'),
      findsOneWidget,
    );
    expect(
      find.text('Ingresso accessibile (B): il percorso arriva lì'),
      findsOneWidget,
    );
    expect(find.text('Bagno accessibile'), findsOneWidget);
    expect(find.text('Parcheggio per disabili a 80 m'), findsOneWidget);
    expect(find.text('«Rampa sul lato di via Mazzini»'), findsOneWidget);
    expect(AccessibilityFacts.rowCount(info), 5);
  });

  testWidgets('toccando un ingresso lo si sceglie come arrivo', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: EntranceMarker(
                entrance: const PlaceEntrance(
                  position: place,
                  wheelchair: 'yes',
                ),
                isDestination: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Ingresso accessibile'));
    expect(tapped, isTrue);
  });
}
