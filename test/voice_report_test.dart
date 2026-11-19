import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/obstacle.dart';
import 'package:freeway/services/speech_input.dart';
import 'package:freeway/services/voice_report_matcher.dart';
import 'package:freeway/widgets/map_widgets.dart';
import 'package:freeway/widgets/navigation_prompts.dart';

void main() {
  group('Riconosce il tipo di ostacolo detto a voce', () {
    final cases = {
      'C\'è un gradino': 'Gradino che rende impossibile il passaggio',
      'scalini davanti al negozio':
          'Gradino che rende impossibile il passaggio',
      'Una macchina parcheggiata sul marciapiede':
          'Auto parcheggiata su scivolo o marciapiede',
      'auto sullo scivolo': 'Auto parcheggiata su scivolo o marciapiede',
      'buche enormi': 'Buche o pavimentazione accidentata',
      'cantiere che blocca tutto': 'Cantieri con percorsi accessibili bloccati',
      'lavori in corso': 'Cantieri con percorsi accessibili bloccati',
      'manca la rampa': 'Mancanza di rampa/ascensore',
      'salita troppo ripida': 'Tratto di strada troppo ripido',
      'un palo in mezzo': 'Palo o colonna lungo la via pedonale',
      'cassonetti della spazzatura':
          'Rifiuti o ingombri che ostruiscono il passaggio',
      'ghiaia e sassi': 'Tratto con sassi/ghiaia',
      'porta troppo stretta': 'Porte strette o con apertura difficile',
      'incrocio pericoloso, poca visibilità':
          'Incrocio o passaggio con scarsa visibilità',
      'parked car on the ramp': 'Auto parcheggiata su scivolo o marciapiede',
      'stairs': 'Gradino che rende impossibile il passaggio',
    };
    cases.forEach((spoken, type) {
      test(spoken, () => expect(matchObstacleType(spoken), type));
    });

    test('non indovina quando non capisce', () {
      expect(matchObstacleType('buongiorno'), isNull);
      expect(matchObstacleType(''), isNull);
      // "cartello" non è "car".
      expect(matchObstacleType('cartello'), 'Mancanza di segnaletica adeguata');
    });

    test('i tipi riconosciuti sono quelli della scheda', () {
      final all = obstacleTypesByCategory.values.expand((t) => t).toSet();
      for (final type in cases.values) {
        expect(all, contains(type));
      }
    });
  });

  test('fuori dal browser il microfono non è disponibile', () async {
    final speech = SpeechInput();
    expect(speech.isSupported, isFalse);
    expect(await speech.listen('it'), isEmpty);
  });

  testWidgets('la conferma segnala o fa scegliere dall\'elenco', (
    tester,
  ) async {
    var confirmed = false, fromList = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceReportCard(
            heard: 'un gradino',
            type: 'Gradino che rende impossibile il passaggio',
            onConfirm: () => confirmed = true,
            onChooseFromList: () => fromList = true,
            onCancel: () {},
          ),
        ),
      ),
    );
    expect(
      find.text('Segnalo «Gradino che rende impossibile il passaggio» qui?'),
      findsOneWidget,
    );
    expect(find.text('Ho capito: «un gradino».'), findsOneWidget);
    await tester.tap(find.text('Segnala'));
    await tester.tap(find.text("Scegli dall'elenco"));
    expect(confirmed, isTrue);
    expect(fromList, isTrue);
  });

  testWidgets('il pulsante del microfono compare solo se disponibile', (
    tester,
  ) async {
    Widget controls({VoidCallback? onVoice}) => MaterialApp(
      home: Scaffold(
        body: MapControls(
          onZoomIn: () {},
          onZoomOut: () {},
          onLocate: () {},
          isLocating: false,
          onVoiceReport: onVoice,
        ),
      ),
    );
    await tester.pumpWidget(controls());
    expect(find.byTooltip('Segnala un ostacolo a voce'), findsNothing);
    var tapped = false;
    await tester.pumpWidget(controls(onVoice: () => tapped = true));
    await tester.tap(find.byTooltip('Segnala un ostacolo a voce'));
    expect(tapped, isTrue);
  });
}
