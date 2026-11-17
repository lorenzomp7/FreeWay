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
          "dell'Università degli Studi di Brescia: Chiara Leggerini (Project "
          'manager), Lorenzo Mainetti (Team leader), Michela Lanzini, Matteo '
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
      'Cerca partenza e arrivo per calcolare il percorso più accessibile.',
      'Tieni premuto sulla mappa per segnalare un ostacolo che incontri.',
      'Tocca un ostacolo per scoprire di cosa si tratta e quando è stato segnalato.',
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
];
