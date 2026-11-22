// Configurazione Firebase dell'app web.
//
// I valori si copiano dalla console Firebase del proprio progetto:
// Impostazioni progetto → Generali → Le tue app → app web (firebaseConfig).
// Non sono segreti: finiscono comunque nel JavaScript pubblicato.
// Finché sono vuoti l'app non si collega a nessun progetto e lo dice.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// ID client OAuth per "Accedi con Google" sul web (Authentication → Metodo
/// di accesso → Google → Configurazione SDK web). Vuoto finché non c'è.
const String kGoogleWebClientId = '';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'DefaultFirebaseOptions è configurato solo per il web. '
      'Esegui `flutterfire configure` per le altre piattaforme.',
    );
  }

  /// `true` quando la configurazione del progetto è stata inserita.
  static bool get isConfigured =>
      web.apiKey.isNotEmpty && web.projectId.isNotEmpty;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBbiJni3pw2ygX7B9AWdjc96Zs2PQyM_wY',
    appId: '1:221640287393:web:b7d787c623b808d1fcfce0',
    messagingSenderId: '221640287393',
    projectId: 'freewayonlineapp',
    authDomain: 'freewayonlineapp.firebaseapp.com',
    storageBucket: 'freewayonlineapp.firebasestorage.app',
    measurementId: 'G-KWWJ2Y7WC3',
  );
}
