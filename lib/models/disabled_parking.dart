import 'package:latlong2/latlong.dart';

/// Un parcheggio con posti riservati alle persone con disabilità, letto da
/// OpenStreetMap: un singolo stallo (`amenity=parking_space` +
/// `parking_space=disabled`) oppure un parcheggio con `capacity:disabled`.
class DisabledParking {
  const DisabledParking({
    required this.id,
    required this.position,
    this.name,
    this.spaces,
    this.fee,
    this.maxStay,
    this.isSingleSpace = false,
  });

  /// Tipo e id OpenStreetMap, per esempio `node/123`.
  final String id;
  final LatLng position;
  final String? name;

  /// Posti riservati, se indicati (`capacity:disabled` o `capacity`).
  final int? spaces;

  /// Tag `fee`: `yes`, `no` o `null`.
  final String? fee;

  /// Tag `maxstay`, per esempio `2 hours`.
  final String? maxStay;

  /// `true` per uno stallo singolo, `false` per un parcheggio con posti
  /// riservati.
  final bool isSingleSpace;

  /// Riga breve per la scheda: nome, posti, a pagamento.
  String get summary {
    final parts = <String>[
      if (name != null && name!.isNotEmpty) name!,
      if (spaces != null)
        spaces == 1 ? '1 posto riservato' : '$spaces posti riservati'
      else if (isSingleSpace)
        'Posto riservato',
      if (fee == 'yes') 'a pagamento',
      if (fee == 'no') 'gratuito',
      if (maxStay != null && maxStay!.isNotEmpty) 'sosta max $maxStay',
    ];
    return parts.isEmpty ? 'Parcheggio per disabili' : parts.join(' · ');
  }
}
