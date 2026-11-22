import 'package:latlong2/latlong.dart';

/// Se in sedia a rotelle si può salire su un mezzo, secondo i dati
/// dell'azienda di trasporto (campo `wheelchair_accessible` del GTFS).
enum TransitAccess { accessible, notAccessible, unknown }

/// Tipo di mezzo, semplificato dalle modalità di MOTIS.
enum TransitVehicle {
  walk('a piedi', 'on foot'),
  bus('bus', 'bus'),
  tram('tram', 'tram'),
  metro('metro', 'metro'),
  train('treno', 'train'),
  ferry('traghetto', 'ferry'),
  cableCar('funivia', 'cable car'),
  other('mezzo', 'vehicle');

  const TransitVehicle(this.it, this.en);

  final String it;
  final String en;

  /// Dalla modalità di MOTIS (`BUS`, `SUBWAY`, `REGIONAL_RAIL`…).
  static TransitVehicle fromMode(String? mode) {
    switch (mode) {
      case 'WALK':
        return walk;
      case 'BUS':
      case 'COACH':
        return bus;
      case 'TRAM':
        return tram;
      case 'SUBWAY':
      case 'METRO':
        return metro;
      case 'RAIL':
      case 'HIGHSPEED_RAIL':
      case 'LONG_DISTANCE':
      case 'NIGHT_RAIL':
      case 'REGIONAL_FAST_RAIL':
      case 'REGIONAL_RAIL':
      case 'SUBURBAN':
        return train;
      case 'FERRY':
        return ferry;
      case 'FUNICULAR':
      case 'AERIAL_LIFT':
      case 'AREAL_LIFT':
      case 'CABLE_CAR':
        return cableCar;
      default:
        return other;
    }
  }

  String get emoji => switch (this) {
    walk => '🚶',
    bus => '🚌',
    tram => '🚊',
    metro => '🚇',
    train => '🚆',
    ferry => '⛴️',
    cableCar => '🚡',
    other => '🚏',
  };
}

/// Un tratto di un viaggio con i mezzi pubblici: a piedi oppure su un mezzo.
class TransitLeg {
  const TransitLeg({
    required this.vehicle,
    required this.fromName,
    required this.toName,
    required this.departure,
    required this.arrival,
    required this.points,
    this.line = '',
    this.headsign = '',
    this.agency = '',
    this.access = TransitAccess.unknown,
    this.distance = 0,
    this.stops = 0,
  });

  final TransitVehicle vehicle;

  /// Nome della linea, per esempio "10", "M1" o "R4".
  final String line;

  /// Direzione scritta sul mezzo.
  final String headsign;
  final String fromName;
  final String toName;
  final DateTime departure;
  final DateTime arrival;
  final List<LatLng> points;
  final String agency;
  final TransitAccess access;

  /// Metri, solo per i tratti a piedi.
  final double distance;

  /// Fermate intermedie, solo per i mezzi.
  final int stops;

  bool get isWalk => vehicle == TransitVehicle.walk;

  Duration get duration => arrival.difference(departure);

  /// "Bus 10", "Metro M1", "Treno R4"; senza linea solo il tipo di mezzo.
  String get title {
    final name = vehicle.it[0].toUpperCase() + vehicle.it.substring(1);
    return line.isEmpty ? name : '$name $line';
  }
}

/// Riassunto dell'accessibilità dei mezzi di un viaggio.
TransitAccess overallAccess(List<TransitLeg> legs) {
  final rides = legs.where((l) => !l.isWalk);
  if (rides.any((l) => l.access == TransitAccess.notAccessible)) {
    return TransitAccess.notAccessible;
  }
  if (rides.isNotEmpty &&
      rides.every((l) => l.access == TransitAccess.accessible)) {
    return TransitAccess.accessible;
  }
  return TransitAccess.unknown;
}
