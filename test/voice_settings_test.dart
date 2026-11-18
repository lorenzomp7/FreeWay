import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/tts_service.dart';
import 'package:freeway/widgets/voice_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('volume e velocità restano salvati sul dispositivo', () async {
    final tts = TtsService()
      ..volume = VoiceVolume.low
      ..speed = VoiceSpeed.slow;
    await tts.saveSettings();

    final again = TtsService();
    await again.loadSettings();
    expect(again.volume, VoiceVolume.low);
    expect(again.speed, VoiceSpeed.slow);
  });

  test('sul telefono la velocità normale è quella del motore vocale', () {
    expect(VoiceSpeed.normal.mobileRate, 0.5);
    expect(VoiceSpeed.slow.webRate, lessThan(VoiceSpeed.normal.webRate));
  });

  testWidgets('la scheda cambia volume, velocità, lingua e voce attiva', (
    tester,
  ) async {
    final tts = TtsService();
    String? language;
    bool? muted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceSettingsSheet(
            tts: tts,
            initialLanguage: 'it',
            onLanguageChanged: (value) => language = value,
            onMutedChanged: (value) => muted = value,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Media'));
    await tester.tap(find.text('Veloce'));
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(tts.volume, VoiceVolume.medium);
    expect(tts.speed, VoiceSpeed.fast);
    expect(language, 'en');

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tts.muted, isTrue);
    expect(muted, isTrue);
  });
}
