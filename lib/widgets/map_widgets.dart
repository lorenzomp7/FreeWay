import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Filtri colorati delle mappe: tessere più chiare o invertite nel tema scuro.
List<double> _tileMatrix(
  double contrast,
  bool invert,
  double offset,
  double saturation,
) {
  final c = invert ? -contrast : contrast;
  final o = invert ? 255 - offset : offset;
  final rg = (0.715 - saturation * 0.715) * c;
  final rb = (0.072 - saturation * 0.072) * c;
  final gr = (0.213 - saturation * 0.213) * c;
  return [
    (0.213 + saturation * 0.787) * c, rg, rb, 0, o, //
    gr, (0.715 + saturation * 0.285) * c, rb, 0, o, //
    gr, rg, (0.072 + saturation * 0.928) * c, 0, o, //
    0, 0, 0, 1, 0, //
  ];
}

Widget lightTileBuilder(BuildContext context, Widget tileWidget, dynamic tile) {
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(_tileMatrix(0.97, false, 8, 0.35)),
    child: tileWidget,
  );
}

Widget darkTileBuilder(BuildContext context, Widget tileWidget, dynamic tile) {
  return ColorFiltered(
    colorFilter: ColorFilter.matrix(_tileMatrix(0.82, true, 18, 0.12)),
    child: tileWidget,
  );
}

/// Attribuzione obbligatoria di OpenStreetMap.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '© OpenStreetMap contributors',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontSize: 9.5, letterSpacing: 0.1),
      ),
    );
  }
}

/// Pulsanti di zoom e posizione sul lato destro della mappa.
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
    required this.isLocating,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocate;
  final bool isLocating;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    BoxDecoration decoration() => BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(14),
          boxShadow: softShadow(colors),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: decoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MapControlButton(
                icon: Icons.add_rounded,
                onPressed: onZoomIn,
                tooltip: 'Ingrandisci',
              ),
              Divider(height: 1, thickness: 1, color: colors.border),
              MapControlButton(
                icon: Icons.remove_rounded,
                onPressed: onZoomOut,
                tooltip: 'Riduci',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: decoration(),
          child: MapControlButton(
            icon: Icons.my_location_rounded,
            onPressed: onLocate,
            tooltip: 'La mia posizione',
            isLoading: isLocating,
            color: AppPalette.primary,
          ),
        ),
      ],
    );
  }
}

class MapControlButton extends StatelessWidget {
  const MapControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isLoading = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isLoading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = color ?? colors.textPrimary;
    final Widget child = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Icon(icon, color: foreground, size: 20);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      ),
    );
  }
}

/// Etichette brevi dei filtri per categoria.
const Map<String, String> _shortCategoryLabels = {
  'Dislivello e pavimentazione': 'Dislivelli',
  'Ingresso e passaggio': 'Passaggi',
  'Ostacoli temporanei': 'Temporanei',
};

const Map<String, IconData> _filterIcons = {
  'Tutti': Icons.tune_rounded,
  'Dislivello e pavimentazione': Icons.stairs_rounded,
  'Ingresso e passaggio': Icons.meeting_room_outlined,
  'Sicurezza': Icons.shield_outlined,
  'Ostacoli temporanei': Icons.construction_rounded,
};

/// Filtri orizzontali per mostrare solo una categoria di ostacoli.
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selected,
    required this.countFor,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final int Function(String category) countFor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          final count = countFor(category);
          final label = _shortCategoryLabels[category] ?? category;
          return GestureDetector(
            onTap: () => onSelected(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppPalette.primary : colors.surface,
                border: Border.all(
                  color: isSelected ? AppPalette.primary : colors.border,
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow,
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _filterIcons[category] ?? Icons.place_outlined,
                    color: isSelected ? Colors.white : colors.textSecondary,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected ? Colors.white : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: textTheme.labelSmall?.copyWith(
                        color: isSelected ? Colors.white : colors.textSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Suggerimento "Tieni premuto sulla mappa per segnalare un ostacolo".
class ReportHint extends StatelessWidget {
  const ReportHint({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
        boxShadow: softShadow(colors),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              size: 15,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Tieni premuto sulla mappa per segnalare un ostacolo',
              maxLines: 2,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(
                Icons.close_rounded,
                color: colors.textTertiary,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Segnaposto di partenza/arrivo con la punta a forma di goccia.
class RouteEndpointMarker extends StatelessWidget {
  const RouteEndpointMarker({super.key, required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        Transform.translate(
          offset: const Offset(0, -3),
          child: CustomPaint(
            size: const Size(12, 9),
            painter: _PinTipPainter(color),
          ),
        ),
      ],
    );
  }
}

class _PinTipPainter extends CustomPainter {
  _PinTipPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawShadow(outer, Colors.black.withValues(alpha: 0.4), 2, false);
    canvas.drawPath(outer, Paint()..color = Colors.white);

    final inner = Path()
      ..moveTo(2.5, 0)
      ..lineTo(size.width / 2, size.height - 3)
      ..lineTo(size.width - 2.5, 0)
      ..close();
    canvas.drawPath(inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTipPainter oldDelegate) => oldDelegate.color != color;
}

/// Punto blu pulsante con la posizione dell'utente.
class UserLocationDot extends StatefulWidget {
  const UserLocationDot({super.key});

  @override
  State<UserLocationDot> createState() => _UserLocationDotState();
}

class _UserLocationDotState extends State<UserLocationDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final size = 12 + 28 * t;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppPalette.userBlue.withValues(alpha: (1 - t) * 0.28),
                shape: BoxShape.circle,
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppPalette.userBlue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Icona di un ostacolo sulla mappa.
class ObstacleMarker extends StatelessWidget {
  const ObstacleMarker({
    super.key,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

/// Raggruppamento di più ostacoli vicini.
class ClusterBadge extends StatelessWidget {
  const ClusterBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.35),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
        gradient: AppPalette.brandGradient,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
