import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colori principali del brand FREE WAY.
class AppPalette {
  static const Color primary = Color(0xFFEC0414);
  static const Color primaryDark = Color(0xFFC00310);
  static const Color primaryLight = Color(0xFFFF5566);
  static const Color accent = Color(0xFF3EC8D8);
  static const Color tertiary = Color(0xFF00B368);
  static const Color onAccent = Color(0xFF04252A);
  static const Color snackBarLight = Color(0xFF1D2129);
  static const Color startGreen = Color(0xFF00A15C);
  static const Color userBlue = Color(0xFF2E7CF6);
  static const Color alternativeRoute = Color(0xFF98A2B3);

  /// Tratto da fare in auto e parcheggi per disabili (blu dei cartelli).
  static const Color driveRoute = Color(0xFF1F4FA8);
  static const Color parkingBlue = Color(0xFF0B57D0);
  static const Color navigationPanel = Color(0xFF14171C);
  static const Color navigationButton = Color(0xFF1F242C);
  static const Color offRouteBanner = Color(0xFFFFC93C);
  static const Color offRouteText = Color(0xFF3D2C00);

  /// Striscia "Stai condividendo la posizione" (contrasto 9:1).
  static const Color shareBanner = Color(0xFFCDE6FF);
  static const Color shareText = Color(0xFF0B2A47);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );
}

/// Estensione del tema con i colori semantici usati in tutta l'app.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primarySoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.scrim,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primarySoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color scrim;
  final Color shadow;

  static const AppColors light = AppColors(
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F3F6),
    border: Color(0xFFE5E8EC),
    borderStrong: Color(0xFFCBD2DB),
    textPrimary: Color(0xFF11151C),
    textSecondary: Color(0xFF5A6472),
    // Contrasto almeno 4,5:1 su surface e surfaceMuted (WCAG AA).
    textTertiary: Color(0xFF646C79),
    primarySoft: Color(0xFFFFECEE),
    success: Color(0xFF0B7A4B),
    successSoft: Color(0xFFE4F6ED),
    warning: Color(0xFFB25E00),
    warningSoft: Color(0xFFFFF2DF),
    danger: Color(0xFFC81E27),
    dangerSoft: Color(0xFFFDECEC),
    info: Color(0xFF1F6FE0),
    infoSoft: Color(0xFFE8F1FE),
    scrim: Color(0x66101828),
    shadow: Color(0x1A101828),
  );

  static const AppColors dark = AppColors(
    background: Color(0xFF0D0F13),
    surface: Color(0xFF171A20),
    surfaceElevated: Color(0xFF1E222A),
    surfaceMuted: Color(0xFF23272F),
    border: Color(0xFF2C313A),
    borderStrong: Color(0xFF3C434F),
    textPrimary: Color(0xFFF3F5F8),
    textSecondary: Color(0xFFA7B0BE),
    textTertiary: Color(0xFF8D96A3),
    primarySoft: Color(0xFF3A1015),
    success: Color(0xFF3ED08C),
    successSoft: Color(0xFF12281F),
    warning: Color(0xFFFFB84D),
    warningSoft: Color(0xFF2E2213),
    danger: Color(0xFFFF6B6B),
    dangerSoft: Color(0xFF33161A),
    info: Color(0xFF5FA0FF),
    infoSoft: Color(0xFF141F31),
    scrim: Color(0x99000000),
    shadow: Color(0x66000000),
  );

  /// Restituisce i colori del tema corrente (chiaro di default).
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primarySoft,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? scrim,
    Color? shadow,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primarySoft: primarySoft ?? this.primarySoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      primarySoft: l(primarySoft, other.primarySoft),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      scrim: l(scrim, other.scrim),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// Ombra morbida usata da card, pannelli e pulsanti flottanti.
List<BoxShadow> softShadow(AppColors colors) => [
      BoxShadow(
        color: colors.shadow,
        offset: const Offset(0, 8),
        blurRadius: 24,
        spreadRadius: -4,
      ),
      BoxShadow(
        color: colors.shadow.withValues(alpha: colors.shadow.a * 0.5),
        offset: const Offset(0, 1),
        blurRadius: 4,
      ),
    ];

