import 'package:latlong2/latlong.dart';

/// Un ingresso di un edificio segnato su OpenStreetMap (`entrance=*`).
class PlaceEntrance {
  const PlaceEntrance({
    required this.position,
    this.wheelchair,
    this.type,
    this.name,
  });

  final LatLng position;

  /// `yes`, `limited`, `no` o `null` se non indicato.
  final String? wheelchair;

  /// Valore di `entrance`: `main`, `yes`, `service`, `emergency`…
  final String? type;
  final String? name;

  bool get isAccessible => wheelchair == 'yes' || wheelchair == 'limited';
  bool get isNotAccessible => wheelchair == 'no';
  bool get isMain => type == 'main';
}

/// Accessibilità di un luogo secondo OpenStreetMap, come le voci "Accessible
/// entrance / restroom / parking" della scheda di Google Maps.
class PlaceAccessibility {
  const PlaceAccessibility({
    this.wheelchair,
    this.toilets,
    this.description,
    this.entrances = const [],
    this.disabledParkingMeters,
  });

  /// Tag `wheelchair` del luogo: `yes`, `limited`, `no` o `null`.
  final String? wheelchair;

  /// Tag `toilets:wheelchair`: `yes`, `no` o `null`.
  final String? toilets;

  /// Tag `wheelchair:description`, se presente.
  final String? description;
  final List<PlaceEntrance> entrances;

  /// Distanza del parcheggio per disabili più vicino, se ce n'è uno entro
  /// 150 m.
  final double? disabledParkingMeters;

  bool get hasData =>
      wheelchair != null ||
      toilets != null ||
      description != null ||
      entrances.isNotEmpty ||
      disabledParkingMeters != null;

  /// L'ingresso verso cui portare il percorso: prima uno accessibile in sedia
  /// a rotelle, poi uno parzialmente accessibile, poi l'ingresso principale
  /// se non è segnato come inaccessibile. `null` se nessuno va bene.
  PlaceEntrance? get bestEntrance {
    PlaceEntrance? pick(bool Function(PlaceEntrance e) test) {
      for (final entrance in entrances) {
        if (test(entrance)) return entrance;
      }
      return null;
    }

    return pick((e) => e.wheelchair == 'yes' && e.isMain) ??
        pick((e) => e.wheelchair == 'yes') ??
        pick((e) => e.wheelchair == 'limited') ??
        pick((e) => e.isMain && e.wheelchair == null);
  }

  /// Ci sono ingressi segnati ma tutti inaccessibili.
  bool get allEntrancesInaccessible =>
      entrances.isNotEmpty && entrances.every((e) => e.isNotAccessible);
}
