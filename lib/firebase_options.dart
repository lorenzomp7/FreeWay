// Configurazione Firebase del progetto `progetto-rimosso`.
//
// È la configurazione web pubblica, la stessa inclusa nella web app pubblicata.
// Per aggiungere altre piattaforme rigenerare il file con `flutterfire configure`.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'DefaultFirebaseOptions è configurato solo per il web. '
      'Esegui `flutterfire configure` per le altre piattaforme.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'RIMOSSO',
    appId: 'RIMOSSO',
    messagingSenderId: 'RIMOSSO',
    projectId: 'progetto-rimosso',
    authDomain: 'progetto-rimosso.firebaseapp.com',
    databaseURL:
        'https://progetto-rimosso-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'progetto-rimosso.firebasestorage.app',
    measurementId: 'RIMOSSO',
  );
}
