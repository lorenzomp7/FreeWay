import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/navigation_service.dart';
import 'package:freeway/services/obstacle_alerts.dart';
import 'package:freeway/services/tts_service.dart';
import 'package:freeway/services/voice_guidance.dart';
import 'package:freeway/widgets/voice_settings_sheet.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

final left = RouteStep(
  instruction: 'turn|left|Via Verdi',
  location: const LatLng(45.54, 10.22),
  maneuverType: 'turn',
  modifier: 'left',
  streetName: 'Via Verdi',
);

NavigationUpdate at(double distance) => NavigationUpdate(
  position: const LatLng(45.54, 10.22),
  currentStep: left,
  distanceToNextStep: distance,
  isOffRoute: false,
  progress: 0,
  hasArrived: false,
  stepIndex: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('in modalità breve dice solo la manovra quando è il momento', () {
    final guidance = VoiceGuidance();
    final said = [
      for (final d in <double>[300, 120, 90, 15])
        guidance.next(at(d), 'it', brief: true),
    ].whereType<String>().toList();
    expect(said, ['Svolta a sinistra su Via Verdi']);
  });

  test('avvisa degli ostacoli circa 45 secondi prima', () {
    expect(aheadWarningDistance(0), 80);
    expect(aheadWarningDistance(double.nan), 80);
    expect(aheadWarningDistance(1), 45);
    expect(aheadWarningDistance(0.5), 35);
    expect(aheadWarningDistance(3), 80);
  });

  test('la modalità resta salvata sul dispositivo', () async {
    final tts = TtsService()..guidance = VoiceGuidanceMode.brief;
    await tts.saveSettings();
    final again = TtsService();
    await again.loadSettings();
    expect(again.guidance, VoiceGuidanceMode.brief);
  });

  testWidgets('la scheda della voce cambia la modalità', (tester) async {
    final tts = TtsService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceSettingsSheet(
            tts: tts,
            initialLanguage: 'it',
            onLanguageChanged: (_) {},
            onMutedChanged: (_) {},
          ),
        ),
      ),
    );
    expect(
      find.text('Annuncia ogni svolta in anticipo e quando è il momento.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Breve'));
    await tester.pump();
    expect(tts.guidance, VoiceGuidanceMode.brief);
    expect(find.textContaining('Solo quando è il momento'), findsOneWidget);
  });
}
