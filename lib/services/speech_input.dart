import 'speech/speech_input_stub.dart'
    if (dart.library.js_interop) 'speech/speech_input_web.dart'
    as impl;

/// Riconoscimento vocale del browser (Web Speech API), per segnalare un
/// ostacolo dicendone il tipo. Dove non c'è (Firefox, test) non è
/// disponibile e il pulsante non compare.
abstract class SpeechInput {
  factory SpeechInput() = impl.PlatformSpeechInput;

  bool get isSupported;

  /// Ascolta una frase in [language] ('it' o 'en') e restituisce le
  /// trascrizioni possibili, dalla più probabile; vuota se non ha capito o
  /// se il microfono non è consentito.
  Future<List<String>> listen(String language);

  void cancel();
}
