import 'package:latlong2/latlong.dart';

/// Singola manovra restituita da OSRM.
///
/// [instruction] è codificata come `tipo|modificatore|nome via` e viene
/// tradotta da `InstructionTranslator`.
class RouteStep {
  RouteStep({
    required this.instruction,
    required this.location,
    required this.maneuverType,
    required this.modifier,
    this.streetName = '',
    this.distance = 0,
    this.duration = 0,
  });

  final String instruction;
  final LatLng location;
  final String maneuverType;
  final String modifier;
  final String streetName;
  final double distance;
  final double duration;
}

/// Tipo di difficoltà lungo un percorso, ricavata dai dati di
/// OpenRouteService (pendenza, fondo stradale e tipo di via).
enum RouteWarningKind {
  steps,
  steepUp,
  steepDown,
  moderateSlope,
  roughSurface,
  construction,
}

/// Una difficoltà sul percorso con i metri che copre, come gli avvisi
/// "This route has stairs" o "Steep hill" delle indicazioni di Google Maps.
class RouteWarning {
  const RouteWarning(this.kind, this.meters, {this.detail = ''});

  final RouteWarningKind kind;
  final double meters;

  /// Per il fondo stradale: i tipi trovati, per esempio "ghiaia, sterrato".
  final String detail;

  /// Difficoltà che può rendere il percorso impraticabile in sedia a rotelle.
  bool get isHard =>
      kind != RouteWarningKind.moderateSlope &&
      kind != RouteWarningKind.roughSurface;

  String get _length => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
      : '${(meters / 5).ceil() * 5} m';

  /// Testo breve, per la scheda del percorso.
  String get shortLabel {
    switch (kind) {
      case RouteWarningKind.steps:
        return 'Gradini';
      case RouteWarningKind.steepUp:
        return 'Salita ripida';
      case RouteWarningKind.steepDown:
        return 'Discesa ripida';
      case RouteWarningKind.moderateSlope:
        return 'Pendenza';
      case RouteWarningKind.roughSurface:
        return 'Fondo sconnesso';
      case RouteWarningKind.construction:
        return 'Lavori';
    }
  }

  /// Testo completo, per l'elenco sotto le schede e per i lettori di schermo.
  String get label {
    switch (kind) {
      case RouteWarningKind.steps:
        return 'Gradini o scale per $_length';
      case RouteWarningKind.steepUp:
        return 'Salita ripida (oltre il 7%) per $_length';
      case RouteWarningKind.steepDown:
        return 'Discesa ripida (oltre il 7%) per $_length';
      case RouteWarningKind.moderateSlope:
        return 'Pendenza del 4–6% per $_length';
      case RouteWarningKind.roughSurface:
        return detail.isEmpty
            ? 'Fondo sconnesso per $_length'
            : 'Fondo sconnesso ($detail) per $_length';
      case RouteWarningKind.construction:
        return 'Tratto in costruzione per $_length';
    }
  }
}

/// Percorso pedonale proposto all'utente.
class RouteOption {
  RouteOption({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
    required this.index,
  });

  final List<LatLng> points;

  /// Distanza in metri.
  final double distance;

  /// Durata in secondi.
  final double duration;
  final List<RouteStep> steps;
  final int index;

  int obstacleCount = 0;
  bool isRecommended = false;
  String label = '';

  /// Difficoltà note lungo il tragitto, dalla più grave.
  List<RouteWarning> warnings = const [];

  /// `true` se il servizio ha fornito pendenze e fondi stradali: senza questi
  /// dati (OSRM) l'assenza di avvisi non vuol dire che non ci siano difficoltà.
  bool hasTerrainData = false;

  int get hardWarningCount => warnings.where((w) => w.isHard).length;

  String get distanceText {
    if (distance >= 1000) return '${(distance / 1000).toStringAsFixed(1)} km';
    return '${distance.round()} m';
  }

  String get durationText {
    final minutes = (duration / 60).round();
    if (minutes >= 60) return '${minutes ~/ 60}h ${minutes % 60}min';
    return '$minutes min';
  }

  /// Punteggio di accessibilità (0-100) in base agli ostacoli segnalati e
  /// alle difficoltà gravi (gradini, salite ripide, lavori) sul tragitto.
  int get accessibilityScore {
    final int base;
    switch (obstacleCount) {
      case 0:
        base = 100;
      case 1:
        base = 85;
      case 2:
        base = 65;
      case 3:
        base = 45;
      default:
        base = 30;
    }
    return (base - 15 * hardWarningCount).clamp(10, 100);
  }
}
