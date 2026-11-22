import 'package:flutter/material.dart';

/// Modo di spostarsi scelto nelle indicazioni, come i mezzi di Google Maps
/// (auto, mezzi, a piedi…).
enum TravelMode {
  /// Evita gradini, pendenze e fondi sconnessi e gira intorno agli ostacoli
  /// segnalati.
  wheelchair('Sedia a rotelle', Icons.accessible_rounded),

  /// Percorso pedonale più veloce; gli ostacoli vengono solo contati.
  walking('A piedi', Icons.directions_walk_rounded),

  /// In auto fino a un parcheggio per disabili vicino alla destinazione, poi
  /// in sedia a rotelle fino all'ingresso.
  car('In auto', Icons.directions_car_rounded),

  /// Bus, tram, metro e treni (Transitous), con i tratti a piedi e i cambi
  /// accessibili in sedia a rotelle. In fondo all'elenco: i viaggi salvati
  /// usano il nome, non la posizione.
  transit('Mezzi pubblici', Icons.directions_transit_rounded);

  const TravelMode(this.label, this.icon);

  final String label;
  final IconData icon;
}
