import 'package:flutter/material.dart';

import '../models/route_option.dart';
import '../services/along_route_service.dart';
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
    this.onSearchAlong,
    this.alongCounts = const {},
    this.alongLoading = const {},
    this.stops = const [],
    this.onRemoveStop,
    this.weatherWarning,
    this.onSaveOffline,
    this.offlineProgress,
    this.isSavedOffline = false,
  });

  final List<RouteOption> routes;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onClose;

  /// Cerca lungo il percorso (bagni, panchine, fontanelle), come "Search
  /// along route" di Google Maps.
  final ValueChanged<AlongRouteCategory>? onSearchAlong;

  /// Risultati per categoria già cercata.
  final Map<AlongRouteCategory, int> alongCounts;
  final Set<AlongRouteCategory> alongLoading;

  /// Tappe intermedie, in ordine ("Add stop").
  final List<String> stops;
  final ValueChanged<int>? onRemoveStop;

  /// Avviso meteo sul percorso (pioggia, neve, ghiaccio, caldo).
  final String? weatherWarning;

  /// "Salva per l'uso senza rete", come "Download offline map".
  final VoidCallback? onSaveOffline;

  /// Avanzamento del salvataggio (fatte, totali), `null` se fermo.
  final (int, int)? offlineProgress;
  final bool isSavedOffline;

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
            // Come l'avviso delle indicazioni accessibili di Google Maps.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Attenzione: i percorsi possono non riflettere le '
                      'condizioni reali della strada.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (weatherWarning != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.umbrella_rounded,
                        size: 16,
                        color: colors.warning,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          weatherWarning!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (stops.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < stops.length; i++)
                      InputChip(
                        avatar: const Icon(
                          Icons.flag_circle_outlined,
                          size: 18,
                        ),
                        label: Text('Tappa ${i + 1}: ${stops[i]}'),
                        deleteButtonTooltipMessage: 'Togli la tappa',
                        onDeleted: onRemoveStop == null
                            ? null
                            : () => onRemoveStop!(i),
                      ),
                  ],
                ),
              ),
            if (onSearchAlong != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final category in AlongRouteCategory.values)
                        AlongRouteChip(
                          category: category,
                          count: alongCounts[category],
                          isLoading: alongLoading.contains(category),
                          onPressed: () => onSearchAlong!(category),
                        ),
                    ],
                  ),
                ),
              ),
            if (onSaveOffline != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OfflineRouteChip(
                    progress: offlineProgress,
                    isSaved: isSavedOffline,
                    onPressed: onSaveOffline!,
                  ),
                ),
              ),
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

IconData alongRouteIcon(AlongRouteCategory category) => switch (category) {
  AlongRouteCategory.toilets => Icons.wc_rounded,
  AlongRouteCategory.benches => Icons.event_seat_rounded,
  AlongRouteCategory.water => Icons.water_drop_rounded,
};

/// Pulsante di una categoria da cercare lungo il percorso, con il numero di
/// risultati dopo la ricerca.
class AlongRouteChip extends StatelessWidget {
  const AlongRouteChip({
    super.key,
    required this.category,
    required this.count,
    required this.isLoading,
    required this.onPressed,
  });

  final AlongRouteCategory category;

  /// `null` se non ancora cercata.
  final int? count;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (count) {
      null => category.label,
      0 => '${category.label}: nessuna',
      final n => '${category.label}: $n',
    };
    return ActionChip(
      avatar: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(alongRouteIcon(category), size: 18),
      label: Text(label),
      tooltip: count == null
          ? 'Cerca ${category.plural} lungo il percorso'
          : count == 0
          ? 'Nessun risultato su OpenStreetMap lungo il percorso'
          : 'Mostrati sulla mappa',
      onPressed: isLoading ? null : onPressed,
    );
  }
}

/// "Salva per l'uso senza rete": salva la mappa del tragitto.
class OfflineRouteChip extends StatelessWidget {
  const OfflineRouteChip({
    super.key,
    required this.progress,
    required this.isSaved,
    required this.onPressed,
  });

  final (int, int)? progress;
  final bool isSaved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final saving = progress;
    if (saving != null) {
      final (done, total) = saving;
      return ActionChip(
        avatar: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text(
          total == 0 ? 'Salvo la mappa…' : 'Salvo la mappa… $done/$total',
        ),
        onPressed: null,
      );
    }
    if (isSaved) {
      return ActionChip(
        avatar: Icon(
          Icons.offline_pin_rounded,
          size: 18,
          color: colors.success,
        ),
        label: const Text('Mappa salvata per l\'uso senza rete'),
        tooltip: 'Salva di nuovo',
        onPressed: onPressed,
      );
    }
    return ActionChip(
      avatar: const Icon(Icons.download_for_offline_outlined, size: 18),
      label: const Text('Salva per l\'uso senza rete'),
      tooltip: 'Salva la mappa del tragitto, nel caso la rete cada',
      onPressed: onPressed,
    );
  }
}
