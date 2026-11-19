import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Tipologie di ostacolo selezionabili, raggruppate per categoria.
const Map<String, List<String>> obstacleTypesByCategory = {
  'Dislivello e pavimentazione': [
    'Mancanza di rampa/ascensore',
    'Gradino che rende impossibile il passaggio',
    'Tratto di strada troppo ripido',
    'Buche o pavimentazione accidentata',
    'Tratto con sassi/ghiaia',
  ],
  'Ingresso e passaggio': [
    'Porte strette o con apertura difficile',
    'Tornelli non accessibili',
    'Palo o colonna lungo la via pedonale',
  ],
  'Sicurezza': [
    'Incrocio o passaggio con scarsa visibilità',
    'Mancanza di segnaletica adeguata',
  ],
  'Ostacoli temporanei': [
    'Auto parcheggiata su scivolo o marciapiede',
    'Cantieri con percorsi accessibili bloccati',
    'Rifiuti o ingombri che ostruiscono il passaggio',
  ],
};

/// Icone dei gruppi nella scheda di segnalazione.
const Map<String, IconData> obstacleCategoryIcons = {
  'Dislivello e pavimentazione': Icons.stairs_rounded,
  'Ingresso e passaggio': Icons.meeting_room_outlined,
  'Sicurezza': Icons.shield_outlined,
  'Ostacoli temporanei': Icons.construction_rounded,
};

/// Categoria di un tipo di ostacolo: quella della lista
/// [obstacleTypesByCategory] o, per i testi delle versioni precedenti, quella
/// ricavata da parole chiave.
String obstacleCategoryOf(String type) {
  for (final entry in obstacleTypesByCategory.entries) {
    if (entry.value.contains(type)) return entry.key;
  }
  bool has(String text) => type.contains(text);
  if (has('rampa') ||
      has('ascensore') ||
      has('Gradino') ||
      has('ripido') ||
      has('Buche') ||
      has('pavimentazione') ||
      has('sassi') ||
      has('ghiaia')) {
    return 'Dislivello e pavimentazione';
  }
  if (has('Porte') || has('Tornelli') || has('Palo') || has('colonna')) {
    return 'Ingresso e passaggio';
  }
  if (has('visibilità') || has('segnaletica')) return 'Sicurezza';
  if (has('Auto') ||
      has('parcheggiata') ||
      has('Cantieri') ||
      has('Rifiuti') ||
      has('ingombri')) {
    return 'Ostacoli temporanei';
  }
  return 'Altro';
}

/// Risposta a "Si riesce a passare in sedia a rotelle?" su un ostacolo.
enum PassVote {
  yes('passYesBy', 'Sì'),
  hard('passHardBy', 'A fatica'),
  no('passNoBy', 'No');

  const PassVote(this.field, this.label);

  /// Campo di Firestore con gli uid di chi ha dato questa risposta.
  final String field;
  final String label;
}

/// Segnalazione di un ostacolo salvata su Firestore (collezione `segnalazioni`).
class Obstacle {
  Obstacle({
    required this.id,
    required this.position,
    required this.type,
    this.reportedAt,
    this.userId,
    String? category,
    this.confirmedBy = const [],
    this.lastConfirmedAt,
    this.notThereBy = const [],
    this.lastNotThereAt,
    this.hasPhoto = false,
    this.passYesBy = const [],
    this.passHardBy = const [],
    this.passNoBy = const [],
    this.thankedBy = const [],
  }) : _storedCategory = category;

  final String id;
  final LatLng position;
  final String type;
  final DateTime? reportedAt;

  /// Chi ha fatto la segnalazione (assente nelle segnalazioni più vecchie).
  final String? userId;

  /// Utenti che hanno confermato che l'ostacolo è ancora presente.
  final List<String> confirmedBy;
  final DateTime? lastConfirmedAt;

  /// Chi ha detto "non c'è più" senza poterlo rimuovere (gli ospiti).
  final List<String> notThereBy;
  final DateTime? lastNotThereAt;

  /// C'è una foto in `foto/{id}`, da caricare solo aprendo la scheda.
  final bool hasPhoto;

  /// Chi ha detto che in sedia a rotelle si passa, a fatica o no.
  final List<String> passYesBy;
  final List<String> passHardBy;
  final List<String> passNoBy;

