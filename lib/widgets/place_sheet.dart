import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Scheda in basso del luogo trovato, come quella di Google Maps: nome,
/// indirizzo, distanza e i pulsanti "Indicazioni", "Avvia" e "Condividi".
class PlaceSheet extends StatelessWidget {
  const PlaceSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.distanceText,
    required this.nearbyObstacles,
    required this.onDirections,
    required this.onStart,
    required this.onShare,
    required this.onClose,
  });

  final String title;
  final String subtitle;

  /// Per esempio "a 1,2 km da te"; `null` se la tua posizione non è nota.
  final String? distanceText;

  /// Ostacoli segnalati nei dintorni del luogo.
  final int nearbyObstacles;
  final VoidCallback onDirections;
  final VoidCallback onStart;
  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final details = [
      ?distanceText,
      nearbyObstacles == 0
          ? 'Nessun ostacolo segnalato vicino'
          : nearbyObstacles == 1
          ? '1 ostacolo segnalato vicino'
          : '$nearbyObstacles ostacoli segnalati vicino',
    ];
    return Semantics(
      container: true,
      label: 'Scheda del luogo $title',
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: softShadow(colors),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderStrong,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge,
                          ),
                          if (subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              details.join(' · '),
                              style: textTheme.bodySmall?.copyWith(
                                color: nearbyObstacles == 0
                                    ? colors.textTertiary
                                    : colors.warning,
                              ),
                            ),
                          ),
                        ],
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
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onDirections,
                        icon: const Icon(Icons.directions_rounded, size: 20),
                        label: const Text('Indicazioni'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onStart,
                        icon: const Icon(Icons.navigation_outlined, size: 20),
                        label: const Text('Avvia'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.share_outlined, size: 20),
                        label: const Text('Condividi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra in alto e pulsante "Fatto" per scegliere un punto spostando la
/// mappa sotto il segnaposto al centro.
class ChooseOnMapBar extends StatelessWidget {
  const ChooseOnMapBar({
    super.key,
    required this.isStart,
    required this.onCancel,
  });

  final bool isStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow(colors),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Annulla',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onCancel,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStart ? 'Scegli la partenza' : 'Scegli la destinazione',
                  style: textTheme.titleSmall,
                ),
                Text(
                  'Sposta la mappa sotto il segnaposto',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
