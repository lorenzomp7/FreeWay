import 'package:shared_preferences/shared_preferences.dart';

/// Pendenza massima che si riesce a fare in sedia a rotelle.
enum MaxIncline {
  three(3, '3%'),
  six(6, '6%'),
  ten(10, '10%'),
  fifteen(15, '15%');

  const MaxIncline(this.percent, this.label);

  final int percent;
  final String label;
}

/// Altezza massima di un cordolo o di un gradino ribassato.
enum MaxKerb {
  three(0.03, '3 cm'),
  six(0.06, '6 cm'),
  ten(0.10, '10 cm');

  const MaxKerb(this.meters, this.label);

  final double meters;
  final String label;
}

/// Velocità personale: corregge i tempi calcolati dal servizio dei percorsi,
/// come il passo usato da Google Maps per le stime a piedi.
enum TravelPace {
  slow('Lenta', 0.75),
  normal('Normale', 1),
  fast('Veloce', 1.25);

  const TravelPace(this.label, this.factor);

  final String label;

  /// Rapporto con la velocità normale: i tempi si dividono per questo.
  final double factor;
}

/// "Opzioni del percorso", come "Route options" di Google Maps ma pensate
/// per la sedia a rotelle.
class RoutePreferences {
  const RoutePreferences({
    this.maxIncline = MaxIncline.six,
    this.maxKerb = MaxKerb.six,
    this.avoidRoughSurfaces = false,
    this.pace = TravelPace.normal,
  });

  final MaxIncline maxIncline;
  final MaxKerb maxKerb;

  /// Evita ciottoli, ghiaia e sterrato.
  final bool avoidRoughSurfaces;
  final TravelPace pace;

  static const RoutePreferences defaults = RoutePreferences();

  /// I limiti sono quelli predefiniti di OpenRouteService: non serve
  /// mandarli.
  bool get hasDefaultRestrictions =>
      maxIncline == MaxIncline.six &&
      maxKerb == MaxKerb.six &&
      !avoidRoughSurfaces;

  /// Cambiano il percorso (non solo i tempi).
  bool sameRestrictions(RoutePreferences other) =>
      maxIncline == other.maxIncline &&
      maxKerb == other.maxKerb &&
      avoidRoughSurfaces == other.avoidRoughSurfaces;

  RoutePreferences copyWith({
    MaxIncline? maxIncline,
    MaxKerb? maxKerb,
    bool? avoidRoughSurfaces,
    TravelPace? pace,
  }) => RoutePreferences(
    maxIncline: maxIncline ?? this.maxIncline,
    maxKerb: maxKerb ?? this.maxKerb,
    avoidRoughSurfaces: avoidRoughSurfaces ?? this.avoidRoughSurfaces,
    pace: pace ?? this.pace,
  );

  /// Limiti del profilo carrozzina di OpenRouteService
  /// (`options.profile_params.restrictions`).
  Map<String, Object> get orsRestrictions => {
    'maximum_incline': maxIncline.percent,
    'maximum_sloped_kerb': maxKerb.meters,
    if (avoidRoughSurfaces) ...{
      'surface_type': 'paving_stones',
      'smoothness_type': 'good',
    },
  };

  /// Riassunto breve delle scelte diverse da quelle predefinite.
  String get summary => [
    if (maxIncline != MaxIncline.six) 'pendenza max ${maxIncline.label}',
    if (maxKerb != MaxKerb.six) 'cordoli max ${maxKerb.label}',
    if (avoidRoughSurfaces) 'niente ciottoli',
    if (pace != TravelPace.normal) 'velocità ${pace.label.toLowerCase()}',
  ].join(' · ');

  static const String _key = 'freeway.route_preferences';

  static Future<RoutePreferences> load({
    Future<SharedPreferences> Function()? preferences,
  }) async {
    try {
      final prefs = await (preferences ?? SharedPreferences.getInstance)();
      final raw = prefs.getStringList(_key);
      if (raw == null || raw.length != 4) return defaults;
      T pick<T extends Enum>(List<T> values, String name, T fallback) =>
          values.firstWhere((v) => v.name == name, orElse: () => fallback);
      return RoutePreferences(
        maxIncline: pick(MaxIncline.values, raw[0], MaxIncline.six),
        maxKerb: pick(MaxKerb.values, raw[1], MaxKerb.six),
        avoidRoughSurfaces: raw[2] == 'true',
        pace: pick(TravelPace.values, raw[3], TravelPace.normal),
      );
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save({Future<SharedPreferences> Function()? preferences}) async {
    try {
      final prefs = await (preferences ?? SharedPreferences.getInstance)();
      await prefs.setStringList(_key, [
        maxIncline.name,
        maxKerb.name,
        '$avoidRoughSurfaces',
        pace.name,
      ]);
    } catch (_) {
      // Le scelte valgono comunque fino alla chiusura.
    }
  }
}