  /// Chi ha ringraziato l'autore della segnalazione.
  final List<String> thankedBy;

  final String? _storedCategory;

  factory Obstacle.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Obstacle.fromMap(doc.id, doc.data());
  }

  factory Obstacle.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    final confirmed = data['lastConfirmedAt'];
    final notThere = data['lastNotThereAt'];
    return Obstacle(
      id: id,
      position: LatLng(
        (data['lat'] as num).toDouble(),
        (data['lng'] as num).toDouble(),
      ),
      type: data['type'] as String,
      reportedAt: timestamp is Timestamp ? timestamp.toDate() : null,
      userId: data['userId'] as String?,
      category: data['category'] as String?,
      confirmedBy:
          (data['confirmedBy'] as List?)?.whereType<String>().toList() ??
          const [],
      lastConfirmedAt: confirmed is Timestamp ? confirmed.toDate() : null,
      notThereBy:
          (data['notThereBy'] as List?)?.whereType<String>().toList() ??
          const [],
      lastNotThereAt: notThere is Timestamp ? notThere.toDate() : null,
      hasPhoto: data['hasPhoto'] == true,
      passYesBy: _uids(data[PassVote.yes.field]),
      passHardBy: _uids(data[PassVote.hard.field]),
      passNoBy: _uids(data[PassVote.no.field]),
      thankedBy: _uids(data['thankedBy']),
    );
  }

  static List<String> _uids(Object? value) =>
      (value as List?)?.whereType<String>().toList() ?? const [];

  /// [uid] può ringraziare chi ha segnalato: una volta, e solo se la
  /// segnalazione è di qualcun altro e se ne conosce l'autore.
  bool canBeThankedBy(String? uid) =>
      uid != null &&
      userId != null &&
      !isReportedBy(uid) &&
      !thankedBy.contains(uid);

  int get passVoteCount =>
      passYesBy.length + passHardBy.length + passNoBy.length;

  /// [uid] può dire se si passa: una volta sola e non sulla propria
  /// segnalazione.
  bool canVotePassBy(String? uid) =>
      uid != null &&
      !isReportedBy(uid) &&
      !passYesBy.contains(uid) &&
      !passHardBy.contains(uid) &&
      !passNoBy.contains(uid);

  /// Almeno due persone dicono che in sedia a rotelle si passa, e sono più
  /// di quelle che dicono "a fatica" o "no": i percorsi in sedia a rotelle
  /// non lo evitano più.
  bool get isWheelchairPassable =>
      passYesBy.length >= 2 &&
      passYesBy.length > passHardBy.length + passNoBy.length;

  /// Per esempio "In sedia a rotelle: si passa per 2 persone, no per 1".
  String? get passLabel {
    if (passVoteCount == 0) return null;
    String people(int n) => n == 1 ? '1 persona' : '$n persone';
    final parts = [
      if (passYesBy.isNotEmpty) 'si passa per ${people(passYesBy.length)}',
      if (passHardBy.isNotEmpty) 'a fatica per ${people(passHardBy.length)}',
      if (passNoBy.isNotEmpty) 'non si passa per ${people(passNoBy.length)}',
    ];
    return 'In sedia a rotelle: ${parts.join(', ')}';
  }

  int get confirmationCount => confirmedBy.length;

  /// Dopo quanto tempo senza conferme un ostacolo temporaneo sparisce.
  static const Duration temporaryLifetime = Duration(days: 14);

  /// Auto in sosta, cantieri e ingombri: ostacoli destinati a sparire.
  bool get isTemporary => category == 'Ostacoli temporanei';

  /// Ultima volta che qualcuno ha segnalato o confermato l'ostacolo.
  DateTime? get lastSeenAt {
    final reported = reportedAt;
    final confirmed = lastConfirmedAt;
    if (reported == null) return confirmed;
    if (confirmed == null) return reported;
    return confirmed.isAfter(reported) ? confirmed : reported;
  }

  /// Quando un ostacolo temporaneo smette di essere mostrato, se nessuno
  /// conferma che c'è ancora. `null` per gli ostacoli permanenti.
  DateTime? get expiresAt {
    final seen = lastSeenAt;
    if (!isTemporary || seen == null) return null;
    return seen.add(temporaryLifetime);
  }

  bool isExpired([DateTime? now]) {
    final expiry = expiresAt;
    return expiry != null && (now ?? DateTime.now()).isAfter(expiry);
  }

  /// Voti "non c'è più" che bastano a togliere l'ostacolo dalla mappa.
  static const int notThereVotesToHide = 2;

  /// Almeno due persone hanno detto che non c'è più, e dopo di loro nessuno
  /// ha confermato che c'è ancora (come i voti "Still there / Not there" di
  /// Google Maps).
  bool get isDismissedByVotes {
    if (notThereBy.length < notThereVotesToHide) return false;
    final confirmed = lastConfirmedAt;
    final voted = lastNotThereAt;
    return confirmed == null || (voted != null && voted.isAfter(confirmed));
  }

  /// Da non mostrare né usare nei percorsi: scaduto o tolto dai voti.
  bool isHidden([DateTime? now]) => isExpired(now) || isDismissedByVotes;

  /// [uid] può votare che l'ostacolo non c'è più.
  bool canVoteNotThereBy(String? uid) =>
      uid != null && !isReportedBy(uid) && !notThereBy.contains(uid);

  /// La segnalazione è stata fatta da [uid].
  bool isReportedBy(String? uid) => uid != null && userId == uid;

  /// [uid] può confermare che l'ostacolo c'è ancora.
  bool canBeConfirmedBy(String? uid) =>
      uid != null && !isReportedBy(uid) && !confirmedBy.contains(uid);

  bool _has(String text) => type.contains(text);

  IconData get icon {
    if (_has('rampa') || _has('ascensore')) return Icons.elevator_outlined;
    if (_has('Gradino')) return Icons.stairs_rounded;
    if (_has('ripido')) return Icons.trending_up_rounded;
    if (_has('Buche') || _has('pavimentazione')) return Icons.texture_rounded;
    if (_has('sassi') || _has('ghiaia')) return Icons.grain_rounded;
    if (_has('Porte')) return Icons.sensor_door_outlined;
    if (_has('Tornelli')) return Icons.block_rounded;
    if (_has('Palo') || _has('colonna')) return Icons.height_rounded;
    if (_has('visibilità')) return Icons.visibility_off_rounded;
    if (_has('segnaletica')) return Icons.signpost_rounded;
    if (_has('Auto') || _has('parcheggiata')) {
      return Icons.directions_car_rounded;
    }
    if (_has('Cantieri')) return Icons.construction_rounded;
    if (_has('Rifiuti') || _has('ingombri')) {
      return Icons.delete_outline_rounded;
    }
    return Icons.warning_amber_rounded;
  }

  Color get color {
    if (_has('rampa') ||
        _has('ascensore') ||
        _has('Gradino') ||
        _has('ripido')) {
      return const Color(0xFFD92D20);
    }
    if (_has('Buche') ||
        _has('pavimentazione') ||
        _has('sassi') ||
        _has('ghiaia')) {
      return const Color(0xFFDC6803);
    }
    if (_has('Porte') || _has('Tornelli') || _has('Palo') || _has('colonna')) {
      return const Color(0xFF7839EE);
    }
    if (_has('visibilità') || _has('segnaletica')) {
      return const Color(0xFFA16207);
    }
    if (_has('Auto') ||
        _has('parcheggiata') ||
        _has('Cantieri') ||
        _has('Rifiuti') ||
        _has('ingombri')) {
      return const Color(0xFF1570EF);
    }
    return const Color(0xFF667085);
  }

  /// Categoria salvata su Firestore o, se manca, ricavata dal tipo.
  String get category {
    final stored = _storedCategory;
    if (stored != null && obstacleTypesByCategory.containsKey(stored)) {
      return stored;
    }
    return obstacleCategoryOf(type);
  }
}

/// Quanti "grazie" hanno ricevuto in tutto le segnalazioni di [userId].
int thanksReceived(Iterable<Obstacle> obstacles, String? userId) {
  if (userId == null) return 0;
  return obstacles
      .where((o) => o.isReportedBy(userId))
      .fold(0, (total, o) => total + o.thankedBy.length);
}
