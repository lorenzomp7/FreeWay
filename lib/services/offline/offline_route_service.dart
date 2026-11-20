import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;
import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../geo_utils.dart';
import 'tile_store.dart';

/// Indirizzo delle tile di OpenStreetMap usato dalla mappa.
const String kOsmTileTemplate =
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

String osmTileUrl(int z, int x, int y) =>
    'https://tile.openstreetmap.org/$z/$x/$y.png';

/// Esito di "Salva per l'uso senza rete".
enum OfflineSaveResult { saved, partial, tooLong, failed }

/// "Salva per l'uso senza rete", come "Download offline map" di Google Maps
/// ma ridotto al tragitto: si salvano le tile di un corridoio intorno al
/// percorso agli zoom 15 e 16. Le regole d'uso delle tile di OpenStreetMap
/// vietano di scaricare grandi aree, soprattutto dallo zoom 17 in su: per
/// questo il corridoio è stretto, gli zoom sono bassi, c'è un tetto di tile e
/// il download parte solo su richiesta.
class OfflineRouteService {
  OfflineRouteService({
    TileStore? store,
    http.Client? client,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? clock,
  }) : store = store ?? TileStore(),
       _client = client ?? http.Client(),
       _preferences = preferences ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now;

  final TileStore store;
  final http.Client _client;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _clock;

  static const List<int> zooms = [15, 16];

  /// Zoom a cui la mappa segue la posizione quando si è senza rete.
  static const double offlineZoom = 16;

  /// Distanza dal percorso coperta dalle tile salvate.
  static const double corridorMeters = 120;

  /// Tetto di tile per un percorso: basta per qualche chilometro a piedi.
  static const int maxTiles = 160;

  /// Le tile salvate si tengono una settimana, come chiede OpenStreetMap.
  static const Duration lifetime = Duration(days: 7);

  static const String _indexKey = 'freeway.offline_tiles';

  final Set<String> _saved = {};

  /// Indirizzi delle tile disponibili senza rete.
  Set<String> get saved => Set.unmodifiable(_saved);
  bool get hasSavedRoute => _saved.isNotEmpty;
  bool isSaved(String url) => _saved.contains(url);

  Future<void> load() async {
    try {
      final raw = (await _preferences()).getString(_indexKey);
      if (raw == null) return;
      final data = jsonDecode(raw);
      final savedAt = DateTime.tryParse('${data['savedAt']}');
      if (savedAt == null || _clock().difference(savedAt) > lifetime) {
        await clear();
        return;
      }
      _saved
        ..clear()
        ..addAll((data['urls'] as List).whereType<String>());
    } catch (_) {
      _saved.clear();
    }
  }

  Future<void> clear() async {
    _saved.clear();
    await store.clear();
    try {
      await (await _preferences()).remove(_indexKey);
    } catch (_) {
      // Nessun archivio: va bene così.
    }
  }

  /// Salva le tile del percorso. Prende il posto del percorso salvato prima.
  Future<OfflineSaveResult> saveRoute(
    List<LatLng> route, {
    void Function(int done, int total)? onProgress,
  }) async {
    final tiles = tilesForRoute(route);
    if (tiles == null) return OfflineSaveResult.tooLong;
    await clear();
    final urls = [for (final t in tiles) osmTileUrl(t.$1, t.$2, t.$3)];
    var done = 0;
    var failures = 0;
    final saved = <String>[];
    onProgress?.call(0, urls.length);
    // Poche richieste alla volta, per non pesare sui server di OSM.
    for (var i = 0; i < urls.length; i += 2) {
      await Future.wait([
        for (final url in urls.skip(i).take(2))
          _fetch(url).then((ok) {
            done++;
            if (ok) {
              saved.add(url);
            } else {
              failures++;
            }
            onProgress?.call(done, urls.length);
          }),
      ]);
    }
    _saved.addAll(saved);
    try {
      await (await _preferences()).setString(
        _indexKey,
        jsonEncode({'savedAt': _clock().toIso8601String(), 'urls': saved}),
      );
    } catch (_) {
      // Le tile restano disponibili finché la pagina è aperta.
    }
    if (saved.isEmpty) return OfflineSaveResult.failed;
    return failures == 0 ? OfflineSaveResult.saved : OfflineSaveResult.partial;
  }

  Future<bool> _fetch(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return false;
      }
      await store.put(url, response.bodyBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Tile (zoom, x, y) del corridoio intorno al percorso, o `null` se sono
  /// più di [maxTiles] (percorso troppo lungo).
  @visibleForTesting
  static Set<(int, int, int)>? tilesForRoute(List<LatLng> route) {
    if (route.isEmpty) return {};
    final samples = <LatLng>[route.first];
    for (var i = 1; i < route.length; i++) {
      final a = route[i - 1];
      final b = route[i];
      final steps = (haversineDistance(a, b) / 40).ceil();
      for (var s = 1; s <= steps; s++) {
        final t = s / steps;
        samples.add(
          LatLng(
            a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t,
          ),
        );
      }
    }
    final tiles = <(int, int, int)>{};
    for (final z in zooms) {
      for (final p in samples) {
        final dLat = corridorMeters / 111320;
        final dLon =
            corridorMeters /
            (111320 * math.cos(p.latitude * math.pi / 180)).abs().clamp(
              1,
              double.infinity,
            );
        final (x1, y1) = tileXY(p.latitude + dLat, p.longitude - dLon, z);
        final (x2, y2) = tileXY(p.latitude - dLat, p.longitude + dLon, z);
        for (var x = x1; x <= x2; x++) {
          for (var y = y1; y <= y2; y++) {
            tiles.add((z, x, y));
            if (tiles.length > maxTiles) return null;
          }
        }
      }
    }
    return tiles;
  }

  /// Coordinate della tile che contiene il punto, allo zoom [z].
  @visibleForTesting
  static (int, int) tileXY(double lat, double lon, int z) {
    final n = 1 << z;
    final x = ((lon + 180) / 360 * n).floor().clamp(0, n - 1);
    final rad = lat * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * n)
            .floor()
            .clamp(0, n - 1);
    return (x, y);
  }

  void dispose() => _client.close();
}

/// Tile della mappa: quelle salvate per il percorso arrivano dall'archivio,
/// anche senza rete; le altre dalla rete come sempre.
class RouteTileProvider extends TileProvider {
  RouteTileProvider(this._service) : super() {
    _network = CancellableNetworkTileProvider(headers: headers);
  }

  final OfflineRouteService _service;
  late final CancellableNetworkTileProvider _network;

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    final url = getTileUrl(coordinates, options);
    if (_service.isSaved(url)) {
      return StoredTileImage(url, _service.store);
    }
    return _network.getImageWithCancelLoadingSupport(
      coordinates,
      options,
      cancelLoading,
    );
  }

  @override
  Future<void> dispose() async {
    await _network.dispose();
    super.dispose();
  }
}

/// Immagine di una tile letta dall'archivio delle tile salvate.
@immutable
class StoredTileImage extends ImageProvider<StoredTileImage> {
  const StoredTileImage(this.url, this.store);

  final String url;
  final TileStore store;

  @override
  Future<StoredTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    StoredTileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<Codec> _load(ImageDecoderCallback decode) async {
    final Uint8List? bytes = await store.get(url);
    if (bytes == null) throw StateError('Tile non salvata: $url');
    return decode(await ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is StoredTileImage && other.url == url;

  @override
  int get hashCode => url.hashCode;
}
