import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../speech_input.dart';

/// Web Speech API: `SpeechRecognition` (o `webkitSpeechRecognition` su
/// Chrome e Safari).
class PlatformSpeechInput implements SpeechInput {
  JSObject? _active;

  static JSFunction? get _constructor {
    final window = globalContext;
    final standard = window.getProperty<JSAny?>('SpeechRecognition'.toJS);
    if (standard != null && standard.isA<JSFunction>()) {
      return standard as JSFunction;
    }
    final webkit = window.getProperty<JSAny?>('webkitSpeechRecognition'.toJS);
    if (webkit != null && webkit.isA<JSFunction>()) return webkit as JSFunction;
    return null;
  }

  @override
  bool get isSupported => _constructor != null;

  @override
  Future<List<String>> listen(String language) {
    final constructor = _constructor;
    if (constructor == null) return Future.value(const []);
    cancel();
    final completer = Completer<List<String>>();
    void finish(List<String> result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    try {
      final recognition = constructor.callAsConstructor<JSObject>();
      _active = recognition;
      recognition
        ..setProperty('lang'.toJS, (language == 'it' ? 'it-IT' : 'en-US').toJS)
        ..setProperty('interimResults'.toJS, false.toJS)
        ..setProperty('continuous'.toJS, false.toJS)
        ..setProperty('maxAlternatives'.toJS, 3.toJS)
        ..setProperty(
          'onresult'.toJS,
          ((JSObject event) {
            final texts = <String>[];
            final results = event.getProperty<JSObject>('results'.toJS);
            final first = results.getProperty<JSObject?>(0.toJS);
            if (first != null) {
              final count = first
                  .getProperty<JSNumber>('length'.toJS)
                  .toDartInt;
              for (var i = 0; i < count; i++) {
                final alternative = first.getProperty<JSObject>(i.toJS);
                final text = alternative
                    .getProperty<JSString>('transcript'.toJS)
                    .toDart
                    .trim();
                if (text.isNotEmpty) texts.add(text);
              }
            }
            finish(texts);
          }).toJS,
        )
        ..setProperty('onerror'.toJS, ((JSObject _) => finish(const [])).toJS)
        ..setProperty('onend'.toJS, ((JSObject _) => finish(const [])).toJS);
      recognition.callMethod<JSAny?>('start'.toJS);
    } catch (_) {
      finish(const []);
    }
    // Se il browser non risponde, dopo 12 secondi si rinuncia.
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        cancel();
        return const [];
      },
    );
  }

  @override
  void cancel() {
    final active = _active;
    _active = null;
    if (active == null) return;
    try {
      active.callMethod<JSAny?>('abort'.toJS);
    } catch (_) {}
  }
}
