import 'package:latlong2/latlong.dart';

/// Risposta alla domanda "Com'era l'ingresso?" fatta all'arrivo.
enum EntranceAnswer {
  accessible('accessibile', 'Accessibile'),
  steps('gradini', 'Con gradini'),
  notFound('non_trovato', 'Non l\'ho trovato');

  const EntranceAnswer(this.value, this.label);

  /// Valore salvato su Firestore (vedi firestore.rules).
  final String value;

  /// Testo del pulsante.
  final String label;

  static EntranceAnswer? fromValue(Object? value) {
    for (final answer in values) {
      if (answer.value == value) return answer;
    }
    return null;
  }
}

/// Una risposta di chi è arrivato a una destinazione.
class EntranceReport {
  const EntranceReport({
    required this.position,
    required this.answer,
    this.reportedAt,
  });

  final LatLng position;
  final EntranceAnswer answer;
  final DateTime? reportedAt;
}

/// Quante persone hanno dato ciascuna risposta vicino a un luogo.
class EntranceSummary {
  const EntranceSummary({
    this.accessible = 0,
    this.steps = 0,
    this.notFound = 0,
  });

  /// Conta le risposte di [reports].
  factory EntranceSummary.of(Iterable<EntranceReport> reports) {
    var accessible = 0, steps = 0, notFound = 0;
    for (final report in reports) {
      switch (report.answer) {
        case EntranceAnswer.accessible:
          accessible++;
        case EntranceAnswer.steps:
          steps++;
        case EntranceAnswer.notFound:
          notFound++;
      }
    }
    return EntranceSummary(
      accessible: accessible,
      steps: steps,
      notFound: notFound,
    );
  }

  final int accessible;
  final int steps;
  final int notFound;

  int get total => accessible + steps + notFound;
  bool get isEmpty => total == 0;

  static String _people(int n) => n == 1 ? '1 persona' : '$n persone';

  /// Riga per la scheda del luogo, per esempio "Ingresso secondo chi è
  /// arrivato qui: accessibile per 3 persone, con gradini per 1".
  String get label {
    final parts = [
      if (accessible > 0) 'accessibile per ${_people(accessible)}',
      if (steps > 0) 'con gradini per ${_people(steps)}',
      if (notFound > 0) 'non trovato da ${_people(notFound)}',
    ];
    return 'Ingresso secondo chi è arrivato qui: ${parts.join(', ')}';
  }
}
