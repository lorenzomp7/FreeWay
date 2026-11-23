import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Chiave di CARTO per le tile nitide, passata in fase di build con
/// `--dart-define=CARTO_KEY=...`. È una chiave pensata per i browser (finisce
/// nel codice pubblico del sito, come quella di OpenRouteService): gratuita
/// per progetti non commerciali entro una quota mensile, vedi
/// https://github.com/CartoDB/basemap-styles. Vuota: tile di OpenStreetMap.
const String kCartoKey = String.fromEnvironment('CARTO_KEY');

const String _osmTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _cartoHost = 'https://a.basemaps.cartocdn.com';

/// Le tile della mappa.
///
/// Con la chiave di CARTO: Voyager, disegnata dai dati di OpenStreetMap, con
/// la versione `@2x` a 512 pixel per i telefoni ad alta densità, così la mappa
/// resta nitida. Senza chiave CARTO mette una filigrana sulle tile, quindi si
/// usano quelle di OpenStreetMap (256 pixel) con un filtro di colore per il
/// tema scuro, come prima.
class MapTiles {
  const MapTiles({this.cartoKey = kCartoKey});

  final String cartoKey;

  /// Tile nitide di CARTO disponibili.
  bool get isSharp => cartoKey.isNotEmpty;

  /// Stile CARTO, come percorso sul server: Voyager in entrambi i temi.
  /// Dark Matter, provato per il tema scuro, era troppo scuro e poco
  /// leggibile; [brightness] resta per poter tornare a due stili.
  static String cartoStyleFor(Brightness brightness) => 'rastertiles/voyager';

  /// Modello per [TileLayer.urlTemplate]: con CARTO `{r}` diventa `@2x`
  /// quando la [TileLayer] ha `retinaMode` attivo.
  String templateFor(Brightness brightness) => isSharp
      ? '$_cartoHost/${cartoStyleFor(brightness)}/{z}/{x}/{y}{r}.png'
            '?key=${Uri.encodeQueryComponent(cartoKey)}'
      : _osmTemplate;

  /// Indirizzo di una tile, come lo chiede la mappa: serve a "Salva per l'uso
  /// senza rete", che deve salvare proprio le tile che la mappa mostrerà.
  String url(
    Brightness brightness,
    int z,
    int x,
    int y, {
    required bool highDensity,
  }) => isSharp
      ? '$_cartoHost/${cartoStyleFor(brightness)}/$z/$x/$y'
            '${highDensity ? '@2x' : ''}.png'
            '?key=${Uri.encodeQueryComponent(cartoKey)}'
      : 'https://tile.openstreetmap.org/$z/$x/$y.png';

  /// Tile `@2x` sugli schermi ad alta densità, solo con CARTO: con
  /// OpenStreetMap la modalità retina simulata chiederebbe il livello dopo,
  /// assente oltre il 19.
  bool retinaFor(BuildContext context) =>
      isSharp && RetinaMode.isHighDensity(context);

  /// Ultimo zoom con tile vere: oltre si ingrandiscono quelle di questo
  /// livello. CARTO non serve sempre le tile oltre il 18 (la mappa restava
  /// bianca allo zoom 19); le @2x del 18 bastano per restare nitida.
  int get maxNativeZoom => isSharp ? 18 : 19;

  /// Filtro di colore delle tile: serve solo a quelle di OpenStreetMap.
  TileBuilder? builderFor(Brightness brightness) {
    if (isSharp) return null;
    return brightness == Brightness.dark ? darkTileBuilder : lightTileBuilder;
  }

  /// Attribuzione obbligatoria dei dati e, con CARTO, delle tile.
  String get attribution => isSharp
      ? '© OpenStreetMap contributors © CARTO'
      : '© OpenStreetMap contributors';
}

/// Stato schermo ad alta densità, per "Salva per l'uso senza rete".
bool isHighDensity(BuildContext context) => RetinaMode.isHighDensity(context);

/// Coordinate (zoom, x, y) di una tile dal suo indirizzo, qualunque stile o
/// densità abbia; `null` se l'indirizzo non è una tile.
(int, int, int)? tileCoordinatesOf(String url) {
  final match = RegExp(
    r'/(\d+)/(\d+)/(\d+)(?:@2x)?\.png(?:\?.*)?$',
  ).firstMatch(url);
  if (match == null) return null;
  return (
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// Filtri colorati delle tile di OpenStreetMap: più chiare o invertite nel
/// tema scuro.
List<double> _tileMatrix(
  double contrast,
  bool invert,
  double offset,
  double saturation,
) {
  final c = invert ? -contrast : contrast;
  final o = invert ? 255 - offset : offset;
  final rg = (0.715 - saturation * 0.715) * c;
  final rb = (0.072 - saturation * 0.072) * c;
  final gr = (0.213 - saturation * 0.213) * c;
  return [
    (0.213 + saturation * 0.787) * c, rg, rb, 0, o, //
    gr, (0.715 + saturation * 0.285) * c, rb, 0, o, //
    gr, rg, (0.072 + saturation * 0.928) * c, 0, o, //
    0, 0, 0, 1, 0, //
  ];
}

Widget lightTileBuilder(BuildContext context, Widget tileWidget, dynamic tile) {
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(_tileMatrix(0.97, false, 8, 0.35)),
    child: tileWidget,
  );
}

Widget darkTileBuilder(BuildContext context, Widget tileWidget, dynamic tile) {
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(_tileMatrix(0.82, true, 18, 0.12)),
    child: tileWidget,
  );
}
