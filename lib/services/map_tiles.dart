import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Tile della mappa: CARTO Voyager (tema chiaro) e Dark Matter (tema scuro),
/// disegnate dai dati di OpenStreetMap.
///
/// Rispetto alle tile di tile.openstreetmap.org hanno la versione `@2x`, a
/// 512 pixel: sui telefoni ad alta densità la mappa resta nitida invece di
/// essere un'immagine da 256 pixel ingrandita. Il tema scuro è uno stile vero,
/// non più un filtro che inverte i colori.
///
/// Uso gratuito con l'attribuzione di [kMapAttribution]; condizioni:
/// https://carto.com/basemaps e https://www.openstreetmap.org/copyright.
const String _cartoHost = 'https://basemaps.cartocdn.com/rastertiles';

/// Stile delle tile per il tema dell'app.
String tileStyleFor(Brightness brightness) =>
    brightness == Brightness.dark ? 'dark_all' : 'voyager';

/// Modello per [TileLayer.urlTemplate]: `{r}` diventa `@2x` quando la
/// [TileLayer] ha `retinaMode` attivo.
String tileTemplateFor(Brightness brightness) =>
    '$_cartoHost/${tileStyleFor(brightness)}/{z}/{x}/{y}{r}.png';

/// Indirizzo di una tile, come lo chiede la mappa: serve a "Salva per l'uso
/// senza rete", che deve salvare proprio le tile che la mappa mostrerà.
String tileUrl(
  Brightness brightness,
  int z,
  int x,
  int y, {
  required bool highDensity,
}) =>
    '$_cartoHost/${tileStyleFor(brightness)}/$z/$x/$y'
    '${highDensity ? '@2x' : ''}.png';

/// Ultimo zoom con tile vere: oltre si ingrandiscono quelle di questo livello.
const int kMaxNativeTileZoom = 20;

/// Attribuzione obbligatoria dei dati e delle tile.
const String kMapAttribution = '© OpenStreetMap contributors © CARTO';

/// Lo schermo ha più di un pixel fisico per pixel logico: servono le `@2x`.
bool isHighDensity(BuildContext context) => RetinaMode.isHighDensity(context);

/// Coordinate (zoom, x, y) di una tile dal suo indirizzo, qualunque stile o
/// densità abbia; `null` se l'indirizzo non è una tile.
(int, int, int)? tileCoordinatesOf(String url) {
  final match = RegExp(r'/(\d+)/(\d+)/(\d+)(?:@2x)?\.png$').firstMatch(url);
  if (match == null) return null;
  return (
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
