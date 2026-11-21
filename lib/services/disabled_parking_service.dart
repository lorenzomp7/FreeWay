import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/disabled_parking.dart';
import 'geo_utils.dart';

/// Cerca su OpenStreetMap (tramite Overpass) i parcheggi riservati alle
/// persone con disabilità: vicino a una destinazione, per la modalità "In
/// auto", oppure nella zona inquadrata, per il livello della mappa.
class DisabledParkingService {
  DisabledParkingService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static final Uri endpoint = Uri.https('overpass-api.de', '/api/interpreter');
  static const _timeout = Duration(seconds: 12);

  /// Distanza massima dalla destinazione per la modalità "In auto".
  static const int nearRadius = 500;

  /// Parcheggi al massimo nel livello della mappa.
  static const int maxResults = 150;

  final Map<String, List<DisabledParking>> _cache = {};

  /// Filtri Overpass sui parcheggi per disabili, per il blocco [area]
  /// (`around:...` o un rettangolo).
  @visibleForTesting
  static String buildQuery(String area, {int limit = maxResults}) =>
      '[out:json][timeout:10];('
      'nwr($area)["parking_space"="disabled"];'
      'nwr($area)["amenity"="parking_space"]["wheelchair"="designated"];'
      'nwr($area)["amenity"="parking"]["capacity:disabled"];'
      'nwr($area)["amenity"="parking"]["disabled"="designated"];'
      ');out center $limit;';

  /// Parcheggi entro [radius] metri da [point], dal più vicino. `null` se
  /// Overpass non risponde.
  Future<List<DisabledParking>?> near(
    LatLng point, {
    int radius = nearRadius,
  }) async {
    final lat = point.latitude.toStringAsFixed(5);
    final lng = point.longitude.toStringAsFixed(5);
    final found = await _load('around:$radius,$lat,$lng');
    if (found == null) return null;
    return sortByDistance(found, point);
  }

  /// Parcheggi nel rettangolo inquadrato. `null` se Overpass non risponde.
  Future<List<DisabledParking>?> inBounds(LatLng southWest, LatLng northEast) {
    // Arrotondato a ~100 m, così spostando di poco la mappa si riusa la
    // risposta precedente.
    String f(double v) => v.toStringAsFixed(3);
    return _load(
      '${f(southWest.latitude)},${f(southWest.longitude)},'
      '${f(northEast.latitude)},${f(northEast.longitude)}',
    );
  }

  Future<List<DisabledParking>?> _load(String area) async {
    final cached = _cache[area];
    if (cached != null) return cached;
    try {
      // Modulo semplice, senza intestazioni in più: nel browser non serve il
      // controllo preventivo CORS.
      final response = await _client
          .post(endpoint, body: {'data': buildQuery(area)})
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) return null;
      final result = parse(data);
      if (_cache.length > 40) _cache.remove(_cache.keys.first);
      _cache[area] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static List<DisabledParking> parse(Map<String, dynamic> data) {
    final elements = data['elements'];
    if (elements is! List) return const [];
    final result = <DisabledParking>[];
    final seen = <String>{};
    for (final element in elements.whereType<Map<String, dynamic>>()) {
      final tags = element['tags'];
      if (tags is! Map<String, dynamic>) continue;
      if (!isDisabledParking(tags)) continue;
      final id = '${element['type']}/${element['id']}';
      if (!seen.add(id)) continue;
      final center = element['center'];
      final source = center is Map<String, dynamic> ? center : element;
      final lat = source['lat'];
      final lon = source['lon'];
      if (lat is! num || lon is! num) continue;
      final single =
          tags['amenity'] == 'parking_space' ||
          tags['parking_space'] == 'disabled';
      result.add(
        DisabledParking(
          id: id,
          position: LatLng(lat.toDouble(), lon.toDouble()),
          name: tags['name'] as String?,
          spaces: _spaces(tags, single),
          fee: tags['fee'] is String ? tags['fee'] as String : null,
          maxStay: tags['maxstay'] as String?,
          isSingleSpace: single,
        ),
      );
    }
    return result;
  }

  /// Un elemento con posti per disabili, escludendo `capacity:disabled=0` o
  /// `no` (parcheggi che dichiarano di non averne).
  @visibleForTesting
  static bool isDisabledParking(Map<String, dynamic> tags) {
    if (tags['parking_space'] == 'disabled') return true;
    if (tags['amenity'] == 'parking_space' &&
        tags['wheelchair'] == 'designated') {
      return true;
    }
    if (tags['amenity'] != 'parking') return false;
    if (tags['disabled'] == 'designated') return true;
    final capacity = tags['capacity:disabled'];
    if (capacity is! String) return false;
    return capacity == 'yes' || (int.tryParse(capacity) ?? 0) > 0;
  }

  static int? _spaces(Map<String, dynamic> tags, bool single) {
    final disabled = int.tryParse('${tags['capacity:disabled'] ?? ''}');
    if (disabled != null && disabled > 0) return disabled;
    if (single) {
      final capacity = int.tryParse('${tags['capacity'] ?? ''}');
      return capacity != null && capacity > 0 ? capacity : null;
    }
    return null;
  }

  /// Ordina dal più vicino a [point].
  static List<DisabledParking> sortByDistance(
    List<DisabledParking> parkings,
    LatLng point,
  ) {
    final sorted = List<DisabledParking>.of(parkings);
    sorted.sort(
      (a, b) => haversineDistance(
        a.position,
        point,
      ).compareTo(haversineDistance(b.position, point)),
    );
    return sorted;
  }

  void dispose() => _client.close();
}
