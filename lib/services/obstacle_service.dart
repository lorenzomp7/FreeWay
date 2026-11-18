import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  CollectionReference<Map<String, dynamic>> get _photos =>
      _firestore.collection('foto');

  /// Dimensione massima della foto in base64 accettata da firestore.rules.
  static const int maxPhotoChars = 700000;

  /// La foto [bytes] è abbastanza piccola per essere salvata.
  static bool photoFits(Uint8List bytes) =>
      base64Encode(bytes).length <= maxPhotoChars;

  /// Foto di una segnalazione, o `null` se non c'è o non si riesce a leggere.
  Future<Uint8List?> loadPhoto(String id) async {
    try {
      final snapshot = await _photos.doc(id).get();
      final data = snapshot.data()?['data'];
      return data is String ? base64Decode(data) : null;
    } catch (_) {
      return null;
    }
  }

  /// Salva una segnalazione insieme all'ora in `limiti/{uid}`, come chiedono
  /// le regole di firestore.rules. Se il database ha ancora regole più
  /// vecchie che non conoscono `limiti` o `category`, la scrittura combinata
  /// viene rifiutata: in quel caso si salva la segnalazione nel formato
  /// originale. Con le regole nuove anche questo secondo tentativo viene
  /// rifiutato, quindi il limite di frequenza resta valido.
  ///
  /// Con [photo] la foto va in `foto/{id}` nella stessa scrittura. Se le
  /// regole pubblicate non conoscono ancora le foto, la segnalazione si salva
  /// senza e il risultato è `false`; altrimenti `true`.
  Future<bool> add(
    LatLng position,
    String type,
    String userId, {
    Uint8List? photo,
  }) async {
    final doc = _collection.doc();
    final report = {
      'lat': position.latitude,
      'lng': position.longitude,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
    };
    WriteBatch combined({required bool withPhoto}) {
      final batch = _firestore.batch()
        ..set(doc, {
          ...report,
          'category': obstacleCategoryOf(type),
          if (withPhoto) 'hasPhoto': true,
        })
        ..set(
          _limits(userId),
          {'lastReportAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      if (withPhoto) {
        batch.set(_photos.doc(doc.id), {
          'data': base64Encode(photo!),
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      return batch;
    }

    if (photo != null) {
      try {
        await combined(withPhoto: true).commit();
        return true;
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }
    try {
      await combined(withPhoto: false).commit();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      await doc.set(report);
    }
    return photo == null;
  }

  /// Registra che [userId] ha visto l'ostacolo ancora al suo posto.
  Future<void> confirm(String id, String userId) async {
    await _collection.doc(id).update({
      'confirmedBy': FieldValue.arrayUnion([userId]),
      'lastConfirmedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Registra che [userId] non ha trovato l'ostacolo. Con due voti più
  /// recenti dell'ultima conferma l'app smette di mostrarlo.
  Future<void> voteNotThere(String id, String userId) async {
    await _collection.doc(id).update({
      'notThereBy': FieldValue.arrayUnion([userId]),
      'lastNotThereAt': FieldValue.serverTimestamp(),
    });
  }

  /// Rimuove una segnalazione aggiornando `limiti/{uid}`; con regole più
  /// vecchie che non conoscono `limiti` ripiega sulla sola rimozione.
  Future<void> remove(String id, String userId, {bool hasPhoto = false}) async {
    final batch = _firestore.batch()
      ..delete(_collection.doc(id))
      ..set(
        _limits(userId),
        {'lastRemovalAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    if (hasPhoto) batch.delete(_photos.doc(id));
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      await _collection.doc(id).delete();
    }
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
