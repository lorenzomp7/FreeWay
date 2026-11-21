import 'compass_stub.dart'
    if (dart.library.js_interop) 'compass_web.dart'
    as impl;

/// Bussola del telefono, per il cono della direzione e la mappa orientata
/// dove si guarda, come in Google Maps. Nel browser usa l'orientamento del
/// dispositivo: su Android `deviceorientationabsolute`, su iPhone
/// `webkitCompassHeading`, che chiede prima il permesso.
class Compass {
  /// Il browser può dare l'orientamento (non vuol dire che il dispositivo
  /// abbia una bussola: lo si sa alla prima lettura).
  bool get isSupported => impl.isSupported();

  /// Su iPhone bisogna chiedere il permesso, da un tocco della persona.
  /// `false` solo se la persona (o il browser) l'ha negato.
  Future<bool> requestPermission() => impl.requestPermission();

  /// Direzione in gradi dal nord, in senso orario, già corretta per lo
  /// schermo girato in orizzontale.
  Stream<double> get headings => impl.headings();
}
