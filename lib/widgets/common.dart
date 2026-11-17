import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Apre un bottom sheet con lo stile dell'app.
Future<T?> showAppBottomSheet<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    barrierColor: colors.scrim,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: builder(context),
      ),
    ),
  );
}

/// Maniglia in cima ai bottom sheet.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.of(context).borderStrong,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Intestazione dei bottom sheet con icona, titolo, sottotitolo e chiusura.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = color ?? AppPalette.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: colors.surfaceMuted,
              foregroundColor: colors.textSecondary,
              fixedSize: const Size(36, 36),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner con il logo FREE WAY (su sfondo bianco nel tema scuro).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/banner.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    if (Theme.of(context).brightness != Brightness.dark) return image;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: image,
    );
  }
}

/// Piccolo logo quadrato usato nella barra superiore.
class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9.6),
        gradient: AppPalette.brandGradient,
      ),
      child: const Icon(Icons.route_rounded, color: Colors.white, size: 17.4),
    );
  }
}

/// Scritta "FREE WAY" con "WAY" nel colore primario.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: AppColors.of(context).textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
        children: const [
          TextSpan(text: 'FREE'),
          TextSpan(text: ' WAY', style: TextStyle(color: AppPalette.primary)),
        ],
      ),
    );
  }
}

/// Icona circolare su sfondo colorato.
class CircleIconBadge extends StatelessWidget {
  const CircleIconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: foreground, size: 18),
    );
  }
}
