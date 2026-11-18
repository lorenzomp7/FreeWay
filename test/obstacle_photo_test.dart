import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/services/obstacle_service.dart';
import 'package:freeway/widgets/obstacle_sheets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

/// PNG 1x1 valido.
final pixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget host(Widget Function(BuildContext) onOpen) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => onOpen(context),
        child: const Text('apri'),
      ),
    ),
  ),
);

void main() {
  test('hasPhoto si legge dal documento', () {
    final data = {
      'lat': 45.5,
      'lng': 10.2,
      'type': 'Gradino',
      'hasPhoto': true,
    };
    expect(Obstacle.fromMap('a', data).hasPhoto, isTrue);
    expect(
      Obstacle.fromMap('b', {...data}..remove('hasPhoto')).hasPhoto,
      isFalse,
    );
  });

  test('le foto troppo grandi non passano il limite delle regole', () {
    expect(ObstacleService.photoFits(pixel), isTrue);
    expect(ObstacleService.photoFits(Uint8List(600000)), isFalse);
  });

  testWidgets('la segnalazione porta con sé la foto scelta', (tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ReportDraft? draft;
    final sources = <ImageSource>[];
    await tester.pumpWidget(
      host((context) {
        showReportObstacleSheet(
          context,
          pickPhoto: (source) async {
            sources.add(source);
            return pixel;
          },
        ).then((value) => draft = value);
        return const SizedBox();
      }),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gradino che rende impossibile il passaggio'));
    await tester.tap(find.text('Scegli dalla galleria'));
    await tester.pumpAndSettle();
    expect(sources, [ImageSource.gallery]);
    expect(find.bySemanticsLabel("Foto dell'ostacolo"), findsOneWidget);

    await tester.tap(find.text('Invia segnalazione'));
    await tester.pumpAndSettle();
    expect(draft?.type, 'Gradino che rende impossibile il passaggio');
    expect(draft?.photo, pixel);
  });

  testWidgets('la scheda mostra la foto solo se la segnalazione ne ha una', (
    tester,
  ) async {
    final loaded = <String>[];
    Future<Uint8List?> load(String id) async {
      loaded.add(id);
      return pixel;
    }

    for (final withPhoto in [false, true]) {
      final obstacle = Obstacle(
        id: withPhoto ? 'con' : 'senza',
        position: const LatLng(45.5, 10.2),
        type: 'Gradino che rende impossibile il passaggio',
        hasPhoto: withPhoto,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ObstacleDetailsSheet(obstacle: obstacle, loadPhoto: load),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel("Foto dell'ostacolo segnalato"),
        withPhoto ? findsOneWidget : findsNothing,
      );
    }
    expect(loaded, ['con']);
  });
}
