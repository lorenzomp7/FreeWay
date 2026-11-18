import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freeway/services/weather_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> forecast({
  int code = 0,
  double rain = 0,
  double temp = 15,
  List<num> chances = const [0, 10, 20],
  List<num>? temps,
}) => {
  'current': {
    'temperature_2m': temp,
    'precipitation': rain,
    'weather_code': code,
  },
  'hourly': {
    'precipitation_probability': chances,
    'temperature_2m': temps ?? [temp, temp, temp],
  },
};

void main() {
  test('bel tempo: nessun avviso', () {
    expect(WeatherService.warningFromForecast(forecast()), isNull);
  });

  test('pioggia in corso, prevista e neve', () {
    expect(
      WeatherService.warningFromForecast(forecast(code: 61)),
      startsWith('Pioggia in corso'),
    );
    expect(
      WeatherService.warningFromForecast(forecast(chances: [10, 70, 80])),
      startsWith('Pioggia probabile nelle prossime ore (80%)'),
    );
    expect(
      WeatherService.warningFromForecast(forecast(code: 73, temp: -1)),
      'Neve: rampe e marciapiedi possono essere scivolosi o coperti. '
      'Temperature vicine allo zero: possibile ghiaccio su rampe e '
      'marciapiedi.',
    );
  });

  test('caldo intenso suggerisce le fontanelle', () {
    expect(
      WeatherService.warningFromForecast(
        forecast(temp: 30, temps: [31, 34, 33]),
      ),
      contains('Caldo intenso (34 °C)'),
    );
  });

  test('chiede a Open-Meteo una volta per zona e tollera gli errori', () async {
    var calls = 0;
    final service = WeatherService(
      client: MockClient((request) async {
        calls++;
        expect(request.url.host, 'api.open-meteo.com');
        return http.Response(jsonEncode(forecast(code: 63)), 200);
      }),
    );
    const brescia = LatLng(45.5398, 10.2195);
    expect(await service.warningFor(brescia), startsWith('Pioggia in corso'));
    await service.warningFor(const LatLng(45.5401, 10.2197));
    expect(calls, 1);

    final down = WeatherService(
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(await down.warningFor(brescia), isNull);
  });
}
