import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

import '../models/obstacle.dart';

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

  Future<void> add(LatLng position, String type, String userId) async {
    await _collection.add({
      'lat': position.latitude,
      'lng': position.longitude,
      'type': type,
      'category': obstacleCategoryOf(type),
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
    });
  }

  /// Registra che [userId] ha visto l'ostacolo ancora al suo posto.
  Future<void> confirm(String id, String userId) async {
    await _collection.doc(id).update({
      'confirmedBy': FieldValue.arrayUnion([userId]),
      'lastConfirmedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String id) async {
    await _collection.doc(id).delete();
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
