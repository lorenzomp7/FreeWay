import 'instruction_translator.dart';
import 'navigation_service.dart';

/// Decide cosa dire a voce durante la navigazione.
///
/// Prima ripeteva l'istruzione a ogni aggiornamento GPS (circa ogni 5 m).
/// Ora, come fanno i navigatori, ogni manovra si annuncia al massimo tre
/// volte, ciascuna una volta sola:
///
/// 1. subito dopo la manovra precedente, se la prossima è lontana:
///    "Prosegui per 300 metri";
/// 2. a [prepareDistance] metri: "Tra 100 metri, svolta a destra";
/// 3. a [nowDistance] metri: "Svolta a destra", seguito da "poi svolta a
///    sinistra" se la manovra successiva arriva entro [chainDistance] metri,
///    così non la si scopre quando è già il momento di farla.
///
/// Le distanze sono pensate per chi va a piedi o in sedia a rotelle (circa
/// 1 m/s): 100 m sono circa un minuto e mezzo di anticipo, 20 m una
/// ventina di secondi.
class VoiceGuidance {
  VoiceGuidance({
    this.prepareDistance = 100,
    this.nowDistance = 20,
    this.chainDistance = 40,
  });

  final double prepareDistance;
  final double nowDistance;
  final double chainDistance;

  /// Oltre questa distanza, appena fatta una manovra si dice per quanto
  /// proseguire.
  double get continueDistance => prepareDistance * 1.4;

  int? _stepIndex;
  final Set<_Stage> _said = {};
  bool _arrivedSaid = false;
  bool _offRouteSaid = false;

  /// Da chiamare quando cambia il percorso (partenza o ricalcolo).
  void reset() {
    _stepIndex = null;
    _said.clear();
    _arrivedSaid = false;
    _offRouteSaid = false;
  }

  /// La frase da dire per [update], oppure `null` se non c'è nulla di nuovo.
  ///
  /// Con [brief] si dice solo la manovra quando è il momento (con il "poi"),
  /// l'arrivo e il fuori percorso: niente "Prosegui per" né "Tra 100 metri".
  String? next(NavigationUpdate update, String language, {bool brief = false}) {
    final it = language == 'it';
    if (update.hasArrived) {
      if (_arrivedSaid) return null;
      _arrivedSaid = true;
      return _instruction(update.currentStep.instruction, language);
    }
    if (update.isOffRoute) {
      if (_offRouteSaid) return null;
      _offRouteSaid = true;
      return it
          ? 'Sei fuori percorso. Ricalcolo.'
          : 'You are off route. Recalculating.';
    }
    _offRouteSaid = false;

    if (_stepIndex != update.stepIndex) {
      _stepIndex = update.stepIndex;
      _said.clear();
    }

    final step = update.currentStep;
    final distance = update.distanceToNextStep;
    final isEnd = step.maneuverType == 'arrive' || step.maneuverType == 'stop';

    if (distance <= nowDistance) {
      // Arrivo e tappe si annunciano quando ci si arriva davvero.
      if (isEnd || !_said.add(_Stage.now)) return null;
      _said.addAll(_Stage.values);
      var text = _instruction(step.instruction, language);
      final following = update.followingStep;
      if (following != null && update.distanceBetweenSteps <= chainDistance) {
        final then = following.maneuverType == 'arrive'
            ? (it ? 'poi sei arrivato/a' : 'then you have arrived')
            : '${it ? 'poi' : 'then'} '
                  '${_lower(_instruction(following.instruction, language))}';
        text = '$text, $then';
      }
      return text;
    }

    if (brief) return null;

    if (distance <= prepareDistance) {
      if (!_said.add(_Stage.prepare)) return null;
      _said.add(_Stage.carryOn);
      final spoken = spokenDistance(distance, language);
      if (step.maneuverType == 'arrive') {
        return it
            ? 'Tra $spoken arrivi a destinazione'
            : 'In $spoken, you will reach your destination';
      }
      if (step.maneuverType == 'stop') {
        return it ? 'Tra $spoken, la tappa' : 'In $spoken, your stop';
      }
      final instruction = _lower(_instruction(step.instruction, language));
      return it ? 'Tra $spoken, $instruction' : 'In $spoken, $instruction';
    }

    if (distance >= continueDistance) {
      if (!_said.add(_Stage.carryOn)) return null;
      final spoken = spokenDistance(distance, language);
      return it ? 'Prosegui per $spoken' : 'Continue for $spoken';
    }
    return null;
  }

  static String _instruction(String raw, String language) =>
      InstructionTranslator(language).translate(raw);

  static String _lower(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

  /// Distanza arrotondata come la si dice: di 10 in 10 m sotto i 100 m, di
  /// 50 in 50 fino al chilometro, poi in chilometri con un decimale.
  static String spokenDistance(double meters, String language) {
    final it = language == 'it';
    if (meters >= 950) {
      final km = (meters / 100).round() / 10;
      final value = km == km.roundToDouble()
          ? km.round().toString()
          : (it ? km.toString().replaceAll('.', ',') : km.toString());
      if (km == 1) return it ? '1 chilometro' : '1 kilometer';
      return it ? '$value chilometri' : '$value kilometers';
    }
    final step = meters < 100 ? 10 : 50;
    final rounded = ((meters / step).round() * step).clamp(10, 950);
    return it ? '$rounded metri' : '$rounded meters';
  }
}

enum _Stage { carryOn, prepare, now }
