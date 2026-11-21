import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/nearby_accessible_service.dart';
import 'package:freeway/widgets/search_panel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const center = LatLng(45.5398, 10.2195);

Map<String, dynamic> overpass(List<Map<String, dynamic>> elements) => {
  'elements': elements,
};

void main() {
  test('le richieste cercano i tag giusti attorno al centro', () {
    final wheelchair = NearbyAccessibleService.buildQuery(
      NearbyFilter.wheelchair,
      center,
    );
    expect(wheelchair, contains('around:800,45.539800,10.219500'));
    expect(
      wheelchair,
      contains('["wheelchair"~"^(yes|designated)\$"]["name"]'),
    );
    expect(
      NearbyAccessibleService.buildQuery(NearbyFilter.parking, center),
      contains('["parking_space"="disabled"]'),
    );
    expect(
      NearbyAccessibleService.buildQuery(NearbyFilter.toilets, center),
      contains('["toilets:wheelchair"~"^(yes|designated)\$"]'),
    );
  });

  test('i risultati sono luoghi della ricerca, dai più vicini', () {
    final places = NearbyAccessibleService.parse(
      NearbyFilter.wheelchair,
      overpass([
        {
          'type': 'way',
          'id': 7,
          'center': {'lat': 45.5450, 'lon': 10.2195},
          'tags': {'name': 'Museo', 'tourism': 'museum'},
        },
        {
          'type': 'node',
          'id': 3,
          'lat': 45.5400,
          'lon': 10.2196,
          'tags': {
            'name': 'Farmacia Centrale',
            'amenity': 'pharmacy',
            'addr:street': 'Via Roma',
            'addr:housenumber': '4',
            'addr:city': 'Brescia',
          },
        },
        // Stesso elemento due volte: si conta una.
        {
          'type': 'node',
          'id': 3,
          'lat': 45.5400,
          'lon': 10.2196,
          'tags': {'name': 'Farmacia Centrale'},
        },
        {'type': 'node', 'id': 9},
      ]),
      center,
    );
    expect(places.map((p) => p['name']), ['Farmacia Centrale', 'Museo']);
    final pharmacy = places.first;
    expect(pharmacy['osm_type'], 'N');
    expect(pharmacy['osm_id'], 3);
    expect(pharmacy['kind'], 'health');
    expect(pharmacy['address'], {'street': 'Via Roma 4', 'city': 'Brescia'});
    expect(places.last['osm_type'], 'W');
  });

  test('un parcheggio senza nome ha un nome generico', () {
    final places = NearbyAccessibleService.parse(
      NearbyFilter.parking,
      overpass([
        {
          'type': 'node',
          'id': 1,
          'lat': 45.54,
          'lon': 10.22,
          'tags': {'amenity': 'parking_space', 'parking_space': 'disabled'},
        },
      ]),
      center,
    );
    expect(places.single['name'], 'Parcheggio per disabili');
  });

  test('se Overpass non risponde il risultato è null', () async {
    final service = NearbyAccessibleService(
      client: MockClient((_) async => http.Response('errore', 504)),
    );
    expect(await service.search(NearbyFilter.toilets, center), isNull);
    final ok = NearbyAccessibleService(
      client: MockClient(
        (_) async => http.Response(jsonEncode(overpass(const [])), 200),
      ),
    );
    expect(await ok.search(NearbyFilter.toilets, center), isEmpty);
  });

  group('Filtri sotto la casella', () {
    Widget dropdown(
      NearbySearch nearby,
      ValueChanged<NearbyFilter?> onFilter,
    ) => MaterialApp(
      home: Scaffold(
        body: SearchDropdown(
          isStart: false,
          items: const [],
          showRecentHeader: true,
          noResultsFor: null,
          userLocation: null,
          showLocationShortcuts: false,
          onSelect: (_, _) {},
          onRemoveRecent: (_) {},
          onUseMyLocation: () {},
          onChooseOnMap: () {},
          nearby: nearby,
          onNearbyFilter: onFilter,
        ),
      ),
    );

    testWidgets('scegliere un filtro lo attiva', (tester) async {
      NearbyFilter? chosen;
      await tester.pumpWidget(
        dropdown(const NearbySearch(), (f) => chosen = f),
      );
      await tester.tap(find.text('Parcheggi disabili'));
      expect(chosen, NearbyFilter.parking);
    });

    testWidgets('mostra risultati, attesa ed errori', (tester) async {
      await tester.pumpWidget(
        dropdown(
          const NearbySearch(
            filter: NearbyFilter.toilets,
            results: [
              {
                'name': 'Bagno accessibile',
                'lat': 45.54,
                'lon': 10.22,
                'kind': 'poi',
              },
            ],
          ),
          (_) {},
        ),
      );
      expect(
        find.text('Bagni accessibili in questa zona della mappa'),
        findsOneWidget,
      );
      expect(find.text('Bagno accessibile'), findsOneWidget);
      expect(find.text('Recenti'), findsNothing);

      await tester.pumpWidget(
        dropdown(
          const NearbySearch(filter: NearbyFilter.toilets, results: []),
          (_) {},
        ),
      );
      expect(find.textContaining('Nessun luogo segnato'), findsOneWidget);

      await tester.pumpWidget(
        dropdown(const NearbySearch(filter: NearbyFilter.toilets), (_) {}),
      );
      expect(find.textContaining('Ricerca non riuscita'), findsOneWidget);
    });
  });
}
