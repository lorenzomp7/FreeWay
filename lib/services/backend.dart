import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Il servizio dati condiviso (Firebase: account e segnalazioni) c'è o no.
///
/// Senza un progetto Firebase configurato, o se non si avvia, FreeWay
/// funziona lo stesso: mappa, ricerca, percorsi e navigazione non ne hanno
/// bisogno. Restano spente solo le funzioni condivise tra persone.
class Backend {
  Backend._();

  static bool _available = false;

  /// `true` solo dopo che Firebase si è avviato davvero.
  static bool get available => _available;

  static void markAvailable() => _available = true;

  @visibleForTesting
  static void resetForTest({bool available = false}) => _available = available;

  /// L'utente connesso, o `null` senza servizio o senza accesso. Senza
  /// servizio non tocca FirebaseAuth, che altrimenti darebbe errore.
  static String? get userId =>
      _available ? FirebaseAuth.instance.currentUser?.uid : null;
}

/// Spiegazione mostrata quando si prova a usare una funzione condivisa senza
/// servizio dati.
const String kSharedFeaturesOff =
    'Le segnalazioni e gli account sono momentaneamente sospesi. Mappa, '
    'percorsi e navigazione funzionano.';
