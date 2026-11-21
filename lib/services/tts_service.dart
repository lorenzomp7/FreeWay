import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Volume della voce, come "Louder / Normal / Softer" di Google Maps.
enum VoiceVolume {
  low('Bassa', 0.4),
  medium('Media', 0.7),
  high('Alta', 1);

  const VoiceVolume(this.label, this.value);

  final String label;
  final double value;
}

/// Velocità della voce. Sul web il browser usa 1 come velocità normale,
/// sui telefoni il motore vocale usa 0,5.
enum VoiceSpeed {
  slow('Lenta', 0.65, 0.38),
  normal('Normale', 0.9, 0.5),
  fast('Veloce', 1.15, 0.6);

  const VoiceSpeed(this.label, this.webRate, this.mobileRate);

  final String label;
  final double webRate;
  final double mobileRate;

  double get rate => kIsWeb ? webRate : mobileRate;
}

/// Quanto parla la voce durante la navigazione.
enum VoiceGuidanceMode {
  /// Tutti gli annunci: "Prosegui per…", "Tra 100 metri…" e la manovra.
  full('Completa'),

  /// Solo la manovra quando è il momento, l'arrivo e gli avvisi.
  brief('Breve');

  const VoiceGuidanceMode(this.label);

  final String label;
}

/// Istruzioni vocali durante la navigazione.
class TtsService {
  TtsService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final FlutterTts _tts = FlutterTts();
  final Future<SharedPreferences> Function() _preferences;
  bool muted = false;
  VoiceVolume volume = VoiceVolume.high;
  VoiceSpeed speed = VoiceSpeed.normal;
  VoiceGuidanceMode guidance = VoiceGuidanceMode.full;
  String? _lastSpoken;
  String _lastLanguage = 'it';

  static const String _volumeKey = 'freeway.voice_volume';
  static const String _speedKey = 'freeway.voice_speed';
  static const String _guidanceKey = 'freeway.voice_guidance';

  /// Legge volume e velocità scelti l'ultima volta.
  Future<void> loadSettings() async {
    try {
      final prefs = await _preferences();
      volume = VoiceVolume.values.firstWhere(
        (v) => v.name == prefs.getString(_volumeKey),
        orElse: () => VoiceVolume.high,
      );
      speed = VoiceSpeed.values.firstWhere(
        (v) => v.name == prefs.getString(_speedKey),
        orElse: () => VoiceSpeed.normal,
      );
      guidance = VoiceGuidanceMode.values.firstWhere(
        (v) => v.name == prefs.getString(_guidanceKey),
        orElse: () => VoiceGuidanceMode.full,
      );
    } catch (_) {
      // Senza archivio restano i valori predefiniti.
    }
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await _preferences();
      await prefs.setString(_volumeKey, volume.name);
      await prefs.setString(_speedKey, speed.name);
      await prefs.setString(_guidanceKey, guidance.name);
    } catch (_) {
      // Le impostazioni valgono comunque fino alla chiusura.
    }
  }

  Future<void> speak(String text, String language) async {
    if (muted || text.isEmpty || text == _lastSpoken) return;
    _lastSpoken = text;
    _lastLanguage = language;
    await _say(text, language);
  }

  /// Ripete l'ultima istruzione, anche se è appena stata detta.
  Future<void> repeat() async {
    final text = _lastSpoken;
    if (muted || text == null) return;
    await _say(text, _lastLanguage);
  }

  /// Frase di prova per le impostazioni della voce.
  Future<void> test(String language) => _say(
    language == 'it'
        ? 'Tra cento metri, svolta a destra'
        : 'In one hundred meters, turn right',
    language,
  );

  Future<void> _say(String text, String language) async {
    try {
      await _tts.setLanguage(language == 'it' ? 'it-IT' : 'en-US');
      await _tts.setSpeechRate(speed.rate);
      await _tts.setVolume(volume.value);
      await _tts.setPitch(1);
      await _tts.speak(text);
    } catch (_) {
      // La sintesi vocale non è disponibile su tutti i browser.
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  void reset() => _lastSpoken = null;
}
