import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';
import 'geo_utils.dart';

/// Lettura e scrittura delle segnalazioni condivise su Firestore.
class ObstacleService {
  ObstacleService(this._firestore);

  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('segnalazioni');

  /// Ascolta in tempo reale le segnalazioni, dalla più recente.
  void listen(void Function(List<Obstacle> obstacles) onChanged) {
    _subscription = _collection
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      onChanged(snapshot.docs.map(Obstacle.fromDoc).toList());
    });
  }

  /// Documento con l'ora dell'ultima segnalazione e rimozione dell'utente,
  /// usato dalle regole di sicurezza per limitarne la frequenza.
  DocumentReference<Map<String, dynamic>> _limits(String userId) =>
      _firestore.collection('limiti').doc(userId);

  Future<void> add(LatLng position, String type, String userId) async {
    final batch = _firestore.batch()
      ..set(_collection.doc(), {
        'lat': position.latitude,
        'lng': position.longitude,
        'type': type,
        'category': obstacleCategoryOf(type),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      })
      ..set(
        _limits(userId),
        {'lastReportAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    await batch.commit();
  }

  /// Registra che [userId] ha visto l'ostacolo ancora al suo posto.
  Future<void> confirm(String id, String userId) async {
    await _collection.doc(id).update({
      'confirmedBy': FieldValue.arrayUnion([userId]),
      'lastConfirmedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String id, String userId) async {
    final batch = _firestore.batch()
      ..delete(_collection.doc(id))
      ..set(
        _limits(userId),
        {'lastRemovalAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    await batch.commit();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Una segnalazione dello stesso tipo entro [radius] metri da [position], se
/// c'è: invece di duplicarla conviene confermarla.
Obstacle? findDuplicate(
  List<Obstacle> obstacles,
  LatLng position,
  String type, {
  double radius = 25,
}) {
  Obstacle? nearest;
  var nearestDistance = double.infinity;
  for (final obstacle in obstacles) {
    if (obstacle.type != type) continue;
    final distance = haversineDistance(obstacle.position, position);
    if (distance <= radius && distance < nearestDistance) {
      nearest = obstacle;
      nearestDistance = distance;
    }
  }
  return nearest;
}
