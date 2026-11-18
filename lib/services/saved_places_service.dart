import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'recent_places_service.dart';

/// Tipo di luogo salvato, come "Home", "Work" e le liste di Google Maps.
enum SavedKind { home, work, other }

/// Un luogo salvato con un nome: "Casa", "Lavoro" o un nome scelto.
class SavedPlace {
  const SavedPlace({
    required this.kind,
    required this.label,
    required this.place,
  });

  final SavedKind kind;
  final String label;

  /// Il luogo nello stesso formato dei suggerimenti di ricerca.
  final Map<String, dynamic> place;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'label': label,
    'place': place,
  };

  static SavedPlace? fromJson(Object? data) {
    if (data is! Map) return null;
    final place = data['place'];
    final label = data['label'];
    if (place is! Map<String, dynamic> ||
        label is! String ||
        place['lat'] is! num ||
        place['lon'] is! num) {
      return null;
    }
    final kind = SavedKind.values.firstWhere(
      (k) => k.name == data['kind'],
      orElse: () => SavedKind.other,
    );
    return SavedPlace(kind: kind, label: label, place: place);
  }
}

/// Casa, Lavoro e altri luoghi salvati, sul dispositivo.
class SavedPlacesService {
  SavedPlacesService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const String storageKey = 'freeway.saved_places';
  static const int maxPlaces = 50;
  static const int maxLabelLength = 40;

  List<SavedPlace> _places = [];

  List<SavedPlace> get places => List.unmodifiable(_places);

  SavedPlace? get home => _first(SavedKind.home);
  SavedPlace? get work => _first(SavedKind.work);
  List<SavedPlace> get others =>
      _places.where((p) => p.kind == SavedKind.other).toList();

  SavedPlace? _first(SavedKind kind) {
    for (final place in _places) {
      if (place.kind == kind) return place;
    }
    return null;
  }

  Future<List<SavedPlace>> load() async {
    try {
      final raw = (await _preferences()).getString(storageKey);
      if (raw == null) return places;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _places = decoded.map(SavedPlace.fromJson).nonNulls.toList();
      }
    } catch (_) {
      _places = [];
    }
    return places;
  }

  /// Salva [place] come Casa, Lavoro o con il nome [label]. Casa e Lavoro
  /// sostituiscono quelli di prima; un luogo già salvato con un nome lo
  /// cambia.
  Future<List<SavedPlace>> save(
    Map<String, dynamic> place,
    SavedKind kind, {
    String? label,
  }) async {
    final name = switch (kind) {
      SavedKind.home => 'Casa',
      SavedKind.work => 'Lavoro',
      SavedKind.other => _cleanLabel(label ?? '${place['name'] ?? 'Luogo'}'),
    };
    final entry = SavedPlace(
      kind: kind,
      label: name,
      place: {
        'name': place['name'] ?? place['display_name'],
        'display_name': place['display_name'] ?? place['name'],
        'lat': double.parse('${place['lat']}'),
        'lon': double.parse('${place['lon']}'),
        if (place['address'] is Map) 'address': place['address'],
        if (place['kind'] != null) 'kind': place['kind'],
        if (place['osm_type'] != null) 'osm_type': place['osm_type'],
        if (place['osm_id'] != null) 'osm_id': place['osm_id'],
      },
    );
    _places = [
      entry,
      ..._places.where(
        (p) => kind == SavedKind.other
            ? !(p.kind == SavedKind.other &&
                  RecentPlacesService.isSamePlace(p.place, entry.place))
            : p.kind != kind,
      ),
    ].take(maxPlaces).toList();
    await _save();
    return places;
  }

  Future<List<SavedPlace>> remove(SavedPlace saved) async {
    _places = _places
        .where(
          (p) =>
              !(p.kind == saved.kind &&
                  p.label == saved.label &&
                  RecentPlacesService.isSamePlace(p.place, saved.place)),
        )
        .toList();
    await _save();
    return places;
  }

  /// Etichette con cui [place] è salvato ("Casa", "Ufficio di Anna"…).
  List<SavedPlace> savedAs(Map<String, dynamic> place) => _places
      .where((p) => RecentPlacesService.isSamePlace(p.place, place))
      .toList();

  /// Luoghi salvati il cui nome o indirizzo contiene tutte le parole di
  /// [query].
  List<SavedPlace> matching(String query, {int limit = 3}) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'[\s,]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    return _places
        .where((saved) {
          final address = saved.place['address'];
          final text = [
            saved.label,
            saved.place['name'],
            if (address is Map) ...address.values,
          ].whereType<Object>().join(' ').toLowerCase();
          return words.every(text.contains);
        })
        .take(limit)
        .toList();
  }

  static String _cleanLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'Luogo salvato';
    return trimmed.length > maxLabelLength
        ? trimmed.substring(0, maxLabelLength)
        : trimmed;
  }

  Future<void> _save() async {
    try {
      await (await _preferences()).setString(
        storageKey,
        jsonEncode([for (final p in _places) p.toJson()]),
      );
    } catch (_) {
      // Senza archivio i luoghi restano solo in memoria.
    }
  }
}
