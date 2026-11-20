import 'connectivity_stub.dart'
    if (dart.library.js_interop) 'connectivity_web.dart'
    as impl;

/// Se il dispositivo ha la rete, come la segnala il browser
/// (`navigator.onLine` e gli eventi `online`/`offline`). Fuori dal web si
/// considera sempre in linea.
class Connectivity {
  bool get isOnline => impl.isOnline();

  /// `true` quando torna la rete, `false` quando cade.
  Stream<bool> get changes => impl.changes();
}
