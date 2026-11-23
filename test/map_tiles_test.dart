import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/map_tiles.dart';

void main() {
  test('stile chiaro Voyager e stile scuro Dark Matter', () {
    expect(tileStyleFor(Brightness.light), 'rastertiles/voyager');
    expect(tileStyleFor(Brightness.dark), 'dark_all');
    expect(
      tileTemplateFor(Brightness.dark),
      'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    );
  });

  test('sugli schermi ad alta densità si chiedono le tile @2x', () {
    expect(
      tileUrl(Brightness.light, 16, 34628, 23435, highDensity: true),
      'https://a.basemaps.cartocdn.com/rastertiles/voyager/16/34628/23435@2x.png',
    );
    expect(
      tileUrl(Brightness.light, 16, 34628, 23435, highDensity: false),
      'https://a.basemaps.cartocdn.com/rastertiles/voyager/16/34628/23435.png',
    );
  });

  test('la mappa chiede le stesse tile salvate per l\'uso senza rete', () {
    for (final brightness in Brightness.values) {
      for (final retina in [true, false]) {
        final layer = TileLayer(
          urlTemplate: tileTemplateFor(brightness),
          retinaMode: retina,
        );
        final requested = TileProvider.templatePlaceholderElement
            .allMatches(layer.urlTemplate!)
            .isNotEmpty;
        expect(requested, isTrue);
        final url = NetworkTileProvider().getTileUrl(
          const TileCoordinates(34628, 23435, 16),
          layer,
        );
        expect(
          url,
          tileUrl(brightness, 16, 34628, 23435, highDensity: retina),
          reason: 'stile $brightness, retina $retina',
        );
      }
    }
  });

  test('le coordinate si leggono da ogni indirizzo di tile', () {
    expect(
      tileCoordinatesOf(
        tileUrl(Brightness.dark, 15, 17314, 11717, highDensity: true),
      ),
      (15, 17314, 11717),
    );
    expect(tileCoordinatesOf('https://example.org/pagina'), isNull);
  });

  test('l\'attribuzione cita OpenStreetMap e CARTO', () {
    expect(kMapAttribution, contains('OpenStreetMap'));
    expect(kMapAttribution, contains('CARTO'));
  });
}
