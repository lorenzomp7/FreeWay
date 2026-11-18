import 'package:latlong2/latlong.dart';

import '../models/route_option.dart';
import 'geo_utils.dart';

/// Dati aggiuntivi chiesti a OpenRouteService per ogni percorso.
const List<String> kOrsExtraInfo = ['steepness', 'surface', 'waytype'];

/// Fondi stradali di OpenRouteService difficili in sedia a rotelle, con il
/// nome italiano. https://giscience.github.io/openrouteservice/api-reference/endpoints/directions/extra-info/
const Map<int, String> _roughSurfaces = {
  2: 'non asfaltato',
  5: 'ciottoli',
  9: 'ghiaia fine',
  10: 'ghiaia',
  11: 'sterrato',
  12: 'terra',
  13: 'ghiaccio',
  15: 'sabbia',
  16: 'trucioli',
  17: 'erba',
  18: 'grigliato erboso',
};

const int _waytypeSteps = 8;
const int _waytypeConstruction = 10;

/// Metri minimi perché una difficoltà venga segnalata: brevi tratti sono
/// spesso solo imprecisioni dei dati.
const double _minSteepMeters = 5;
const double _minModerateMeters = 30;
const double _minRoughMeters = 10;

/// Ricava gli avvisi dal campo `extras` di una risposta di OpenRouteService.
///
/// Ogni valore è `[da, a, codice]`, con `da` e `a` indici dei punti di
/// [points]. Le pendenze vanno da -5 a 5: ±2 è il 4–6%, ±3 o più dal 7%.
List<RouteWarning> parseRouteWarnings(
  Map<String, dynamic> extras,
  List<LatLng> points,
) {
  var steps = 0.0;
  var construction = 0.0;
  var steepUp = 0.0;
  var steepDown = 0.0;
  var moderate = 0.0;
  var rough = 0.0;
  final roughKinds = <String>[];

  for (final (from, to, value) in _ranges(extras['waytype'])) {
    final meters = _length(points, from, to);
    if (value == _waytypeSteps) steps += meters;
    if (value == _waytypeConstruction) construction += meters;
  }
  for (final (from, to, value) in _ranges(extras['steepness'])) {
    final meters = _length(points, from, to);
    if (value >= 3) {
      steepUp += meters;
    } else if (value <= -3) {
      steepDown += meters;
    } else if (value.abs() == 2) {
      moderate += meters;
    }
  }
  for (final (from, to, value) in _ranges(extras['surface'])) {
    final name = _roughSurfaces[value];
    if (name == null) continue;
    rough += _length(points, from, to);
    if (!roughKinds.contains(name)) roughKinds.add(name);
  }

  return [
    if (steps > 0) RouteWarning(RouteWarningKind.steps, steps),
    if (steepUp >= _minSteepMeters)
      RouteWarning(RouteWarningKind.steepUp, steepUp),
    if (steepDown >= _minSteepMeters)
      RouteWarning(RouteWarningKind.steepDown, steepDown),
    if (construction > 0)
      RouteWarning(RouteWarningKind.construction, construction),
    if (rough >= _minRoughMeters)
      RouteWarning(
        RouteWarningKind.roughSurface,
        rough,
        detail: roughKinds.join(', '),
      ),
    if (moderate >= _minModerateMeters)
      RouteWarning(RouteWarningKind.moderateSlope, moderate),
  ];
}

Iterable<(int, int, int)> _ranges(Object? extra) sync* {
  if (extra is! Map) return;
  final values = extra['values'];
  if (values is! List) return;
  for (final value in values) {
    if (value is List &&
        value.length >= 3 &&
        value[0] is num &&
        value[1] is num &&
        value[2] is num) {
      yield (
        (value[0] as num).toInt(),
        (value[1] as num).toInt(),
        (value[2] as num).toInt(),
      );
    }
  }
}

double _length(List<LatLng> points, int from, int to) {
  if (points.length < 2) return 0;
  final start = from.clamp(0, points.length - 1);
  final end = to.clamp(0, points.length - 1);
  var meters = 0.0;
  for (var i = start; i < end; i++) {
    meters += haversineDistance(points[i], points[i + 1]);
  }
  return meters;
}
