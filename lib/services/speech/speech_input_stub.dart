import '../speech_input.dart';

/// Senza browser il riconoscimento vocale non c'è.
class PlatformSpeechInput implements SpeechInput {
  @override
  bool get isSupported => false;

  @override
  Future<List<String>> listen(String language) async => const [];

  @override
  void cancel() {}
}
