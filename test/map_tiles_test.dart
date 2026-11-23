import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/map_tiles.dart';

const carto = MapTiles(cartoKey: 'chiave-di-prova');
const osm = MapTiles(cartoKey: '');

void main() {
  group('con la chiave CARTO', () {
    test('Voyager in entrambi i temi, leggibile, con la chiave', () {
      expect(carto.isSharp, isTrue);
      expect(MapTiles.cartoStyleFor(Brightness.light), 'rastertiles/voyager');
      expect(MapTiles.cartoStyleFor(Brightness.dark), 'rastertiles/voyager');
      expect(
        carto.templateFor(Brightness.dark),
        'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}'
        '.png?key=chiave-di-prova',
      );
      expect(carto.builderFor(Brightness.dark), isNull);
      // Oltre il 18 CARTO non sempre risponde: si ingrandiscono le tile del
      // 18, invece di lasciare la mappa bianca.
      expect(carto.maxNativeZoom, 18);
      expect(carto.attribution, contains('CARTO'));
      expect(carto.attribution, contains('OpenStreetMap'));
    });

    test('sugli schermi ad alta densità si chiedono le tile @2x', () {
      expect(
        carto.url(Brightness.light, 16, 34628, 23435, highDensity: true),
        'https://a.basemaps.cartocdn.com/rastertiles/voyager/16/34628/23435'
        '@2x.png?key=chiave-di-prova',
      );
      expect(
        carto.url(Brightness.light, 16, 34628, 23435, highDensity: false),
        'https://a.basemaps.cartocdn.com/rastertiles/voyager/16/34628/23435'
        '.png?key=chiave-di-prova',
      );
    });
  });

  group('senza chiave', () {
    test('tile di OpenStreetMap con il filtro del tema scuro, come prima', () {
      expect(osm.isSharp, isFalse);
      expect(
        osm.templateFor(Brightness.dark),
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(osm.builderFor(Brightness.dark), isNotNull);
      expect(osm.maxNativeZoom, 19);
      expect(osm.attribution, '© OpenStreetMap contributors');
      expect(
        osm.url(Brightness.dark, 16, 34628, 23435, highDensity: true),
        'https://tile.openstreetmap.org/16/34628/23435.png',
      );
    });
  });

  testWidgets('niente tile @2x simulate con OpenStreetMap', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    late bool osmRetina;
    late bool cartoRetina;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          osmRetina = osm.retinaFor(context);
          cartoRetina = carto.retinaFor(context);
          return const SizedBox();
        },
      ),
    );
    expect(osmRetina, isFalse);
    expect(cartoRetina, isTrue);
  });

  test('la mappa chiede le stesse tile salvate per l\'uso senza rete', () {
    for (final tiles in [carto, osm]) {
      for (final brightness in Brightness.values) {
        for (final retina in [true, false]) {
          final layer = TileLayer(
            urlTemplate: tiles.templateFor(brightness),
            retinaMode: retina && tiles.isSharp,
          );
          final url = NetworkTileProvider().getTileUrl(
            const TileCoordinates(34628, 23435, 16),
            layer,
          );
          expect(
            url,
            tiles.url(
              brightness,
              16,
              34628,
              23435,
              highDensity: retina && tiles.isSharp,
            ),
            reason: 'CARTO ${tiles.isSharp}, $brightness, retina $retina',
          );
        }
      }
    }
  });

  test('le coordinate si leggono da ogni indirizzo di tile', () {
    expect(
      tileCoordinatesOf(
        carto.url(Brightness.dark, 15, 17314, 11717, highDensity: true),
      ),
      (15, 17314, 11717),
    );
    expect(
      tileCoordinatesOf(osm.url(Brightness.dark, 15, 1, 2, highDensity: false)),
      (15, 1, 2),
    );
    expect(tileCoordinatesOf('https://example.org/pagina'), isNull);
  });
}
