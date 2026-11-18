import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/saved_places_service.dart';
import 'package:freeway/widgets/saved_places_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> place(String name, double lat, double lon) => {
  'name': name,
  'display_name': name,
  'lat': lat,
  'lon': lon,
  'address': {'city': 'Brescia', 'road': 'Via Musei'},
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Casa e Lavoro sono uno solo: il nuovo sostituisce il vecchio',
    () async {
      final service = SavedPlacesService();
      await service.save(place('Via Roma 1', 45.53, 10.21), SavedKind.home);
      await service.save(place('Via Milano 5', 45.54, 10.20), SavedKind.home);
      await service.save(place('Università', 45.56, 10.23), SavedKind.work);

      expect(service.home!.place['name'], 'Via Milano 5');
      expect(service.home!.label, 'Casa');
      expect(service.work!.label, 'Lavoro');
      expect(service.places, hasLength(2));
    },
  );

  test('un luogo può essere Casa e anche avere un nome', () async {
    final service = SavedPlacesService();
    final home = place('Via Roma 1', 45.53, 10.21);
    await service.save(home, SavedKind.home);
    await service.save(home, SavedKind.other, label: '  Da mamma  ');

    expect(service.savedAs(home).map((s) => s.label), ['Da mamma', 'Casa']);
  });

  test('salvare di nuovo con un nome lo rinomina senza doppioni', () async {
    final service = SavedPlacesService();
    final clinic = place('Poliambulatorio', 45.55, 10.22);
    await service.save(clinic, SavedKind.other, label: 'Ambulatorio');
    await service.save(clinic, SavedKind.other, label: 'Fisioterapia');

    expect(service.others.map((s) => s.label), ['Fisioterapia']);
  });

  test('i salvati restano sul dispositivo, si cercano e si tolgono', () async {
    final first = SavedPlacesService();
    await first.save(
      place('Poliambulatorio', 45.55, 10.22),
      SavedKind.other,
      label: 'Fisioterapia',
    );
    await first.save(place('Via Roma 1', 45.53, 10.21), SavedKind.home);

    final reloaded = SavedPlacesService();
    await reloaded.load();
    expect(reloaded.places, hasLength(2));
    expect(reloaded.matching('fisio').single.label, 'Fisioterapia');
    expect(reloaded.matching('casa').single.kind, SavedKind.home);
    expect(reloaded.matching('musei brescia'), hasLength(2));
    expect(reloaded.matching(''), isEmpty);

    await reloaded.remove(reloaded.home!);
    expect((await SavedPlacesService().load()).single.label, 'Fisioterapia');
  });

  test('dati rovinati non bloccano la app', () async {
    SharedPreferences.setMockInitialValues({
      SavedPlacesService.storageKey:
          '[{"kind":"home"},"x",{"label":"A",'
          '"place":{"lat":45.5,"lon":10.2}}]',
    });
    final saved = await SavedPlacesService().load();
    expect(saved.single.label, 'A');
    expect(saved.single.kind, SavedKind.other);
  });

  testWidgets('le scorciatoie dicono se Casa e Lavoro sono impostati', (
    tester,
  ) async {
    final tapped = <SavedKind>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedShortcuts(
            home: SavedPlace(
              kind: SavedKind.home,
              label: 'Casa',
              place: place('Via Roma 1', 45.53, 10.21),
            ),
            work: null,
            onTap: tapped.add,
          ),
        ),
      ),
    );

    expect(find.text('Via Roma 1'), findsOneWidget);
    expect(find.text('Imposta'), findsOneWidget);
    await tester.tap(find.text('Lavoro'));
    expect(tapped, [SavedKind.work]);
  });

  testWidgets('la scheda Salva propone Casa, Lavoro e un nome', (tester) async {
    SaveChoice? choice;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showSavePlaceSheet(
                context,
                placeName: 'Poliambulatorio',
                current: const [],
              );
            },
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Lavoro'), findsOneWidget);

    await tester.tap(find.text('Con un nome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fisioterapia');
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(choice, isA<SaveAs>());
    expect((choice! as SaveAs).kind, SavedKind.other);
    expect((choice! as SaveAs).label, 'Fisioterapia');
  });
}
