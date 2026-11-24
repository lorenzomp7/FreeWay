import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Un'inquadratura della mappa: centro e livello di zoom.
class CameraStep {
  const CameraStep(this.center, this.zoom);

  final LatLng center;
  final double zoom;

  @override
  String toString() => 'CameraStep($center, $zoom)';
}

/// Quante volte il lato maggiore dello schermo si può attraversare con
/// un'animazione. Oltre, la mappa salta direttamente: l'animazione
/// scaricherebbe le tile di tutta la strada e sembrerebbe lenta.
const double maxAnimatedScreens = 2.5;

/// Lato di una tile in pixel logici, come in flutter_map.
const double _tileSize = 256;

/// Coordinate del mondo nella proiezione di Mercatore (0..1 su entrambi gli
/// assi), la stessa delle tile: interpolando qui il centro si muove in linea
/// retta sullo schermo.
({double x, double y}) _project(LatLng point) {
  final lat = point.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
  final x = (point.longitude + 180) / 360;
  final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2;
  return (x: x, y: y);
}

LatLng _unproject(({double x, double y}) point) {
  final n = math.pi * (1 - 2 * point.y);
  final lat = math.atan((math.exp(n) - math.exp(-n)) / 2) * 180 / math.pi;
  return LatLng(lat, point.x * 360 - 180);
}

/// Inquadratura a metà strada tra [from] e [to]: [t] va da 0 (partenza) a
/// 1 (arrivo) ed è già passato per la curva dell'animazione.
///
/// Lo zoom cambia in modo lineare, cioè con la stessa velocità percepita a
/// ogni livello; il centro si sposta in linea retta sullo schermo.
CameraStep interpolateCamera(CameraStep from, CameraStep to, double t) {
  if (t <= 0) return from;
  if (t >= 1) return to;
  final a = _project(from.center);
  final b = _project(to.center);
  var dx = b.x - a.x;
  // Attraverso l'antimeridiano si passa dalla strada più corta.
  if (dx > 0.5) dx -= 1;
  if (dx < -0.5) dx += 1;
  var x = a.x + dx * t;
  if (x < 0) x += 1;
  if (x >= 1) x -= 1;
  final y = a.y + (b.y - a.y) * t;
  return CameraStep(
    _unproject((x: x, y: y)),
    from.zoom + (to.zoom - from.zoom) * t,
  );
}

/// Vero se conviene animare il passaggio da [from] a [to] su uno schermo
/// grande [width] x [height] pixel logici: la meta non è già inquadrata
/// esattamente e la distanza, misurata allo zoom più lontano dei due, non
/// supera [maxAnimatedScreens] schermi.
bool shouldAnimateCamera(
  CameraStep from,
  CameraStep to,
  double width,
  double height,
) {
  final a = _project(from.center);
  final b = _project(to.center);
  var dx = (b.x - a.x).abs();
  if (dx > 0.5) dx = 1 - dx;
  final dy = (b.y - a.y).abs();
  final zoomChange = (to.zoom - from.zoom).abs();
  if (dx < 1e-12 && dy < 1e-12 && zoomChange < 1e-6) return false;
  final scale = _tileSize * math.pow(2, math.min(from.zoom, to.zoom));
  final pixels = math.sqrt(dx * dx + dy * dy) * scale;
  final screen = math.max(width, height);
  if (screen <= 0) return false;
  return pixels <= maxAnimatedScreens * screen;
}

/// Rotazione della mappa a metà strada tra [from] e [to] (gradi), girando
/// dalla parte più corta: da 350° a 10° passa per 0°, non per 180°.
double interpolateRotation(double from, double to, double t) {
  if (t <= 0) return from;
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (t >= 1) return from + delta;
  return from + delta * t;
}

/// Vero se la mappa, ruotata di [rotation] gradi, non ha il nord in alto
/// (con una tolleranza di mezzo grado).
bool isRotated(double rotation) {
  final r = rotation % 360;
  return r > 0.5 && r < 359.5;
}

/// Zoom dopo un pizzico sul touchpad o Ctrl + rotellina: il browser manda un
/// fattore di scala (2 = il doppio) e un livello di zoom in più lo raddoppia.
double zoomAfterScale(
  double zoom,
  double scale,
  double minZoom,
  double maxZoom,
) {
  if (!scale.isFinite || scale <= 0) return zoom;
  final next = zoom + math.log(scale) / math.ln2;
  return next.clamp(minZoom, maxZoom).toDouble();
}
