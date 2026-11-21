import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

bool _has(String name) => web.window.has(name);

bool isSupported() => _has('DeviceOrientationEvent');

Future<bool> requestPermission() async {
  if (!isSupported()) return false;
  final constructor = web.window.getProperty<JSObject>(
    'DeviceOrientationEvent'.toJS,
  );
  // Solo Safari su iPhone e iPad ha bisogno del permesso.
  if (!constructor.has('requestPermission')) return true;
  try {
    final result = await constructor
        .callMethod<JSPromise<JSString>>('requestPermission'.toJS)
        .toDart;
    // "prompt" (Chrome senza un tocco recente) non è un rifiuto: le
    // letture arriveranno, o il browser chiederà.
    return result.toDart != 'denied';
  } catch (_) {
    return false;
  }
}

/// L'angolo dello schermo (0, 90, 180, 270) quando il telefono è girato.
double _screenAngle() {
  try {
    return web.window.screen.orientation.angle.toDouble();
  } catch (_) {
    return 0;
  }
}

Stream<double> headings() {
  late final StreamController<double> controller;
  // Con la versione "absolute" (Chrome su Android) alpha è rispetto al nord;
  // con quella normale lo è solo su Safari, tramite webkitCompassHeading.
  final absoluteEvent = _has('ondeviceorientationabsolute');
  final type = absoluteEvent
      ? 'deviceorientationabsolute'
      : 'deviceorientation';

  void onEvent(web.Event event) {
    final e = event as web.DeviceOrientationEvent;
    final object = e as JSObject;
    double? heading;
    final webkit = object.getProperty<JSAny?>('webkitCompassHeading'.toJS);
    if (webkit != null && webkit.isA<JSNumber>()) {
      heading = (webkit as JSNumber).toDartDouble;
    } else if ((absoluteEvent || e.absolute) && e.alpha != null) {
      heading = 360 - e.alpha!;
    }
    if (heading == null || heading.isNaN) return;
    controller.add((heading + _screenAngle()) % 360);
  }

  final listener = onEvent.toJS;
  controller = StreamController<double>.broadcast(
    onListen: () => web.window.addEventListener(type, listener),
    onCancel: () => web.window.removeEventListener(type, listener),
  );
  return controller.stream;
}
