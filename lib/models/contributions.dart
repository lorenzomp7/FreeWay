import 'package:flutter/material.dart';

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

// --- Ringraziamenti, badge e riepilogo settimanale --------------------------

/// Foto e aiuti, ricavati da [Contributions] come gli altri conteggi.
extension ContributionExtras on Contributions {
  /// Segnalazioni con la foto.
  int get photos => reports.where((o) => o.hasPhoto).length;

  /// Conferme e risposte "si passa?" date alle segnalazioni degli altri.
  int get helpsGiven => confirmationsGiven + passVotesGiven;

  List<ContributionBadge> get earnedBadges =>
      contributionBadges.where((b) => b.isEarned(this)).toList();

  /// Il badge non ancora ottenuto più vicino, come "Your next badge is
  /// close!" di Google Maps; `null` se sono stati presi tutti.
  ContributionBadge? get nextBadge {
    ContributionBadge? best;
    for (final badge in contributionBadges) {
      if (badge.isEarned(this)) continue;
      if (best == null || badge.ratio(this) > best.ratio(this)) best = badge;
    }
    return best;
  }
}

/// Un badge con la soglia da raggiungere. Come i livelli, non dà premi:
/// fa vedere a chi contribuisce che il suo aiuto conta.
class ContributionBadge {
  const ContributionBadge({
    required this.id,
    required this.title,
    required this.task,
    required this.icon,
    required this.color,
    required this.target,
    required this.progressOf,
  });

  final String id;
  final String title;

  /// Cosa fare per ottenerlo ("Segnala 10 ostacoli").
  final String task;
  final IconData icon;
  final Color color;
  final int target;
  final int Function(Contributions c) progressOf;

  /// Avanzamento, al massimo [target].
  int progress(Contributions c) => progressOf(c).clamp(0, target);

  bool isEarned(Contributions c) => progressOf(c) >= target;

  double ratio(Contributions c) => progress(c) / target;
}

final List<ContributionBadge> contributionBadges = [
  ContributionBadge(
    id: 'first-report',
    title: 'Primo passo',
    task: 'Segnala il tuo primo ostacolo',
    icon: Icons.flag_rounded,
    color: const Color(0xFFEC0414),
    target: 1,
    progressOf: (c) => c.reports.length,
  ),
  ContributionBadge(
    id: 'verifier',
    title: 'Verificatore',
    task: 'Conferma o rispondi su 10 ostacoli segnalati da altri',
    icon: Icons.fact_check_rounded,
    color: const Color(0xFF0B7A4B),
    target: 10,
    progressOf: (c) => c.helpsGiven,
  ),
  ContributionBadge(
    id: 'photographer',
    title: 'Fotoreporter',
    task: 'Aggiungi la foto a 5 segnalazioni',
    icon: Icons.photo_camera_rounded,
    color: const Color(0xFF1F6FE0),
    target: 5,
    progressOf: (c) => c.photos,
  ),
  ContributionBadge(
    id: 'sentinel',
    title: 'Sentinella del quartiere',
    task: 'Segnala 10 ostacoli',
    icon: Icons.shield_rounded,
    color: const Color(0xFF7839EE),
    target: 10,
    progressOf: (c) => c.reports.length,
  ),
  ContributionBadge(
    id: 'helpful',
    title: 'Utile a tante persone',
    task: 'Fai confermare le tue segnalazioni 10 volte',
    icon: Icons.verified_rounded,
    color: const Color(0xFFB25E00),
    target: 10,
    progressOf: (c) => c.confirmationsReceived,
  ),
  ContributionBadge(
    id: 'thanked',
    title: 'Grazie di cuore',
    task: 'Ricevi 5 grazie per le tue segnalazioni',
    icon: Icons.favorite_rounded,
    color: const Color(0xFFC00310),
    target: 5,
    progressOf: (c) => c.thanksReceived,
  ),
];

/// Cosa è cambiato con un contributo, per ringraziare dicendo i punti.
class ContributionReward {
  const ContributionReward({
    required this.points,
    required this.levelReached,
    required this.newBadges,
    required this.after,
  });

  factory ContributionReward.between(
    Contributions before,
    Contributions after,
  ) {
    final earned = {for (final b in before.earnedBadges) b.id};
    return ContributionReward(
      points: after.points - before.points,
      levelReached: after.level.index > before.level.index ? after.level : null,
      newBadges: [
        for (final b in after.earnedBadges)
          if (!earned.contains(b.id)) b,
      ],
      after: after,
    );
  }

  /// Punti guadagnati.
  final int points;

  /// Il nuovo livello, se il contributo lo ha fatto salire.
  final ContributorLevel? levelReached;
  final List<ContributionBadge> newBadges;
  final Contributions after;

  /// Da festeggiare: nuovo livello o nuovo badge.
  bool get isMilestone => levelReached != null || newBadges.isNotEmpty;

  /// Da aggiungere al ringraziamento, come "You're 97 points from level 4";
  /// vuoto se il contributo non ha cambiato nulla.
  String get message {
    if (points <= 0 && newBadges.isEmpty) return '';
    final gained = points == 1
        ? '+1 punto. '
        : points > 1
        ? '+$points punti. '
        : '';
    final level = levelReached;
    if (newBadges.isNotEmpty) {
      return '${gained}Nuovo badge: «${newBadges.first.title}»!';
    }
    if (level != null) return '${gained}Ora sei al livello «${level.title}»!';
    final missing = after.pointsToNextLevel;
    final next = after.level.next;
    if (missing == null || next == null) return gained.trim();
    return '${gained}Ancora $missing punt${missing == 1 ? 'o' : 'i'} per '
        '«${next.title}».';
  }
}

