import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Avvisi meteo utili a chi si muove a piedi o in sedia a rotelle, come
/// "The road ahead may be flooded" di Google Maps. Dati di Open-Meteo,
/// gratuito e senza chiave.
class WeatherService {
  WeatherService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, (DateTime, String?)> _cache = {};

  /// Per quanto vale una risposta per la stessa zona.
  static const Duration cacheLifetime = Duration(minutes: 20);

  /// Codici WMO di pioggia, rovesci e temporali.
  static const Set<int> _rainCodes = {
    51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99, //
  };

  /// Codici WMO di neve.
  static const Set<int> _snowCodes = {71, 73, 75, 77, 85, 86};

  /// L'avviso per chi parte da [position], o `null` se il tempo non crea
  /// problemi o se il servizio non risponde.
  Future<String?> warningFor(LatLng position) async {
    final key =
        '${position.latitude.toStringAsFixed(2)},'
        '${position.longitude.toStringAsFixed(2)}';
    final cached = _cache[key];
    if (cached != null && _clock().difference(cached.$1) < cacheLifetime) {
      return cached.$2;
    }
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': position.latitude.toStringAsFixed(4),
        'longitude': position.longitude.toStringAsFixed(4),
        'current': 'temperature_2m,precipitation,weather_code',
        'hourly': 'precipitation_probability,temperature_2m',
        'forecast_hours': '3',
        'timezone': 'auto',
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) return null;
      final warning = warningFromForecast(data);
      _cache[key] = (_clock(), warning);
      return warning;
    } catch (_) {
      return null;
    }
  }

  /// Testo dell'avviso ricavato dalla risposta di Open-Meteo.
  @visibleForTesting
  static String? warningFromForecast(Map<String, dynamic> data) {
    final current = data['current'];
    final hourly = data['hourly'];
    final code = current is Map
        ? (current['weather_code'] as num?)?.toInt()
        : null;
    final rainNow = current is Map
        ? (current['precipitation'] as num?)?.toDouble() ?? 0
        : 0.0;
    final temperatures = <double>[
      if (current is Map && current['temperature_2m'] is num)
        (current['temperature_2m'] as num).toDouble(),
      ..._numbers(hourly is Map ? hourly['temperature_2m'] : null),
    ];
    final chances = _numbers(
      hourly is Map ? hourly['precipitation_probability'] : null,
    );

    final parts = <String>[];
    if (code != null && _snowCodes.contains(code)) {
      parts.add(
        'Neve: rampe e marciapiedi possono essere scivolosi o coperti.',
      );
    } else if ((code != null && _rainCodes.contains(code)) || rainNow > 0.1) {
      parts.add(
        'Pioggia in corso: rampe, tombini e pavimenti lisci possono essere '
        'scivolosi.',
      );
    } else if (chances.isNotEmpty && chances.reduce(math.max) >= 60) {
      parts.add(
        'Pioggia probabile nelle prossime ore '
        '(${chances.reduce(math.max).round()}%): rampe e pavimenti lisci '
        'possono diventare scivolosi.',
      );
    }
    if (temperatures.isNotEmpty) {
      final coldest = temperatures.reduce(math.min);
      final hottest = temperatures.reduce(math.max);
      if (coldest <= 1) {
        parts.add(
          'Temperature vicine allo zero: possibile ghiaccio su rampe '
          'e marciapiedi.',
        );
      } else if (hottest >= 32) {
        parts.add(
          'Caldo intenso (${hottest.round()} °C): porta acqua e cerca '
          'le fontanelle lungo il percorso.',
        );
      }
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  static List<double> _numbers(Object? values) => values is List
      ? values.whereType<num>().map((v) => v.toDouble()).toList()
      : const [];

  void dispose() => _client.close();
}
