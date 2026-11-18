import '../models/obstacle.dart';

/// Parole (o loro inizi) che fanno riconoscere ciascun tipo di ostacolo in
/// una frase detta a voce, in italiano e in inglese.
const Map<String, List<String>> _keywords = {
  'Mancanza di rampa/ascensore': [
    'rampa',
    'rampe',
    'ascensor',
    'ramp',
    'elevator',
    'lift',
  ],
  'Gradino che rende impossibile il passaggio': [
    'gradin',
    'scalin',
    'scale',
    'scala',
    'step',
    'stair',
    'kerb',
    'curb',
  ],
  'Tratto di strada troppo ripido': [
    'ripid',
    'salita',
    'discesa',
    'pendenz',
    'steep',
    'hill',
    'slope',
  ],
  'Buche o pavimentazione accidentata': [
    'buca',
    'buche',
    'dissest',
    'sconness',
    'pavimentaz',
    'rotto',
    'rotta',
    'pothole',
    'uneven',
    'broken',
  ],
  'Tratto con sassi/ghiaia': [
    'sass',
    'ghiaia',
    'sterrat',
    'ciottol',
    'gravel',
    'cobble',
  ],
  'Porte strette o con apertura difficile': ['porta', 'porte', 'door'],
  'Tornelli non accessibili': ['tornell', 'turnstile'],
  'Palo o colonna lungo la via pedonale': [
    'palo',
    'pali',
    'paletto',
    'paletti',
    'colonn',
    'dissuasor',
    'pole',
    'post',
    'bollard',
    'column',
  ],
  'Incrocio o passaggio con scarsa visibilità': [
    'incroc',
    'visibilit',
    'attravers',
    'crossing',
    'intersection',
  ],
  'Mancanza di segnaletica adeguata': [
    'segnalet',
    'cartell',
    'semafor',
    'strisce',
    'sign',
  ],
  'Auto parcheggiata su scivolo o marciapiede': [
    'auto',
    'macchin',
    'parchegg',
    'moto',
    'scooter',
    'furgon',
    'car',
    'parked',
  ],
  'Cantieri con percorsi accessibili bloccati': [
    'cantier',
    'lavori',
    'impalcatur',
    'transenn',
    'construction',
    'roadwork',
    'works',
  ],
  'Rifiuti o ingombri che ostruiscono il passaggio': [
    'rifiut',
    'spazzatur',
    'cassonett',
    'ingombr',
    'bidon',
    'immondiz',
    'trash',
    'rubbish',
    'garbage',
    'bin',
  ],
};

const Map<String, String> _accents = {
  'à': 'a',
  'á': 'a',
  'è': 'e',
  'é': 'e',
  'ì': 'i',
  'í': 'i',
  'ò': 'o',
  'ó': 'o',
  'ù': 'u',
  'ú': 'u',
};

/// Parole in minuscolo, senza accenti né punteggiatura.
List<String> _words(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer
      .toString()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
}

/// Il tipo di ostacolo di [obstacleTypesByCategory] che meglio corrisponde
/// alla frase [spoken], oppure `null` se nessuna parola lo fa riconoscere.
///
/// Per ogni tipo si contano le parole della frase che iniziano con una sua
/// parola chiave ("gradini" vale per "gradin"); vince il tipo con più
/// corrispondenze, a parità il primo dell'elenco. Le parole chiave di tre
/// lettere ("car", "bin") devono corrispondere per intero (o al plurale
/// inglese), così "cartello" non diventa "car".
String? matchObstacleType(String spoken) {
  final words = _words(spoken);
  String? best;
  var bestScore = 0;
  for (final entry in _keywords.entries) {
    var score = 0;
    for (final word in words) {
      final hit = entry.value.any(
        (k) =>
            k.length <= 3 ? word == k || word == '${k}s' : word.startsWith(k),
      );
      if (hit) score++;
    }
    if (score > bestScore) {
      best = entry.key;
      bestScore = score;
    }
  }
  return best;
}