/// Un aiuto dato alle segnalazioni degli altri, con l'ora. Firestore sa chi
/// ha confermato o risposto ma non quando: per "La tua settimana" l'ora si
/// tiene sul dispositivo.
enum HelpKind { confirm, pass, gone }

class HelpEntry {
  const HelpEntry(this.kind, this.obstacleId, this.at);

  final HelpKind kind;
  final String obstacleId;
  final DateTime at;

  String get key => '${kind.name}:$obstacleId';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': obstacleId,
    'at': at.millisecondsSinceEpoch,
  };

  static HelpEntry? fromJson(Object? data) {
    if (data is! Map) return null;
    final kind = HelpKind.values.where((k) => k.name == data['kind']);
    final id = data['id'];
    final at = data['at'];
    if (kind.isEmpty || id is! String || at is! int) return null;
    return HelpEntry(kind.first, id, DateTime.fromMillisecondsSinceEpoch(at));
  }
}

/// Un intervallo di giorni, [start] incluso e [end] escluso.
class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime? date) =>
      date != null && !date.isBefore(start) && date.isBefore(end);

  /// La settimana, da lunedì a domenica, che contiene [date].
  factory DateRange.weekOf(DateTime date) {
    final start = DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - DateTime.monday),
    );
    return DateRange(start, DateTime(start.year, start.month, start.day + 7));
  }

  /// La settimana prima di quella di [now].
  factory DateRange.previousWeek(DateTime now) {
    final start = DateRange.weekOf(now).start;
    return DateRange.weekOf(DateTime(start.year, start.month, start.day - 7));
  }

  /// Identificativo della settimana, per mostrarne il riepilogo una volta.
  String get id =>
      '${start.year}-${start.month.toString().padLeft(2, '0')}-'
      '${start.day.toString().padLeft(2, '0')}';

  /// "dal 9 al 15 novembre 2026".
  String get label {
    final last = DateTime(end.year, end.month, end.day - 1);
    final sameYear = start.year == last.year;
    final from = sameYear && start.month == last.month
        ? '${start.day}'
        : sameYear
        ? '${start.day} ${italianMonths[start.month - 1]}'
        : '${start.day} ${italianMonths[start.month - 1]} ${start.year}';
    return 'dal $from al ${last.day} ${italianMonths[last.month - 1]} '
        '${last.year}';
  }
}

const List<String> italianMonths = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

/// "Your week in review": cosa si è fatto in una settimana e a chi è
/// servito.
class WeeklyReview {
  const WeeklyReview({
    required this.range,
    required this.reports,
    required this.helps,
    required this.reportsConfirmed,
  });

  factory WeeklyReview.of(
    Contributions contributions,
    List<HelpEntry> helps,
    DateRange range,
    String userId,
  ) {
    return WeeklyReview(
      range: range,
      reports: [
        for (final o in contributions.reports)
          if (range.contains(o.reportedAt)) o,
      ],
      helps: [
        for (final h in helps)
          if (range.contains(h.at)) h,
      ],
      // Di una conferma ricevuta si sa solo l'ora dell'ultima.
      reportsConfirmed: contributions.reports
          .where(
            (o) =>
                range.contains(o.lastConfirmedAt) &&
                o.confirmedBy.any((uid) => uid != userId),
          )
          .length,
    );
  }

  final DateRange range;

  /// Le proprie segnalazioni della settimana, dalla più recente.
  final List<Obstacle> reports;
  final List<HelpEntry> helps;

  /// Proprie segnalazioni confermate da altri durante la settimana.
  final int reportsConfirmed;

  int get photos => reports.where((o) => o.hasPhoto).length;

  int count(HelpKind kind) => helps.where((h) => h.kind == kind).length;

  int get total => reports.length + helps.length;

  bool get isEmpty => total == 0;
}

/// Un ostacolo vicino, segnalato da altri, che nessuno conferma da tempo:
/// come "Can you tell us more about the place?", invita a verificarlo.
class VerifySuggestion {
  const VerifySuggestion(this.obstacle, this.distance);

  final Obstacle obstacle;

  /// Metri da chi guarda.
  final double distance;
}

/// L'ostacolo più vicino a [location], entro [radius] metri, segnalato da
/// altri, non confermato da almeno [age] e non ancora verificato da
/// [userId]. [distanceOf] misura i metri tra due punti.
VerifySuggestion? findVerifySuggestion(
  Iterable<Obstacle> visible,
  String userId,
  DateTime now,
  double Function(Obstacle obstacle) distanceOf, {
  double radius = 1000,
  Duration age = const Duration(days: 30),
}) {
  VerifySuggestion? best;
  for (final o in visible) {
    if (!o.canBeConfirmedBy(userId) || o.notThereBy.contains(userId)) continue;
    final seen = o.lastSeenAt;
    if (seen != null && now.difference(seen) < age) continue;
    final distance = distanceOf(o);
    if (distance > radius) continue;
    if (best == null || distance < best.distance) {
      best = VerifySuggestion(o, distance);
    }
  }
  return best;
}
