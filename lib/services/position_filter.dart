import 'package:latlong2/latlong.dart';

import 'geo_utils.dart';

/// Una posizione con la sua incertezza e l'ora in cui è stata rilevata.
class PositionFix {
  const PositionFix(this.position, this.accuracy, this.time);

  final LatLng position;

  /// Raggio di incertezza in metri (0 se non noto).
  final double accuracy;
  final DateTime time;
}

/// Sceglie quali posizioni usare, scartando quelle che peggiorano le cose.
///
/// Una nuova posizione si accetta solo se è più recente dell'ultima. Finché
/// l'ultima è fresca (meno di [staleAfter]) si scarta anche una posizione:
/// - molto meno precisa, per esempio una stima dalla rete che arriva dopo
///   un buon fix GPS;
/// - troppo lontana per essere raggiunta in quel tempo a [maxSpeed] metri
///   al secondo, tenendo conto dell'incertezza di entrambe (i "salti" del
///   GPS tra i palazzi).
///
/// Se si scartano [maxRejects] posizioni di fila, la successiva si accetta
/// comunque: forse ci si è davvero spostati, o il segnale è peggiorato per
/// restare.
class PositionFilter {
  PositionFilter({
    this.staleAfter = const Duration(seconds: 15),
    this.maxSpeed = 8,
    this.maxRejects = 3,
  });

  final Duration staleAfter;

  /// Velocità massima credibile in metri al secondo (circa 29 km/h: anche
  /// in sedia a rotelle elettrica o su un mezzo pubblico lento).
  final double maxSpeed;
  final int maxRejects;

  PositionFix? _last;
  int _rejects = 0;

  PositionFix? get last => _last;

  /// Prende [fix] come ultima posizione senza controllarla, per esempio
  /// perché un altro filtro l'ha già accettata.
  void remember(PositionFix fix) {
    _last = fix;
    _rejects = 0;
  }

  void reset() {
    _last = null;
    _rejects = 0;
  }

  /// `true` se [fix] va usata; in quel caso diventa l'ultima posizione.
  bool accept(PositionFix fix) {
    final last = _last;
    if (last != null && !fix.time.isAfter(last.time)) return false;
    if (last != null &&
        fix.time.difference(last.time) < staleAfter &&
        _rejects < maxRejects &&
        (_muchWorse(fix, last) || _impossibleJump(fix, last))) {
      _rejects++;
      return false;
    }
    _last = fix;
    _rejects = 0;
    return true;
  }

  static bool _muchWorse(PositionFix fix, PositionFix last) {
    if (fix.accuracy <= 0 || last.accuracy <= 0) return false;
    final limit = last.accuracy * 2 > last.accuracy + 20
        ? last.accuracy * 2
        : last.accuracy + 20;
    return fix.accuracy > limit;
  }

  bool _impossibleJump(PositionFix fix, PositionFix last) {
    final seconds = fix.time.difference(last.time).inMilliseconds / 1000;
    final distance = haversineDistance(fix.position, last.position);
    return distance > maxSpeed * seconds + fix.accuracy + last.accuracy;
  }
}
