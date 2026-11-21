import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Stato di un viaggio condiviso, come lo vede chi ha ricevuto il link.
class SharedTrip {
  const SharedTrip({
    required this.position,
    required this.destination,
    required this.destinationName,
    required this.arrived,
    required this.expiresAt,
    this.accuracy = 0,
    this.remainingMeters,
    this.remainingSeconds,
    this.updatedAt,
  });

  final LatLng position;
  final double accuracy;
  final LatLng destination;
  final String destinationName;
  final double? remainingMeters;
  final double? remainingSeconds;
  final bool arrived;
  final DateTime? updatedAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Nessun aggiornamento da più di 2 minuti: forse senza segnale.
  bool isStale(DateTime now) {
    final updated = updatedAt;
    return !arrived &&
        updated != null &&
        now.difference(updated) > const Duration(minutes: 2);
  }

  static SharedTrip? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    double? number(String key) => (data[key] as num?)?.toDouble();
    final lat = number('lat');
    final lng = number('lng');
    final destLat = number('destLat');
    final destLng = number('destLng');
    final expires = data['expiresAt'];
    if (lat == null ||
        lng == null ||
        destLat == null ||
        destLng == null ||
        expires is! Timestamp) {
      return null;
    }
    final updated = data['updatedAt'];
    return SharedTrip(
      position: LatLng(lat, lng),
      accuracy: number('accuracy') ?? 0,
      destination: LatLng(destLat, destLng),
      destinationName: data['destName'] as String? ?? 'destinazione',
      remainingMeters: number('remainingMeters'),
      remainingSeconds: number('remainingSeconds'),
      arrived: data['arrived'] == true,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
      expiresAt: expires.toDate(),
    );
  }
}

/// "Condividi il viaggio", come "Share trip progress" di Google Maps: chi
/// riceve il link vede dove sei e quando arrivi, finché non arrivi, non
/// interrompi o non scade (al massimo 4 ore). Il documento `viaggi/{id}` non
/// contiene nome né email.
class TripShareService {
  TripShareService(this._firestore, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _clock;

  /// Durata massima ammessa dalle regole.
  static const Duration maxDuration = Duration(hours: 4);

  /// Dopo l'arrivo il link resta valido ancora un po', per vedere l'arrivo.
  static const Duration afterArrival = Duration(minutes: 15);

  /// Intervallo minimo tra due aggiornamenti (le regole ne vogliono 3 s).
  static const Duration updateInterval = Duration(seconds: 10);

  /// Spostamento minimo per un nuovo aggiornamento prima dell'intervallo
  /// massimo di silenzio.
  static const Duration heartbeat = Duration(seconds: 60);

  CollectionReference<Map<String, dynamic>> get _trips =>
      _firestore.collection('viaggi');

  String? _id;
  DateTime? _lastWrite;
  Map<String, Object?>? _pending;
  Timer? _timer;

  /// Id del viaggio condiviso in corso, o `null`.
  String? get activeId => _id;
  bool get isSharing => _id != null;

  /// Indirizzo da mandare: la pagina dell'app con `?viaggio=id`.
  static Uri linkFor(String id, Uri base) =>
      base.removeFragment().replace(queryParameters: {'viaggio': id});

  Future<String> start({
    required String userId,
    required LatLng position,
    required double accuracy,
    required LatLng destination,
    required String destinationName,
    double? remainingMeters,
    double? remainingSeconds,
  }) async {
    await stop();
    final doc = _trips.doc();
    final name = destinationName.length > 100
        ? destinationName.substring(0, 100)
        : destinationName;
    await doc.set({
      'ownerId': userId,
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': accuracy,
      'destLat': destination.latitude,
      'destLng': destination.longitude,
      'destName': name,
      'remainingMeters': ?remainingMeters,
      'remainingSeconds': ?remainingSeconds,
      'arrived': false,
      'updatedAt': FieldValue.serverTimestamp(),
      // Qualche minuto in meno del massimo, per la differenza di orologio.
      'expiresAt': Timestamp.fromDate(
        _clock().add(maxDuration - const Duration(minutes: 5)),
      ),
    });
    _id = doc.id;
    _lastWrite = _clock();
    return doc.id;
  }

  /// Nuova posizione. Le scritture sono raggruppate: al massimo una ogni
  /// [updateInterval].
  void update({
    required LatLng position,
    required double accuracy,
    double? remainingMeters,
    double? remainingSeconds,
  }) {
    if (_id == null) return;
    _pending = {
      'lat': position.latitude,
      'lng': position.longitude,
      'accuracy': accuracy,
      'remainingMeters': ?remainingMeters,
      'remainingSeconds': ?remainingSeconds,
    };
    _schedule();
  }

  /// Arrivo: chi guarda lo vede e il link scade poco dopo.
  void arrived(LatLng position) {
    if (_id == null) return;
    _pending = {
      'lat': position.latitude,
      'lng': position.longitude,
      'remainingMeters': 0,
      'remainingSeconds': 0,
      'arrived': true,
      'expiresAt': Timestamp.fromDate(_clock().add(afterArrival)),
    };
    _schedule();
  }

  void _schedule() {
    if (_timer?.isActive ?? false) return;
    final last = _lastWrite;
    final wait = last == null
        ? Duration.zero
        : updateInterval - _clock().difference(last);
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _flush);
  }

  Future<void> _flush() async {
    final id = _id;
    final data = _pending;
    if (id == null || data == null) return;
    _pending = null;
    _lastWrite = _clock();
    try {
      await _trips.doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Senza rete Firestore la manda appena torna; se le regole la
      // rifiutano si riprova con la posizione successiva.
    }
  }

  /// Dopo l'arrivo: smette di aggiornare ma lascia il documento, che
  /// scade da solo poco dopo, così chi guarda vede l'arrivo.
  Future<void> finishAfterArrival() async {
    _timer?.cancel();
    _timer = null;
    await _flush();
    _id = null;
  }

  /// Interrompe la condivisione e cancella il documento.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    final id = _id;
    _id = null;
    if (id == null) return;
    try {
      await _trips.doc(id).delete();
    } catch (_) {
      // Se non si riesce a cancellare, il link scade comunque.
    }
  }

  /// Per chi ha ricevuto il link: aggiornamenti del viaggio, `null` se è
  /// finito, scaduto o il link non è valido.
  static Stream<SharedTrip?> watch(FirebaseFirestore firestore, String id) =>
      firestore
          .collection('viaggi')
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          // Un documento assente solo nella cache locale non vuol dire che
          // il viaggio sia finito: si aspetta la risposta del server.
          .where((s) => s.exists || !s.metadata.isFromCache)
          .map((snapshot) => SharedTrip.fromMap(snapshot.data()))
          // Un viaggio scaduto non si può più leggere: è finito.
          .transform(
            StreamTransformer<SharedTrip?, SharedTrip?>.fromHandlers(
              handleError: (_, _, sink) => sink.add(null),
            ),
          );

  @visibleForTesting
  Map<String, Object?>? get pendingForTest => _pending;

  void dispose() {
    _timer?.cancel();
  }
}
