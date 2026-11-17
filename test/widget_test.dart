import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/models/route_option.dart';
import 'package:freeway/services/geocoding_service.dart';
import 'package:freeway/services/instruction_translator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('InstructionTranslator', () {
    test('traduce una svolta in italiano', () {
      const translator = InstructionTranslator('it');
      expect(
        translator.translate('turn|left|Via Roma'),
        'Svolta a sinistra su Via Roma',
      );
    });

    test("traduce l'arrivo in inglese", () {
      const translator = InstructionTranslator('en');
      expect(translator.translate('arrive||'), 'You have arrived at destination');
    });
  });

  test('RouteOption formatta distanza, durata e punteggio', () {
    final route = RouteOption(
      points: const [LatLng(45.46, 9.19)],
      distance: 1530,
      duration: 3900,
      steps: const [],
      index: 0,
    )..obstacleCount = 1;
    expect(route.distanceText, '1.5 km');
    expect(route.durationText, '1h 5min');
    expect(route.accessibilityScore, 85);
  });

  test('formatPlace usa via e città di Nominatim', () {
    final label = formatPlace({
      'display_name': 'Via Roma, Brescia, Lombardia, Italia',
      'address': {'road': 'Via Roma', 'city': 'Brescia', 'county': 'Brescia'},
    });
    expect(label.title, 'Via Roma');
    expect(label.subtitle, 'Brescia, Brescia');
  });
}
