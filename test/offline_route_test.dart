import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/offline/offline_route_service.dart';
import 'package:freeway/services/offline/tile_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Circa 600 m a piedi nel centro di Brescia.
const walk = [
  LatLng(45.5389, 10.2200),
  LatLng(45.5398, 10.2195),
  LatLng(45.5420, 10.2230),
];

OfflineRouteService service(
  MemoryTileStore store, {
  bool Function(Uri url)? fails,
  List<Uri>? requests,
  DateTime Function()? clock,
}) => OfflineRouteService(
  store: store,
  clock: clock,
  client: MockClient((request) async {
    requests?.add(request.url);
    if (fails?.call(request.url) ?? false) return http.Response('', 503);
    return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
  }),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('la tile di un punto è quella di OpenStreetMap', () {
    expect(OfflineRouteService.tileXY(45.5389, 10.22, 16), (34628, 23435));
    expect(OfflineRouteService.tileXY(0, 0, 1), (1, 1));
  });

  test('un breve tragitto a piedi resta sotto il tetto di tile', () {
    final tiles = OfflineRouteService.tilesForRoute(walk)!;
    expect(tiles, isNotEmpty);
    expect(tiles.length, lessThanOrEqualTo(OfflineRouteService.maxTiles));
    expect(tiles.map((t) => t.$1).toSet(), {15, 16});
  });

  test('un percorso troppo lungo non si scarica', () async {
    final long = [const LatLng(45.50, 10.10), const LatLng(45.70, 10.40)];
    expect(OfflineRouteService.tilesForRoute(long), isNull);
    final requests = <Uri>[];
    final offline = service(MemoryTileStore(), requests: requests);
    expect(await offline.saveRoute(long), OfflineSaveResult.tooLong);
    expect(requests, isEmpty);
  });

  test('salva le tile, le ritrova e le ricorda per una settimana', () async {
    final store = MemoryTileStore();
    final progress = <int>[];
    final offline = service(store);
    final result = await offline.saveRoute(
      walk,
      onProgress: (done, _) => progress.add(done),
    );
    expect(result, OfflineSaveResult.saved);
    expect(store.length, offline.saved.length);
    expect(progress.last, offline.saved.length);
    final url = offline.saved.first;
    expect(url, startsWith('https://tile.openstreetmap.org/1'));
    expect(await store.get(url), [1, 2, 3]);

    final reloaded = service(store);
    await reloaded.load();
    expect(reloaded.isSaved(url), isTrue);

    final later = service(
      store,
      clock: () => DateTime.now().add(const Duration(days: 8)),
    );
    await later.load();
    expect(later.hasSavedRoute, isFalse);
  });

  test('se alcune tile non arrivano il salvataggio è parziale', () async {
    final offline = service(
      MemoryTileStore(),
      fails: (url) => url.path.startsWith('/15/'),
    );
    expect(await offline.saveRoute(walk), OfflineSaveResult.partial);
    expect(offline.saved.every((u) => u.contains('/16/')), isTrue);
  });

  test('senza rete il salvataggio fallisce', () async {
    final offline = service(MemoryTileStore(), fails: (_) => true);
    expect(await offline.saveRoute(walk), OfflineSaveResult.failed);
    expect(offline.hasSavedRoute, isFalse);
  });
}
