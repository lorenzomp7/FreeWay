import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/recent_places_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> place(String name, double lat, double lon) => {
  'name': name,
  'display_name': name,
  'lat': lat,
  'lon': lon,
  'address': {'city': 'Brescia', 'state': 'Lombardia'},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('il luogo cercato di nuovo torna in cima senza doppioni', () async {
    final service = RecentPlacesService();
    await service.add(place('Piazza Loggia', 45.5398, 10.2195));
    await service.add(place('Castello', 45.5433, 10.2253));
    final recents = await service.add(place('Piazza Loggia', 45.5398, 10.2195));

    expect(recents.map((p) => p['name']), ['Piazza Loggia', 'Castello']);
  });

  test('la cronologia resta sul dispositivo e ha un limite', () async {
    final first = RecentPlacesService();
    for (var i = 0; i < RecentPlacesService.maxPlaces + 3; i++) {
      await first.add(place('Luogo $i', 45.5 + i / 100, 10.2));
    }

    final reloaded = await RecentPlacesService().load();
    expect(reloaded, hasLength(RecentPlacesService.maxPlaces));
    expect(
      reloaded.first['name'],
      'Luogo ${RecentPlacesService.maxPlaces + 2}',
    );
  });

  test('si può togliere un luogo e cercare tra i recenti', () async {
    final service = RecentPlacesService();
    await service.add(place('Piazza Loggia', 45.5398, 10.2195));
    await service.add(place('Stazione di Brescia', 45.5325, 10.2131));

    expect(service.matching('stazione bre').map((p) => p['name']), [
      'Stazione di Brescia',
    ]);
    expect(service.matching('lombardia'), hasLength(2));
    expect(service.matching('  '), isEmpty);

    final left = await service.remove(place('Piazza Loggia', 45.5398, 10.2195));
    expect(left.map((p) => p['name']), ['Stazione di Brescia']);
  });

  test('una cronologia illeggibile non blocca la ricerca', () async {
    SharedPreferences.setMockInitialValues({
      RecentPlacesService.storageKey: 'non è json',
    });
    expect(await RecentPlacesService().load(), isEmpty);
  });
}
