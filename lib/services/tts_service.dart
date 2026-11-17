import 'package:flutter_tts/flutter_tts.dart';

/// Istruzioni vocali durante la navigazione.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool muted = false;
  String? _lastSpoken;

  Future<void> speak(String text, String language) async {
    if (muted || text.isEmpty || text == _lastSpoken) return;
    try {
      _lastSpoken = text;
      await _tts.setLanguage(language == 'it' ? 'it-IT' : 'en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1);
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
