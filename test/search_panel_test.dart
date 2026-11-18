import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/travel_mode.dart';
import 'package:freeway/widgets/search_panel.dart';

const loggia = {
  'name': 'Piazza della Loggia',
  'lat': 45.5398,
  'lon': 10.2195,
  'address': {'city': 'Brescia', 'state': 'Lombardia'},
};

/// Pannello con valori predefiniti e callback che registrano le azioni.
class Harness {
  final start = TextEditingController();
  final end = TextEditingController();
  final startFocus = FocusNode();
  final endFocus = FocusNode();
  final actions = <String>[];

  Widget build({
    SearchPhase phase = SearchPhase.search,
    List<SearchItem> endItems = const [],
    List<Map<String, dynamic>> recents = const [],
    String? noResultsForEnd,
    bool hasEndPoint = false,
    TravelMode mode = TravelMode.wheelchair,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SearchPanel(
          stage: phase,
          startController: start,
          endController: end,
          startFocus: startFocus,
          endFocus: endFocus,
          startItems: const [],
          endItems: endItems,
          recentPlaces: recents,
          noResultsForStart: null,
          noResultsForEnd: noResultsForEnd,
          userLocation: null,
          isLocatingStart: false,
          isLocatingEnd: false,
          isCalculating: false,
          canCalculate: false,
          hasStartPoint: false,
          hasEndPoint: hasEndPoint,
          travelMode: mode,
          onStartChanged: (_) {},
          onEndChanged: (_) {},
          onSubmitted: (isStart) => actions.add('submit $isStart'),
          onSelectSuggestion: (place, isStart) =>
              actions.add('select ${place['name']} $isStart'),
          onRemoveRecent: (place) => actions.add('remove ${place['name']}'),
          onUseMyLocation: ({required isStart}) =>
              actions.add('my location $isStart'),
          onChooseOnMap: ({required isStart}) => actions.add('map $isStart'),
          onClear: ({required isStart}) => actions.add('clear $isStart'),
          onSwap: () => actions.add('swap'),
          onCalculate: () => actions.add('calculate'),
          onTravelModeChanged: (mode) => actions.add('mode ${mode.name}'),
          onOpenDirections: () => actions.add('directions'),
          onCloseDirections: () => actions.add('close directions'),
          onClosePlace: () => actions.add('close place'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('toccando la casella vuota compaiono le ricerche recenti', (
    tester,
  ) async {
    final h = Harness();
    await tester.pumpWidget(h.build(recents: [loggia]));
    expect(find.text('Recenti'), findsNothing);

    h.endFocus.requestFocus();
    await tester.pumpWidget(h.build(recents: [loggia]));

    expect(find.text('Recenti'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    await tester.tap(find.text('Piazza della Loggia'));
    expect(h.actions, contains('select Piazza della Loggia false'));

    await tester.tap(find.byTooltip('Elimina dalla cronologia'));
    expect(h.actions, contains('remove Piazza della Loggia'));
  });

  testWidgets('senza risultati lo dice invece di restare vuoto', (
    tester,
  ) async {
    final h = Harness()..end.text = 'xyzw';
    await tester.pumpWidget(h.build(noResultsForEnd: 'xyzw'));
    h.endFocus.requestFocus();
    await tester.pumpWidget(h.build(noResultsForEnd: 'xyzw'));

    expect(find.textContaining('Nessun risultato per «xyzw»'), findsOneWidget);
    expect(find.text('Recenti'), findsNothing);
  });

  testWidgets('i suggerimenti mostrano nome, città e icona del tipo', (
    tester,
  ) async {
    final h = Harness()..end.text = 'farm';
    await tester.pumpWidget(h.build());
    h.endFocus.requestFocus();
    await tester.pumpWidget(
      h.build(
        endItems: [
          const SearchItem({
            'name': 'Farmacia Centrale',
            'lat': 45.54,
            'lon': 10.22,
            'kind': 'health',
            'address': {'city': 'Brescia'},
          }),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Farmacia Centrale'), findsOneWidget);
    expect(find.text('Brescia'), findsOneWidget);
    expect(find.byIcon(Icons.local_hospital_outlined), findsOneWidget);
  });

  testWidgets('nelle indicazioni ci sono posizione, mappa e mezzi', (
    tester,
  ) async {
    final h = Harness();
    await tester.pumpWidget(h.build(phase: SearchPhase.directions));

    // Nessun campo attivo: si sceglie il mezzo.
    expect(find.text('Sedia a rotelle'), findsOneWidget);
    await tester.tap(find.text('A piedi'));
    expect(h.actions, contains('mode walking'));

    h.startFocus.requestFocus();
    await tester.pumpWidget(h.build(phase: SearchPhase.directions));
    await tester.tap(find.text('La tua posizione'));
    await tester.tap(find.text('Scegli sulla mappa'));
    expect(h.actions, containsAll(['my location true', 'map true']));
  });

  testWidgets('con un luogo scelto si torna indietro con la freccia', (
    tester,
  ) async {
    final h = Harness()..end.text = 'Piazza della Loggia, Brescia';
    await tester.pumpWidget(
      h.build(phase: SearchPhase.place, hasEndPoint: true),
    );

    await tester.tap(find.byTooltip('Torna alla ricerca'));
    await tester.tap(find.byTooltip('Indicazioni'));
    expect(h.actions, ['close place', 'directions']);
  });
}
