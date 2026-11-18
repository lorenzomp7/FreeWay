import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/travel_mode.dart';

/// Navigazione rimasta a metà: dove si stava andando e con quale mezzo.
class PendingTrip {
  const PendingTrip({
    required this.destination,
    required this.label,
    required this.mode,
    required this.startedAt,
  });

  final LatLng destination;
  final String label;
  final TravelMode mode;
  final DateTime startedAt;

  Map<String, dynamic> toJson() => {
    'lat': destination.latitude,
    'lon': destination.longitude,
    'label': label,
    'mode': mode.name,
    'startedAt': startedAt.toIso8601String(),
  };

  static PendingTrip? fromJson(Object? data) {
    if (data is! Map) return null;
    final lat = data['lat'];
    final lon = data['lon'];
    final label = data['label'];
    final started = DateTime.tryParse('${data['startedAt']}');
    if (lat is! num || lon is! num || label is! String || started == null) {
      return null;
    }
    final mode = TravelMode.values.firstWhere(
      (m) => m.name == data['mode'],
      orElse: () => TravelMode.wheelchair,
    );
    return PendingTrip(
      destination: LatLng(lat.toDouble(), lon.toDouble()),
      label: label,
      mode: mode,
      startedAt: started,
    );
  }
}

/// Ricorda la navigazione in corso, come "Still heading to…?" di Google
/// Maps: se l'app si chiude prima dell'arrivo, alla riapertura si propone di
/// riprendere.
class TripResumeService {
  TripResumeService({Future<SharedPreferences> Function()? preferences})
    : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  static const String storageKey = 'freeway.pending_trip';

  /// Oltre questo tempo il viaggio è considerato concluso o abbandonato.
  static const Duration maxAge = Duration(hours: 3);

  Future<void> save(PendingTrip trip) async {
    try {
      await (await _preferences()).setString(
        storageKey,
        jsonEncode(trip.toJson()),
      );
    } catch (_) {
      // Senza archivio non si potrà riprendere: nessun altro effetto.
    }
  }

  /// Il viaggio da riprendere, o `null` se non c'è o è troppo vecchio.
  Future<PendingTrip?> load({DateTime? now}) async {
    try {
      final raw = (await _preferences()).getString(storageKey);
      if (raw == null) return null;
      final trip = PendingTrip.fromJson(jsonDecode(raw));
      final age = (now ?? DateTime.now()).difference(
        trip?.startedAt ?? DateTime(2000),
      );
      if (trip == null || age > maxAge || age.isNegative) {
        await clear();
        return null;
      }
      return trip;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      await (await _preferences()).remove(storageKey);
    } catch (_) {
      // Niente da fare.
    }
  }
}
