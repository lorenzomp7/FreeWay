import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'tile_store.dart';

TileStore createTileStore() => _CacheTileStore();

/// Tile nella Cache Storage del browser: non serve un service worker.
class _CacheTileStore implements TileStore {
  static const String _name = 'freeway-percorso';
  final MemoryTileStore _fallback = MemoryTileStore();

  Future<web.Cache?> _open() async {
    try {
      return await web.window.caches.open(_name).toDart;
    } catch (_) {
      // Navigazione privata o pagina non sicura: si usa la memoria.
      return null;
    }
  }

  @override
  Future<void> put(String url, Uint8List bytes) async {
    final cache = await _open();
    if (cache == null) return _fallback.put(url, bytes);
    await cache
        .put(
          url.toJS,
          web.Response(
            bytes.toJS,
            web.ResponseInit(
              headers: {'Content-Type': 'image/png'}.jsify()! as JSObject,
            ),
          ),
        )
        .toDart;
  }

  @override
  Future<Uint8List?> get(String url) async {
    final cache = await _open();
    if (cache == null) return _fallback.get(url);
    final match = await cache.match(url.toJS).toDart;
    if (match == null) return null;
    final buffer = await match.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  @override
  Future<void> clear() async {
    await _fallback.clear();
    try {
      await web.window.caches.delete(_name).toDart;
    } catch (_) {
      // Niente da cancellare.
    }
  }
}
