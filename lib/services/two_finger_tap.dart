import 'dart:ui';

/// Riconosce il tocco con due dita (appoggiate e sollevate insieme, senza
/// spostarle), che su Google Maps allontana la mappa di un livello.
///
/// Riceve gli eventi dei soli tocchi sullo schermo (non mouse né touchpad) e
/// restituisce il punto medio delle due dita quando il gesto è completo.
class TwoFingerTapDetector {
  TwoFingerTapDetector({
    this.maxDuration = const Duration(milliseconds: 300),
    this.maxMovement = 18,
  });

  /// Tempo massimo tra il primo dito appoggiato e l'ultimo sollevato.
  final Duration maxDuration;

  /// Spostamento massimo di ciascun dito, in pixel logici.
  final double maxMovement;

  final Map<int, Offset> _start = {};
  final Map<int, Offset> _last = {};
  Duration? _firstDown;
  bool _valid = false;
  int _released = 0;

  /// Un dito si appoggia.
  void down(int pointer, Offset position, Duration time) {
    if (_start.isEmpty) {
      _firstDown = time;
      _valid = true;
      _released = 0;
    }
    if (_start.length >= 2 || _released > 0) _valid = false;
    _start[pointer] = position;
    _last[pointer] = position;
  }

  /// Un dito si sposta.
  void move(int pointer, Offset position) {
    final start = _start[pointer];
    if (start == null) return;
    _last[pointer] = position;
    if ((position - start).distance > maxMovement) _valid = false;
  }

  /// Un dito si solleva. Restituisce il punto medio se con questo si chiude
  /// un tocco con due dita.
  Offset? up(int pointer, Duration time) {
    if (!_start.containsKey(pointer)) return null;
    _released++;
    if (_released < 2 || _start.length != 2) {
      if (_released >= _start.length) _reset();
      return null;
    }
    final first = _firstDown;
    final ok = _valid && first != null && time - first <= maxDuration;
    final points = _last.values.toList();
    _reset();
    if (!ok) return null;
    return Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
  }

  /// Gesto interrotto (per esempio dal sistema).
  void cancel(int pointer) => _reset();

  void _reset() {
    _start.clear();
    _last.clear();
    _firstDown = null;
    _valid = false;
    _released = 0;
  }
}
