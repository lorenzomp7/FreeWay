/// Traduce le manovre OSRM (`tipo|modificatore|via`) in testo leggibile.
class InstructionTranslator {
  const InstructionTranslator(this.language);

  final String language;

  static const Map<String, String> _typesIt = {
    'depart': 'Parti',
    'arrive': 'Sei arrivato/a',
    'turn': 'Svolta',
    'continue': 'Prosegui',
    'merge': 'Immettiti',
    'on ramp': 'Prendi la rampa',
    'off ramp': 'Esci dalla rampa',
    'fork': 'Tieni',
    'end of road': 'Fine della strada, svolta',
    'new name': 'Prosegui',
    'roundabout': 'Alla rotonda',
    'rotary': 'Alla rotonda',
    'roundabout turn': 'Alla rotonda, svolta',
    'notification': '',
    'exit roundabout': 'Esci dalla rotonda',
    'exit rotary': 'Esci dalla rotonda',
  };

  static const Map<String, String> _typesEn = {
    'depart': 'Depart',
    'arrive': 'You have arrived',
    'turn': 'Turn',
    'continue': 'Continue',
    'merge': 'Merge',
    'on ramp': 'Take the ramp',
    'off ramp': 'Exit the ramp',
    'fork': 'Keep',
    'end of road': 'End of road, turn',
    'new name': 'Continue',
    'roundabout': 'At the roundabout',
    'rotary': 'At the roundabout',
    'roundabout turn': 'At the roundabout, turn',
    'notification': '',
    'exit roundabout': 'Exit the roundabout',
    'exit rotary': 'Exit the roundabout',
  };

  static const Map<String, String> _modifiersIt = {
    'uturn': 'Fai inversione a U',
    'sharp right': 'a destra (stretto)',
    'right': 'a destra',
    'slight right': 'leggermente a destra',
    'straight': 'dritto',
    'slight left': 'leggermente a sinistra',
    'left': 'a sinistra',
    'sharp left': 'a sinistra (stretto)',
  };

  static const Map<String, String> _modifiersEn = {
    'uturn': 'Make a U-turn',
    'sharp right': 'sharp right',
    'right': 'right',
    'slight right': 'slight right',
    'straight': 'straight',
    'slight left': 'slight left',
    'left': 'left',
    'sharp left': 'sharp left',
  };

  String translate(String instruction) {
    final parts = instruction.split('|');
    if (parts.length < 3) return instruction;
    final type = parts[0];
    final modifier = parts[1];
    final street = parts[2];
    final isItalian = language == 'it';
    final types = isItalian ? _typesIt : _typesEn;
    final modifiers = isItalian ? _modifiersIt : _modifiersEn;

    String text;
    if (type == 'depart') {
      final suffix = street.isNotEmpty
          ? (isItalian ? ' da $street' : ' from $street')
          : '';
      text = (types[type] ?? type) + suffix;
    } else if (type == 'stop') {
      final where = street.isNotEmpty
          ? (isItalian ? ' su $street' : ' on $street')
          : '';
      text = isItalian
          ? 'Hai raggiunto la tappa$where'
          : 'You have reached your stop$where';
    } else if (type == 'park') {
      final where = street.isNotEmpty
          ? (isItalian ? ' ($street)' : ' ($street)')
          : '';
      text = isItalian
          ? 'Parcheggia nel posto riservato alle persone con disabilità$where, '
                'poi prosegui in sedia a rotelle'
          : 'Park in the accessible parking space$where, then continue '
                'by wheelchair';
    } else if (type == 'arrive') {
      final side = isItalian
          ? const {
              'left': 'la destinazione è sulla sinistra',
              'right': 'la destinazione è sulla destra',
              'straight': 'la destinazione è davanti a te',
            }[modifier]
          : const {
              'left': 'your destination is on the left',
              'right': 'your destination is on the right',
              'straight': 'your destination is ahead',
            }[modifier];
      if (side != null) {
        final where = street.isNotEmpty
            ? (isItalian ? ' su $street' : ' on $street')
            : '';
        text = '${types[type] ?? type}$where: $side';
      } else {
        final suffix = street.isNotEmpty
            ? (isItalian
                  ? ' a destinazione su $street'
                  : ' at destination on $street')
            : (isItalian ? ' a destinazione' : ' at destination');
        text = (types[type] ?? type) + suffix;
      }
    } else if (modifier == 'uturn') {
      text = modifiers['uturn'] ?? 'U-turn';
    } else {
      final action = types[type] ?? type;
      final direction = modifiers[modifier] ?? modifier;
      final suffix = street.isNotEmpty
          ? (isItalian ? ' su $street' : ' on $street')
          : '';
      text = '$action $direction$suffix';
    }
    return text.trim();
  }
}

/// Emoji mostrata nel pannello di navigazione per ogni manovra.
String maneuverEmoji(String type, String modifier) {
  if (type == 'arrive') return '🏁';
  if (type == 'stop') return '📍';
  if (type == 'park') return '🅿️';
  if (type == 'depart') return '🚶';
  switch (modifier) {
    case 'uturn':
      return '↩️';
    case 'sharp right':
      return '↗️';
    case 'right':
      return '➡️';
    case 'slight right':
      return '↗️';
    case 'straight':
      return '⬆️';
    case 'slight left':
      return '↖️';
    case 'left':
      return '⬅️';
    case 'sharp left':
      return '↖️';
    default:
      return '⬆️';
  }
}
