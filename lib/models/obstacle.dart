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

  final String? _storedCategory;

  factory Obstacle.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return Obstacle.fromMap(doc.id, doc.data());
  }

  factory Obstacle.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    final confirmed = data['lastConfirmedAt'];
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
      confirmedBy: (data['confirmedBy'] as List?)?.whereType<String>().toList() ??
          const [],
      lastConfirmedAt: confirmed is Timestamp ? confirmed.toDate() : null,
    );
  }

  int get confirmationCount => confirmedBy.length;

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
    if (_has('rampa') || _has('ascensore') || _has('Gradino') || _has('ripido')) {
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
