import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/place_accessibility.dart';
import 'geo_utils.dart';

/// Legge da OpenStreetMap (tramite Overpass) accessibilità, ingressi e
/// parcheggi per disabili di un luogo trovato con la ricerca.
class PlaceAccessibilityService {
  PlaceAccessibilityService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, PlaceAccessibility> _cache = {};

  static const _timeout = Duration(seconds: 12);
  static final Uri endpoint = Uri.https('overpass-api.de', '/api/interpreter');

  /// Città, vie e simili non hanno ingressi: non serve chiedere.
  static bool supports(Map<String, dynamic> place) {
    final kind = place['kind'];
    return place['osm_type'] is String &&
        place['osm_id'] is num &&
        kind != 'city' &&
        kind != 'street';
  }

  /// La richiesta è un semplice modulo, senza intestazioni in più: nel
  /// browser così non serve il controllo preventivo CORS.
  ///
  /// `null` se il luogo non ha un elemento OpenStreetMap o se Overpass non
  /// risponde: la scheda funziona anche senza.
  Future<PlaceAccessibility?> load(
    Map<String, dynamic> place,
    LatLng position,
  ) async {
    if (!supports(place)) return null;
    final type = place['osm_type'] as String;
    final id = (place['osm_id'] as num).toInt();
    final key = '$type$id';
    final cached = _cache[key];
    if (cached != null) return cached;
    final query = buildQuery(type, id);
    if (query == null) return null;
    try {
      final response = await _client
          .post(endpoint, body: {'data': query})
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) return null;
      final result = parse(data, type, id, position);
      _cache[key] = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Query Overpass: i tag del luogo, gli ingressi del suo edificio (o entro
  /// 40 m da un punto) e i parcheggi per disabili entro 150 m.
  @visibleForTesting
  static String? buildQuery(String osmType, int id) {
    const parking =
        'nwr(around.p:150)["amenity"="parking"]'
        '["capacity:disabled"];out center 3;'
        'nwr(around.p:150)["parking_space"="disabled"];out center 3;';
    switch (osmType) {
      case 'N':
        return '[out:json][timeout:10];node($id)->.p;.p out tags;'
            '.p is_in->.a;way(pivot.a)["building"]->.b;'
            '(node(w.b)["entrance"];node(around.p:40)["entrance"];);out;'
            '$parking';
      case 'W':
        return '[out:json][timeout:10];way($id)->.p;.p out tags center;'
            'node(w.p)["entrance"];out;$parking';
      case 'R':
        return '[out:json][timeout:10];relation($id)->.p;.p out tags center;'
            'way(r.p)->.w;node(w.w)["entrance"];out;$parking';
      default:
        return null;
    }
  }

  @visibleForTesting
  static PlaceAccessibility parse(
    Map<String, dynamic> data,
    String osmType,
    int id,
    LatLng position,
  ) {
    final elements = data['elements'];
    if (elements is! List) return const PlaceAccessibility();
    const typeNames = {'N': 'node', 'W': 'way', 'R': 'relation'};
    Map<String, dynamic> placeTags = const {};
    final entrances = <PlaceEntrance>[];
    final seenEntrances = <int>{};
    double? parking;

    for (final element in elements.whereType<Map<String, dynamic>>()) {
      final tags = element['tags'];
      if (tags is! Map<String, dynamic>) continue;
      final elementType = element['type'];
      final elementId = (element['id'] as num?)?.toInt();
      final point = _point(element);

      if (elementType == typeNames[osmType] && elementId == id) {
        placeTags = tags;
      } else if (tags['entrance'] != null && point != null) {
        if (elementId != null && !seenEntrances.add(elementId)) continue;
        entrances.add(
          PlaceEntrance(
            position: point,
            wheelchair: _value(tags['wheelchair']),
            type: tags['entrance'] as String?,
            name: (tags['name'] ?? tags['ref']) as String?,
          ),
        );
      } else if (_isDisabledParking(tags) && point != null) {
        final meters = haversineDistance(position, point);
        if (parking == null || meters < parking) parking = meters;
      }
    }

    return PlaceAccessibility(
      wheelchair: _value(placeTags['wheelchair']),
      toilets: _value(placeTags['toilets:wheelchair']),
      description:
          (placeTags['wheelchair:description:it'] ??
                  placeTags['wheelchair:description'])
              as String?,
      entrances: entrances,
      disabledParkingMeters: parking,
    );
  }

  static LatLng? _point(Map<String, dynamic> element) {
    final center = element['center'];
    final source = center is Map<String, dynamic> ? center : element;
    final lat = source['lat'];
    final lon = source['lon'];
    if (lat is! num || lon is! num) return null;
    return LatLng(lat.toDouble(), lon.toDouble());
  }

  /// Solo i valori che sappiamo spiegare; altri valori contano come assenti.
  static String? _value(Object? raw) {
    const known = {'yes', 'limited', 'no', 'designated'};
    if (raw is! String || !known.contains(raw)) return null;
    return raw == 'designated' ? 'yes' : raw;
  }

  static bool _isDisabledParking(Map<String, dynamic> tags) {
    if (tags['parking_space'] == 'disabled') return true;
    final capacity = tags['capacity:disabled'];
    if (capacity is! String) return false;
    return capacity == 'yes' || (int.tryParse(capacity) ?? 0) > 0;
  }

  void dispose() => _client.close();
}
