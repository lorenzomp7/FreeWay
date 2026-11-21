import 'obstacle.dart';

/// Livello di chi contribuisce, come i livelli delle "Guide locali" di
/// Google Maps ma senza premi: serve solo a far vedere quanto si è aiutato.
enum ContributorLevel {
  newcomer('Nuovo arrivo', 0),
  explorer('Esploratore', 1),
  guide('Guida', 10),
  expert('Guida esperta', 30),
  ambassador('Ambasciatore dell\'accessibilità', 75);

  const ContributorLevel(this.title, this.minPoints);

  final String title;
  final int minPoints;

  static ContributorLevel forPoints(int points) =>
      values.lastWhere((level) => points >= level.minPoints);

  ContributorLevel? get next =>
      index + 1 < values.length ? values[index + 1] : null;
}

/// Stato di una propria segnalazione.
enum ReportStatus {
  visible('Visibile sulla mappa'),
  expired('Nascosta: nessuno la conferma da tempo'),
  dismissed('Nascosta: altre persone dicono che non c\'è più');

  const ReportStatus(this.label);

  final String label;

  static ReportStatus of(Obstacle obstacle, DateTime now) {
    if (obstacle.isDismissedByVotes) return dismissed;
    if (obstacle.isExpired(now)) return expired;
    return visible;
  }
}

/// "Le tue segnalazioni" e quanto hanno aiutato, come la pagina
/// "Contributi" di Google Maps. Si calcola dalle segnalazioni già lette,
/// senza altre richieste.
class Contributions {
  const Contributions({
    required this.reports,
    required this.confirmationsReceived,
    required this.thanksReceived,
    required this.passVotesReceived,
    required this.confirmationsGiven,
    required this.passVotesGiven,
    required this.thanksGiven,
  });

  /// Le segnalazioni fatte, dalla più recente (anche quelle nascoste).
  final List<Obstacle> reports;

  /// Conferme "c'è ancora" date da altri alle proprie segnalazioni.
  final int confirmationsReceived;
  final int thanksReceived;

  /// Risposte "si passa?" date da altri alle proprie segnalazioni.
  final int passVotesReceived;

  /// Aiuti dati alle segnalazioni degli altri.
  final int confirmationsGiven;
  final int passVotesGiven;
  final int thanksGiven;

  static Contributions of(Iterable<Obstacle> obstacles, String userId) {
    final mine = <Obstacle>[];
    var confirmationsReceived = 0;
    var thanksReceived = 0;
    var passReceived = 0;
    var confirmationsGiven = 0;
    var passGiven = 0;
    var thanksGiven = 0;
    for (final o in obstacles) {
      if (o.isReportedBy(userId)) {
        mine.add(o);
        confirmationsReceived += o.confirmedBy
            .where((uid) => uid != userId)
            .length;
        thanksReceived += o.thankedBy.length;
        passReceived += o.passVoteCount;
      } else {
        if (o.confirmedBy.contains(userId)) confirmationsGiven++;
        if (o.thankedBy.contains(userId)) thanksGiven++;
        if (o.passYesBy.contains(userId) ||
            o.passHardBy.contains(userId) ||
            o.passNoBy.contains(userId)) {
          passGiven++;
        }
      }
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    mine.sort(
      (a, b) => (b.reportedAt ?? epoch).compareTo(a.reportedAt ?? epoch),
    );
    return Contributions(
      reports: mine,
      confirmationsReceived: confirmationsReceived,
      thanksReceived: thanksReceived,
      passVotesReceived: passReceived,
      confirmationsGiven: confirmationsGiven,
      passVotesGiven: passGiven,
      thanksGiven: thanksGiven,
    );
  }

  bool get isEmpty =>
      reports.isEmpty &&
      confirmationsGiven == 0 &&
      passVotesGiven == 0 &&
      thanksGiven == 0;

  /// Una segnalazione vale 3 punti, una conferma o una risposta "si passa?"
  /// sulle segnalazioni degli altri 1 punto. I "grazie" non contano: sono
  /// un gesto gentile, non un dato.
  int get points => reports.length * 3 + confirmationsGiven + passVotesGiven;

  ContributorLevel get level => ContributorLevel.forPoints(points);

  /// Punti che mancano al livello dopo, o `null` all'ultimo livello.
  int? get pointsToNextLevel {
    final next = level.next;
    return next == null ? null : next.minPoints - points;
  }

  /// Avanzamento verso il livello dopo, tra 0 e 1.
  double get levelProgress {
    final next = level.next;
    if (next == null) return 1;
    final span = next.minPoints - level.minPoints;
    return ((points - level.minPoints) / span).clamp(0.0, 1.0);
  }

  /// Segnalazioni ancora visibili sulla mappa.
  int visibleReports(DateTime now) => reports
      .where((o) => ReportStatus.of(o, now) == ReportStatus.visible)
      .length;
}