ThemeData buildAppTheme(
  AppColors colors,
  Brightness brightness, {
  String? fontFamily,
}) {
  final isDark = brightness == Brightness.dark;

  TextStyle style(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  final textTheme = TextTheme(
    displaySmall: style(32, FontWeight.w800, colors.textPrimary,
        height: 1.15, letterSpacing: -0.8),
    headlineMedium: style(26, FontWeight.w700, colors.textPrimary,
        height: 1.2, letterSpacing: -0.5),
    headlineSmall: style(21, FontWeight.w700, colors.textPrimary,
        height: 1.25, letterSpacing: -0.3),
    titleLarge: style(18, FontWeight.w700, colors.textPrimary,
        height: 1.3, letterSpacing: -0.2),
    titleMedium: style(16, FontWeight.w600, colors.textPrimary,
        height: 1.35, letterSpacing: -0.1),
    titleSmall: style(14, FontWeight.w600, colors.textPrimary, height: 1.35),
    bodyLarge: style(16, FontWeight.w400, colors.textPrimary, height: 1.5),
    bodyMedium: style(14, FontWeight.w400, colors.textSecondary, height: 1.5),
    bodySmall: style(12.5, FontWeight.w400, colors.textSecondary, height: 1.45),
    labelLarge: style(15, FontWeight.w600, colors.textPrimary,
        height: 1.2, letterSpacing: 0),
    labelMedium: style(13, FontWeight.w600, colors.textSecondary, height: 1.2),
    labelSmall: style(11, FontWeight.w700, colors.textTertiary,
        height: 1.2, letterSpacing: 0.4),
  );

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    primaryContainer: colors.primarySoft,
    onPrimaryContainer: isDark ? Colors.white : AppPalette.primaryDark,
    secondary: AppPalette.accent,
    onSecondary: AppPalette.onAccent,
    tertiary: AppPalette.tertiary,
    onTertiary: Colors.white,
    error: colors.danger,
    onError: Colors.white,
    errorContainer: colors.dangerSoft,
    onErrorContainer: colors.danger,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    onSurfaceVariant: colors.textSecondary,
    surfaceContainerHighest: colors.surfaceMuted,
    outline: colors.border,
    outlineVariant: colors.border,
    shadow: colors.shadow,
    scrim: colors.scrim,
    inverseSurface: isDark ? colors.textPrimary : AppPalette.snackBarLight,
    onInverseSurface: isDark ? colors.background : Colors.white,
    inversePrimary: AppPalette.primaryLight,
  );

  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  final buttonText = textTheme.labelLarge?.copyWith(color: Colors.white);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: fontFamily,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.surface,
    visualDensity: VisualDensity.standard,
    extensions: [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalBackgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.border),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: AppPalette.primary,
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      side: BorderSide(color: colors.border),
      shape: const StadiumBorder(),
      checkmarkColor: Colors.white,
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: colors.surfaceMuted,
        disabledForegroundColor: colors.textTertiary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: colors.surfaceMuted,
        disabledForegroundColor: colors.textTertiary,
        elevation: 0,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shadowColor: Colors.transparent,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: colors.borderStrong),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: textTheme.labelLarge?.copyWith(color: AppPalette.primary),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colors.textSecondary,
        highlightColor: colors.surfaceMuted,
      ),
    ),
    iconTheme: IconThemeData(size: 22, color: colors.textSecondary),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.surface,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceMuted,
      isDense: true,
      contentPadding: const EdgeInsets.all(16),
      hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
      labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      prefixIconColor: colors.textTertiary,
      suffixIconColor: colors.textTertiary,
      border: inputBorder(colors.border),
      enabledBorder: inputBorder(colors.border),
      disabledBorder: inputBorder(colors.border),
      focusedBorder: inputBorder(AppPalette.primary, 1.6),
      errorBorder: inputBorder(colors.danger),
      focusedErrorBorder: inputBorder(colors.danger, 1.6),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.textSecondary,
      textColor: colors.textPrimary,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppPalette.primary),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppPalette.primary
            : colors.borderStrong,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? Colors.white : colors.surface,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppPalette.primary
            : colors.surfaceMuted,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? colors.surfaceElevated : AppPalette.snackBarLight,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceElevated : AppPalette.snackBarLight,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
    ),
  );
}
