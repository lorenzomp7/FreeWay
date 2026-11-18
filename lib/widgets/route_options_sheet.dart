import 'package:flutter/material.dart';

import '../models/route_option.dart';
import '../theme/app_theme.dart';

/// Pannello in basso con i percorsi trovati e il pulsante "Avvia navigazione".
class RouteOptionsSheet extends StatelessWidget {
  const RouteOptionsSheet({
    super.key,
    required this.routes,
    required this.selectedIndex,
    required this.onSelect,
    required this.onStart,
    required this.onClose,
  });

  final List<RouteOption> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = routes.length == 1
        ? '1 percorso disponibile'
        : '${routes.length} percorsi disponibili';
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: softShadow(colors),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.surfaceMuted,
                      foregroundColor: colors.textSecondary,
                      fixedSize: const Size(34, 34),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                itemCount: routes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => RouteCard(
                  route: routes[index],
                  isSelected: index == selectedIndex,
                  onTap: () => onSelect(index),
                ),
              ),
            ),
            if (selectedIndex < routes.length &&
                routes[selectedIndex].warnings.isNotEmpty)
              RouteWarningsList(warnings: routes[selectedIndex].warnings),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.navigation_rounded, size: 20),
                  label: const Text('Avvia navigazione'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObstacleBadge {
  const _ObstacleBadge(this.color, this.label, this.background);

  final Color color;
  final String label;
  final Color background;
}

_ObstacleBadge _obstacleBadge(BuildContext context, RouteOption route) {
  final colors = AppColors.of(context);
  final count = route.obstacleCount;
  if (count == 0) {
    return _ObstacleBadge(
      colors.success,
      'Nessun ostacolo',
      colors.successSoft,
    );
  }
  if (count <= 2) {
    return _ObstacleBadge(
      colors.warning,
      '$count ostacol${count == 1 ? 'o' : 'i'}',
      colors.warningSoft,
    );
  }
  return _ObstacleBadge(colors.danger, '$count ostacoli', colors.dangerSoft);
}

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  final RouteOption route;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final badge = _obstacleBadge(context, route);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 208,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? colors.primarySoft : colors.surface,
          border: Border.all(
            color: isSelected ? AppPalette.primary : colors.border,
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (route.isRecommended)
                  RecommendedChip(
                    label: route.label.isNotEmpty ? route.label : 'Consigliato',
                    color: colors.success,
                    background: colors.successSoft,
                    icon: Icons.verified_rounded,
                  )
                else
                  Flexible(
                    child: Text(
                      route.label.isNotEmpty
                          ? route.label
                          : 'Percorso ${route.index + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(route.durationText, style: textTheme.headlineSmall),
                const SizedBox(width: 8),
                Text(
                  route.distanceText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: route.accessibilityScore / 100,
                      minHeight: 6,
                      backgroundColor: colors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation(badge.color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${route.accessibilityScore}%',
                  style: textTheme.labelMedium?.copyWith(color: badge.color),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  route.obstacleCount == 0
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: badge.color,
                  size: 14,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    badge.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: badge.color),
                  ),
                ),
              ],
            ),
            _TerrainLine(route: route),
          ],
        ),
      ),
    );
  }
}

/// Riga della scheda con le difficoltà del terreno: la più grave e quante
/// altre ce ne sono.
class _TerrainLine extends StatelessWidget {
  const _TerrainLine({required this.route});

  final RouteOption route;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final warnings = route.warnings;
    if (!route.hasTerrainData && warnings.isEmpty) {
      return Text(
        'Pendenze non disponibili',
        maxLines: 1,
        style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
      );
    }
    if (warnings.isEmpty) {
      return Row(
        children: [
          Icon(Icons.terrain_rounded, color: colors.success, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Senza gradini né salite',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colors.success),
            ),
          ),
        ],
      );
    }
    final first = warnings.first;
    final color = first.isHard ? colors.danger : colors.warning;
    final more = warnings.length > 1 ? ' +${warnings.length - 1}' : '';
    return Row(
      children: [
        Icon(routeWarningIcon(first.kind), color: color, size: 14),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '${first.shortLabel}$more',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

IconData routeWarningIcon(RouteWarningKind kind) {
  switch (kind) {
    case RouteWarningKind.steps:
      return Icons.stairs_rounded;
    case RouteWarningKind.steepUp:
      return Icons.trending_up_rounded;
    case RouteWarningKind.steepDown:
      return Icons.trending_down_rounded;
    case RouteWarningKind.moderateSlope:
      return Icons.show_chart_rounded;
    case RouteWarningKind.roughSurface:
      return Icons.grain_rounded;
    case RouteWarningKind.construction:
      return Icons.construction_rounded;
  }
}

/// Elenco delle difficoltà del percorso selezionato, come gli avvisi
/// "This route has stairs" di Google Maps.
class RouteWarningsList extends StatelessWidget {
  const RouteWarningsList({super.key, required this.warnings});

  final List<RouteWarning> warnings;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final warning in warnings)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: warning.isHard ? colors.dangerSoft : colors.warningSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    routeWarningIcon(warning.kind),
                    size: 14,
                    color: warning.isHard ? colors.danger : colors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    warning.label,
                    style: textTheme.bodySmall?.copyWith(
                      color: warning.isHard ? colors.danger : colors.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class RecommendedChip extends StatelessWidget {
  const RecommendedChip({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
