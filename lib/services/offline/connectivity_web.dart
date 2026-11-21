import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool isOnline() => web.window.navigator.onLine;

Stream<bool> changes() {
  late final StreamController<bool> controller;
  final online = ((web.Event _) => controller.add(true)).toJS;
  final offline = ((web.Event _) => controller.add(false)).toJS;
  controller = StreamController<bool>.broadcast(
    onListen: () {
      web.window.addEventListener('online', online);
      web.window.addEventListener('offline', offline);
    },
    onCancel: () {
      web.window.removeEventListener('online', online);
      web.window.removeEventListener('offline', offline);
    },
  );
  return controller.stream;
}
