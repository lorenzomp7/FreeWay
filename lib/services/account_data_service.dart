import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline/offline_route_service.dart';

/// Esito di "Elimina account e dati".
enum DeletionResult {
  /// Dati e account eliminati: l'app torna alla schermata di accesso.
  done,

  /// Dati eliminati, ma Firebase chiede un accesso recente per eliminare
  /// l'account: bisogna uscire, rientrare e ripetere.
  needsRecentLogin,
}

/// Diritti dell'interessato (GDPR) sui dati di FreeWay: copia dei propri
/// dati (artt. 15 e 20) ed eliminazione di account e dati (art. 17).
class AccountDataService {
  AccountDataService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Scritture al massimo per batch (Firestore ne accetta 500).
  static const int _batchSize = 400;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('segnalazioni');

  /// Campi delle segnalazioni altrui che contengono il proprio uid:
  /// conferme, voti "Non c'è più", "Grazie" e risposte "Si riesce a
  /// passare?".
  static const List<String> voteFields = [
    'confirmedBy',
    'notThereBy',
    'thankedBy',
    'passYesBy',
    'passHardBy',
    'passNoBy',
  ];

  /// Tutti i dati legati all'account, in JSON leggibile: profilo, proprie
  /// segnalazioni, conferme e voti dati, limiti e i dati salvati su questo
  /// dispositivo (ricerche recenti, luoghi salvati, impostazioni).
  Future<String> exportJson() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Nessun utente');
    final uid = user.uid;
    final own = await _reports.where('userId', isEqualTo: uid).get();
    final votes = <String, List<String>>{};
    for (final field in voteFields) {
      final docs = await _reports.where(field, arrayContains: uid).get();
      votes[field] = [for (final d in docs.docs) d.id];
    }
    final entrances = await _firestore
        .collection('ingressi')
        .where('userId', isEqualTo: uid)
        .get();
    final trips = await _firestore
        .collection('viaggi')
        .where('ownerId', isEqualTo: uid)
        .get();
    Map<String, dynamic>? limits;
    try {
      limits = (await _firestore.collection('limiti').doc(uid).get()).data();
    } catch (_) {
      limits = null;
    }
    final preferences = await SharedPreferences.getInstance();
    return buildExport(
      account: {
        'uid': uid,
        'email': user.email,
        'nome': user.displayName,
        'ospite': user.isAnonymous,
        'accessi': [for (final p in user.providerData) p.providerId],
        'creato': user.metadata.creationTime?.toIso8601String(),
        'ultimoAccesso': user.metadata.lastSignInTime?.toIso8601String(),
      },
      ownReports: [
        for (final d in own.docs) {'id': d.id, ...d.data()},
      ],
      votes: votes,
      entrances: [
        for (final d in entrances.docs) {'id': d.id, ...d.data()},
      ],
      sharedTrips: [
        for (final d in trips.docs) {'id': d.id, ...d.data()},
      ],
      limits: limits,
      device: {
        for (final key in preferences.getKeys())
          if (key.startsWith('freeway.')) key: preferences.get(key),
      },
    );
  }

  /// Compone il JSON dell'esportazione, con date leggibili.
  @visibleForTesting
  static String buildExport({
    required Map<String, dynamic> account,
    required List<Map<String, dynamic>> ownReports,
    required Map<String, List<String>> votes,
    List<Map<String, dynamic>> entrances = const [],
    List<Map<String, dynamic>> sharedTrips = const [],
    Map<String, dynamic>? limits,
    Map<String, Object?> device = const {},
  }) {
    Object? plain(Object? value) {
      if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
      if (value is DateTime) return value.toUtc().toIso8601String();
      if (value is Map) {
        return {for (final e in value.entries) '${e.key}': plain(e.value)};
      }
      if (value is List) return [for (final v in value) plain(v)];
      if (value is String) {
        // Ricerche e luoghi salvati sono a loro volta JSON.
        final trimmed = value.trimLeft();
        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
          try {
            return jsonDecode(value);
          } catch (_) {
            return value;
          }
        }
      }
      return value;
    }

    final data = {
      'esportato': DateTime.now().toUtc().toIso8601String(),
      'account': plain(account),
      'segnalazioni': plain(ownReports),
      'votiSulleSegnalazioniAltrui': votes,
      'risposteSugliIngressi': plain(entrances),
      'viaggiCondivisi': plain(sharedTrips),
      'limiti': plain(limits),
      'suQuestoDispositivo': plain(device),
      'nota':
          'Le foto delle segnalazioni sono nella collezione "foto" con lo '
          'stesso id della segnalazione. La posizione GPS non viene salvata '
          'sui server di FreeWay.',
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Elimina le proprie segnalazioni (con le foto), ritira conferme, voti e
  /// "grazie" dati alle segnalazioni degli altri, cancella le risposte sugli
  /// ingressi, i viaggi condivisi, i limiti e i dati salvati sul
  /// dispositivo, poi l'account.
  Future<DeletionResult> deleteEverything() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Nessun utente');
    final uid = user.uid;

    final own = await _reports.where('userId', isEqualTo: uid).get();
    await _inBatches(own.docs, (batch, doc) {
      batch.delete(doc.reference);
      if (doc.data()['hasPhoto'] == true) {
        batch.delete(_firestore.collection('foto').doc(doc.id));
      }
    });

    // Un campo alla volta: le regole accettano solo il ritiro del proprio uid.
    for (final field in voteFields) {
      final docs = await _reports.where(field, arrayContains: uid).get();
      await _inBatches(docs.docs, (batch, doc) {
        batch.update(doc.reference, {
          field: FieldValue.arrayRemove([uid]),
        });
      });
    }

    for (final (collection, owner) in [
      ('ingressi', 'userId'),
      ('viaggi', 'ownerId'),
    ]) {
      final docs = await _firestore
          .collection(collection)
          .where(owner, isEqualTo: uid)
          .get();
      await _inBatches(docs.docs, (batch, doc) => batch.delete(doc.reference));
    }

    await _deleteLimits(uid);

    // Percorso e mappe salvati per l'uso senza rete.
    try {
      await OfflineRouteService().clear();
    } catch (_) {
      // Non è un dato personale sul server: si va avanti.
    }

    final preferences = await SharedPreferences.getInstance();
    for (final key in preferences.getKeys().toList()) {
      if (key.startsWith('freeway.')) await preferences.remove(key);
    }

    try {
      await user.delete();
      return DeletionResult.done;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        return DeletionResult.needsRecentLogin;
      }
      rethrow;
    }
  }

  /// I limiti si cancellano solo quando i tempi minimi (30 s dall'ultima
  /// segnalazione, 10 s dall'ultima rimozione, 60 s dall'ultima risposta
  /// sull'ingresso) sono passati: se serve si aspetta e si riprova una volta.
  Future<void> _deleteLimits(String uid) async {
    final ref = _firestore.collection('limiti').doc(uid);
    try {
      await ref.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      await Future<void>.delayed(const Duration(seconds: 61));
      await ref.delete();
    }
  }

  Future<void> _inBatches(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    void Function(
      WriteBatch batch,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    )
    write,
  ) async {
    for (var i = 0; i < docs.length; i += _batchSize ~/ 2) {
      final batch = _firestore.batch();
      for (final doc in docs.skip(i).take(_batchSize ~/ 2)) {
        write(batch, doc);
      }
      await batch.commit();
    }
  }
}
