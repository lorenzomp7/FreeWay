import 'dart:typed_data';

import 'tile_store_memory.dart'
    if (dart.library.js_interop) 'tile_store_web.dart';

/// Dove si tengono le tile salvate per l'uso senza rete. Sul web è la Cache
/// Storage del browser, che resta anche chiudendo la pagina; altrove (e nei
/// test) la memoria.
abstract class TileStore {
  factory TileStore() => createTileStore();

  Future<void> put(String url, Uint8List bytes);
  Future<Uint8List?> get(String url);
  Future<void> clear();
}

/// Archivio in memoria, usato fuori dal web e nei test.
class MemoryTileStore implements TileStore {
  final Map<String, Uint8List> _tiles = {};

  @override
  Future<void> put(String url, Uint8List bytes) async => _tiles[url] = bytes;

  @override
  Future<Uint8List?> get(String url) async => _tiles[url];

  @override
  Future<void> clear() async => _tiles.clear();

  int get length => _tiles.length;
}
