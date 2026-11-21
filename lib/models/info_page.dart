import 'package:flutter/material.dart';

/// Contenuto delle schede informative ("Chi siamo", "Come funziona", ...).
class InfoPage {
  const InfoPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.paragraphs = const [],
    this.bullets = const [],
    required this.footer,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> paragraphs;
  final List<String> bullets;
  final String footer;
}

/// Contatto per la privacy, passato in fase di build con
/// `--dart-define=PRIVACY_CONTACT=...` (per esempio un'email del team).
const String kPrivacyContact = String.fromEnvironment('PRIVACY_CONTACT');

/// Informativa sul trattamento dei dati (artt. 13 e 14 GDPR), in breve.
const InfoPage privacyPage = InfoPage(
  title: 'Privacy',
  subtitle: 'Quali dati usa FREE WAY e come eliminarli',
  icon: Icons.privacy_tip_outlined,
  paragraphs: [
    'Titolare del trattamento è il team FREE WAY di Enactus UniBs '
        "(Università degli Studi di Brescia). Per domande o per esercitare i "
        'tuoi diritti: '
        '${kPrivacyContact == '' ? 'scrivi al team (vedi "Chi siamo")' : kPrivacyContact}.',
    'Account e segnalazioni sono salvati su Google Firebase (Authentication '
        'e Cloud Firestore), che li tratta per conto nostro secondo i '
        'Firebase Data Processing and Security Terms.',
  ],
  bullets: [
    "Account: email (o profilo Google) e un codice anonimo per l'ospite. "
        "Servono a far funzionare l'app (art. 6.1.b GDPR).",
    'Segnalazioni: posizione e tipo dell’ostacolo, ora, il tuo codice '
        'utente, la foto se la aggiungi, conferme e voti "Non c\'è più". '
        'Sono visibili a chi usa l’app. Non fotografare persone né targhe.',
    'La tua posizione GPS e il mezzo scelto (sedia a rotelle, a piedi, in '
        'auto) non vengono salvati sui nostri server. Le coordinate dei '
        'punti cercati e dei percorsi vengono inviate ai servizi di mappa: '
        'OpenStreetMap, Photon (Komoot), Nominatim, Overpass, '
        'OpenRouteService, Valhalla e OSRM (FOSSGIS), Open-Meteo; senza GPS '
        'la posizione è stimata dall’indirizzo IP (ipwho.is, ipapi.co).',
    'Sul dispositivo restano ricerche recenti, luoghi salvati, impostazioni '
        'della voce e il viaggio in corso (per 3 ore).',
    'Hai diritto di accedere ai tuoi dati, averne una copia, correggerli e '
        'cancellarli, e di reclamare al Garante per la protezione dei dati '
        'personali. Dal menu "I tuoi dati" puoi copiarli o eliminare account '
        'e dati in ogni momento.',
  ],
  footer:
      'Le segnalazioni restano finché sono utili: quelle temporanee spariscono '
      'dalla mappa dopo 14 giorni senza conferme.',
);

const List<InfoPage> infoPages = [
  InfoPage(
    title: 'Chi siamo',
    subtitle: 'Il progetto e le persone dietro FREE WAY',
    icon: Icons.diversity_3_rounded,
    paragraphs: [
      "FREE WAY nasce dall'idea di rendere le città più accessibili a tutti/e. "
          'Vogliamo aiutare le persone a spostarsi liberamente, segnalando in '
          'tempo reale gli ostacoli sulle strade e sui marciapiedi.',
      'Il progetto è realizzato da un team di studenti/sse e dottorandi/e '
          "dell'Università degli Studi di Brescia: Lorenzo Mainetti (Team "
          'leader), Chiara Leggerini (Project manager), Michela Lanzini, Matteo '
          'Boniotti, Anita Paiardi e Andrea Menardo.',
    ],
    footer:
        "Crediamo che l'inclusione passi anche dalla tecnologia semplice e condivisa.",
  ),
  InfoPage(
    title: 'Come funziona',
    subtitle: 'Tre gesti per muoverti e contribuire',
    icon: Icons.lightbulb_outline_rounded,
    paragraphs: [
      'Con FREE WAY trovi il percorso pedonale migliore da un punto A a un '
          'punto B, tenendo conto delle barriere segnalate dalla community.',
    ],
    bullets: [
      'Cerca il luogo da raggiungere, poi scegli da dove partire: FREE WAY '
          'calcola il percorso più accessibile.',
      'Tieni premuto sulla mappa, oppure usa il pulsante "Segnala un ostacolo '
          'qui", per segnalare un ostacolo che incontri.',
      "Tocca un ostacolo per scoprire di cosa si tratta, confermare che c'è "
          'ancora o segnalare che è stato rimosso.',
    ],
    footer:
        "Ogni segnalazione viene condivisa con tutte le persone che usano l'app.",
  ),
  InfoPage(
    title: 'Prossimi passi',
    subtitle: 'A cosa stiamo lavorando',
    icon: Icons.rocket_launch_outlined,
    bullets: [
      'Mappe e percorsi più fluidi, con API dedicate.',
      'Navigazione passo-passo sempre più precisa lungo il tragitto.',
      'Possibilità di allegare una foto alla segnalazione.',
      'Un indice di vivibilità costruito sui dati raccolti dalla community.',
    ],
    footer: 'Continua a seguirci: il cambiamento passa anche da te!',
  ),
  privacyPage,
];
