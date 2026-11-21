import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/info_page.dart';
import 'package:freeway/services/account_data_service.dart';

void main() {
  test('la copia dei dati è JSON leggibile con date ISO', () {
    final json = AccountDataService.buildExport(
      account: {'uid': 'u1', 'email': 'a@b.it', 'ospite': false},
      ownReports: [
        {
          'id': 'r1',
          'lat': 45.5,
          'lng': 10.2,
          'type': 'Gradino',
          'timestamp': Timestamp.fromMillisecondsSinceEpoch(0),
        },
      ],
      votes: {
        'confirmedBy': ['r2'],
        'thankedBy': ['r3'],
      },
      entrances: [
        {'id': 'i1', 'answer': 'gradini'},
      ],
      limits: {'lastReportAt': Timestamp.fromMillisecondsSinceEpoch(0)},
      device: {
        'freeway.saved_places': '[{"name":"Casa"}]',
        'freeway.voice_speed': 'normal',
      },
    );
    final data = jsonDecode(json) as Map<String, dynamic>;
    expect(data['account']['uid'], 'u1');
    expect(data['segnalazioni'][0]['timestamp'], '1970-01-01T00:00:00.000Z');
    expect(data['votiSulleSegnalazioniAltrui']['confirmedBy'], ['r2']);
    expect(data['votiSulleSegnalazioniAltrui']['thankedBy'], ['r3']);
    expect(data['risposteSugliIngressi'][0]['answer'], 'gradini');
    expect(data['limiti']['lastReportAt'], '1970-01-01T00:00:00.000Z');
    // I valori salvati come JSON tornano strutturati.
    expect(
      data['suQuestoDispositivo']['freeway.saved_places'][0]['name'],
      'Casa',
    );
    expect(data['suQuestoDispositivo']['freeway.voice_speed'], 'normal');
  });

  test('si ritirano tutti i campi con il proprio uid', () {
    expect(AccountDataService.voteFields, [
      'confirmedBy',
      'notThereBy',
      'thankedBy',
      'passYesBy',
      'passHardBy',
      'passNoBy',
    ]);
  });

  test("l'informativa è tra le schede e spiega diritti e servizi", () {
    expect(infoPages, contains(privacyPage));
    final text = [...privacyPage.paragraphs, ...privacyPage.bullets].join(' ');
    expect(text, contains('Titolare'));
    expect(text, contains('Garante'));
    expect(text, contains('Valhalla'));
    expect(text, contains('non vengono salvati'));
  });
}
