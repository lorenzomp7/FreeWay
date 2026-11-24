import 'package:flutter/widgets.dart';

/// Tempi e curva delle animazioni, uguali in tutta l'app.
///
/// Brevi e con una sola curva, veloce all'inizio e morbida alla fine: l'app
/// risponde subito al tocco e si ferma senza scatti. Se nel sistema è attivo
/// «Riduci movimento» ([MediaQueryData.disableAnimations]) i passaggi sono
/// immediati: per chi soffre di vertigini o di nausea da movimento le
/// animazioni non sono un abbellimento ma un ostacolo.
abstract final class AppMotion {
  /// Cambio di stato di un controllo: selezione, interruttore, scheda.
  static const Duration quick = Duration(milliseconds: 150);

  /// Pannelli che entrano, escono o si spostano.
  static const Duration standard = Duration(milliseconds: 240);

  /// Spostamento della mappa verso un luogo o un percorso.
  static const Duration camera = Duration(milliseconds: 450);

  /// La curva di tutte le animazioni.
  static const Curve curve = Cubic(0.2, 0.9, 0.2, 1);

  /// Vero se l'utente ha chiesto di ridurre le animazioni.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], oppure zero se le animazioni sono ridotte.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// Stile per bottom sheet e finestre: quello predefinito, oppure nessuna
  /// animazione se le animazioni sono ridotte.
  static AnimationStyle? routeStyle(BuildContext context) =>
      reduced(context) ? AnimationStyle.noAnimation : null;
}
