import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/opening_hours.dart';

void main() {
  // 23 novembre 2026 è un lunedì.
  DateTime monday(int hour, [int minute = 0]) =>
      DateTime(2026, 11, 23, hour, minute);
  DateTime day(int offset, int hour, [int minute = 0]) =>
      DateTime(2026, 11, 23 + offset, hour, minute);

  group('OpeningHours.parse', () {
    test('capisce giorni e fasce orarie', () {
      final hours = OpeningHours.parse(
        'Mo-Fr 09:00-12:30,15:00-19:00; Sa 09:00-12:00',
      )!;
      expect(hours.at(monday(10)).status, OpeningStatus.open);
      expect(hours.at(monday(10)).closesAt, monday(12, 30));
      expect(hours.at(monday(13)).status, OpeningStatus.closed);
      expect(hours.at(monday(13)).opensAt, monday(15));
      // Sabato pomeriggio: riapre lunedì.
      final saturday = hours.at(day(5, 14));
      expect(saturday.status, OpeningStatus.closed);
      expect(saturday.opensAt, day(7, 9));
    });

    test('24/7 è sempre aperto', () {
      final hours = OpeningHours.parse('24/7')!;
      expect(hours.alwaysOpen, isTrue);
      expect(hours.at(monday(3)).status, OpeningStatus.open);
      expect(hours.at(monday(3)).closesAt, isNull);
    });

    test('le fasce oltre mezzanotte continuano il giorno dopo', () {
      final hours = OpeningHours.parse('Fr-Sa 18:00-02:00')!;
      final lateFriday = hours.at(day(4, 23));
      expect(lateFriday.status, OpeningStatus.open);
      expect(lateFriday.closesAt, day(5, 2));
      // Sabato all'una: aperto da venerdì sera.
      expect(hours.at(day(5, 1)).status, OpeningStatus.open);
      // Domenica all'una: aperto da sabato sera.
      expect(hours.at(day(6, 1)).status, OpeningStatus.open);
      expect(hours.at(day(6, 3)).status, OpeningStatus.closed);
    });

    test('00:00-24:00 tutti i giorni non chiude a mezzanotte', () {
      final hours = OpeningHours.parse('Mo-Su 00:00-24:00')!;
      final check = hours.at(monday(23, 50));
      expect(check.status, OpeningStatus.open);
      expect(check.closesAt!.isAfter(day(1, 0, 30)), isTrue);
    });

    test('le regole dopo prendono il posto di quelle prima', () {
      final hours = OpeningHours.parse('Mo-Sa 08:00-20:00; We off')!;
      expect(hours.at(day(2, 10)).status, OpeningStatus.closed);
      expect(hours.at(day(2, 10)).opensAt, day(3, 8));
      expect(hours.at(day(3, 10)).status, OpeningStatus.open);
      // La domenica non è citata: chiuso.
      expect(hours.at(day(6, 10)).status, OpeningStatus.closed);
    });

    test('le regole dei festivi si ignorano', () {
      final hours = OpeningHours.parse('Mo-Fr 09:00-18:00; PH off')!;
      expect(hours.at(monday(10)).status, OpeningStatus.open);
    });

    test('fasce senza giorni valgono tutti i giorni', () {
      final hours = OpeningHours.parse('10:00-22:00')!;
      expect(hours.at(day(6, 21)).status, OpeningStatus.open);
    });

    test('gli orari complessi non si indovinano', () {
      for (final raw in [
        'Mo-Fr 09:00-18:00; Jan off',
        'sunrise-sunset',
        'Mo-Fr 08:00-12:00, We 14:00-18:00',
        'Mo-Fr 09:00+',
        'Mo-Fr 09:00-18:00 "su appuntamento"',
        'Su[1] 10:00-12:00',
        'mo-fr 09:00-18:00',
        'PH off',
        '',
        null,
      ]) {
        expect(OpeningHours.parse(raw), isNull, reason: '$raw');
      }
    });
  });

  group('testi', () {
    final hours = OpeningHours.parse('Mo-Fr 09:00-12:30,15:00-19:00')!;

    test('aperto o chiuso adesso', () {
      expect(
        openingNowText(hours, monday(10)),
        'Aperto ora · chiude alle 12:30',
      );
      expect(
        openingNowText(hours, monday(20)),
        'Chiuso ora · apre domani alle 9:00',
      );
      expect(
        openingNowText(hours, day(4, 20)),
        'Chiuso ora · apre lunedì alle 9:00',
      );
      expect(openingNowText(null, monday(10)), isNull);
    });

    test('avviso sull\'arrivo', () {
      expect(arrivalOpeningWarning(hours, monday(10)), isNull);
      expect(
        arrivalOpeningWarning(hours, monday(13)),
        'Potrebbe essere chiuso quando arrivi: apre alle 15:00',
      );
      expect(
        arrivalOpeningWarning(hours, monday(18, 40)),
        'Chiude alle 19:00, poco dopo il tuo arrivo',
      );
      expect(
        arrivalOpeningWarning(OpeningHours.parse('24/7'), monday(3)),
        isNull,
      );
      expect(arrivalOpeningWarning(null, monday(13)), isNull);
    });
  });
}
