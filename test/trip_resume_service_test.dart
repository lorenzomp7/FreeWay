import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/travel_mode.dart';
import 'package:freeway/services/trip_resume_service.dart';
import 'package:freeway/widgets/navigation_prompts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final started = DateTime(2026, 11, 18, 10);
  final trip = PendingTrip(
    destination: const LatLng(45.5398, 10.2195),
    label: 'Piazza della Loggia, Brescia',
    mode: TravelMode.walking,
    startedAt: started,
  );

  test('la navigazione interrotta si ritrova alla riapertura', () async {
    await TripResumeService().save(trip);
    final loaded = await TripResumeService().load(
      now: started.add(const Duration(minutes: 20)),
    );
    expect(loaded?.label, 'Piazza della Loggia, Brescia');
    expect(loaded?.mode, TravelMode.walking);
    expect(loaded?.destination, const LatLng(45.5398, 10.2195));
  });

  test('dopo 3 ore, o dopo averla chiusa, non si propone più', () async {
    final service = TripResumeService();
    await service.save(trip);
    expect(
      await service.load(now: started.add(const Duration(hours: 4))),
      isNull,
    );
    // Il viaggio scaduto viene anche cancellato.
    expect(await service.load(now: started), isNull);

    await service.save(trip);
    await service.clear();
    expect(await service.load(now: started), isNull);
  });

  test('dati illeggibili non bloccano l\'app', () async {
    SharedPreferences.setMockInitialValues({
      TripResumeService.storageKey: '{"lat": "x"}',
    });
    expect(await TripResumeService().load(), isNull);
  });

  testWidgets('"Stai ancora andando a…?" con Riprendi e No', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResumeTripCard(
            destination: 'Piazza della Loggia',
            onResume: () => actions.add('riprendi'),
            onDismiss: () => actions.add('no'),
          ),
        ),
      ),
    );
    expect(
      find.text('Stai ancora andando a Piazza della Loggia?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Riprendi'));
    await tester.tap(find.text('No'));
    expect(actions, ['riprendi', 'no']);
  });
}
