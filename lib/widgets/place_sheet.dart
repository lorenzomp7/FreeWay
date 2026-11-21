import 'package:flutter/material.dart';

import '../models/entrance_report.dart';
import '../models/place_accessibility.dart';
import '../services/geocoding_service.dart' show formatDistance;
import '../services/opening_hours.dart';
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
    this.accessibility,
    this.isLoadingAccessibility = false,
    this.entranceSummary = const EntranceSummary(),
    required this.onDirections,
    required this.onStart,
    required this.onShare,
    required this.onClose,
    this.onSave,
    this.savedLabels = const [],
  });

  final String title;
  final String subtitle;

  /// Per esempio "a 1,2 km da te"; `null` se la tua posizione non è nota.
  final String? distanceText;

  /// Ostacoli segnalati nei dintorni del luogo.
  final int nearbyObstacles;

  /// Accessibilità da OpenStreetMap; `null` se non disponibile.
  final PlaceAccessibility? accessibility;
  final bool isLoadingAccessibility;

  /// Risposte "Com'era l'ingresso?" di chi è già arrivato qui.
  final EntranceSummary entranceSummary;
  final VoidCallback onDirections;
  final VoidCallback onStart;
  final VoidCallback onShare;
  final VoidCallback onClose;

  /// Pulsante "Salva" (Casa, Lavoro o un nome); `null` per nasconderlo.
  final VoidCallback? onSave;

  /// Nomi con cui il luogo è già salvato, per esempio «Casa».
  final List<String> savedLabels;

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
                if (isLoadingAccessibility || accessibility != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, right: 12),
                    child: isLoadingAccessibility
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Controllo l\'accessibilità…',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          )
                        : AccessibilityFacts(info: accessibility!),
                  ),
                if (!entranceSummary.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.door_front_door_outlined,
                          size: 18,
                          color:
                              entranceSummary.accessible >=
                                  entranceSummary.steps
                              ? colors.success
                              : colors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entranceSummary.label,
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
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
                      if (onSave != null) ...[
                        OutlinedButton.icon(
                          onPressed: onSave,
                          icon: Icon(
                            savedLabels.isEmpty
                                ? Icons.bookmark_border_rounded
                                : Icons.bookmark_rounded,
                            size: 20,
                          ),
                          label: Text(
                            savedLabels.isEmpty
                                ? 'Salva'
                                : 'Salvato: ${savedLabels.join(', ')}',
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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

/// Le voci di accessibilità del luogo, come "Accessible entrance",
/// "Accessible restroom" e "Accessible parking" di Google Maps.
class AccessibilityFacts extends StatelessWidget {
  const AccessibilityFacts({super.key, required this.info, this.now});

  final PlaceAccessibility info;

  /// Momento per "Aperto ora"; per i test (di solito adesso).
  final DateTime? now;

  /// Righe che la scheda mostrerà, per spostare i pulsanti della mappa.
  static int rowCount(PlaceAccessibility? info, {DateTime? now}) {
    if (info == null) return 0;
    final hours =
        openingNowText(info.openingHours, now ?? DateTime.now()) == null
        ? 0
        : 1;
    if (!info.hasData) return 1 + hours;
    var rows = 1 + hours; // ingresso del luogo
    if (info.entrances.isNotEmpty) rows++;
    if (info.toilets != null) rows++;
    if (info.disabledParkingMeters != null) rows++;
    if (info.description != null) rows++;
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    Widget row(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );

    final opening = openingNowText(info.openingHours, now ?? DateTime.now());
    final Widget? hoursRow = opening == null
        ? null
        : row(
            Icons.schedule_rounded,
            opening.startsWith('Chiuso')
                ? colors.danger
                : opening.contains('chiude')
                ? colors.textSecondary
                : colors.success,
            '$opening (orari OpenStreetMap)',
          );

    if (!info.hasData) {
      final missing = row(
        Icons.accessible_rounded,
        colors.textTertiary,
        'Accessibilità non indicata su OpenStreetMap',
      );
      if (hoursRow == null) return missing;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [hoursRow, missing],
      );
    }

    final rows = <Widget>[?hoursRow];
    switch (info.wheelchair) {
      case 'yes':
        rows.add(
          row(
            Icons.accessible_rounded,
            colors.success,
            'Accessibile in sedia a rotelle',
          ),
        );
      case 'limited':
        rows.add(
          row(
            Icons.accessible_rounded,
            colors.warning,
            'Parzialmente accessibile in sedia a rotelle',
          ),
        );
      case 'no':
        rows.add(
          row(
            Icons.not_accessible_rounded,
            colors.danger,
            'Non accessibile in sedia a rotelle',
          ),
        );
      default:
        rows.add(
          row(
            Icons.accessible_rounded,
            colors.textTertiary,
            'Accessibilità del luogo non indicata',
          ),
        );
    }

    final best = info.bestEntrance;
    if (best != null) {
      final what = best.isAccessible
          ? (best.wheelchair == 'yes'
                ? 'Ingresso accessibile'
                : 'Ingresso parzialmente accessibile')
          : 'Ingresso principale';
      final name = best.name != null ? ' (${best.name})' : '';
      rows.add(
        row(
          Icons.door_front_door_outlined,
          best.isAccessible ? colors.success : colors.textSecondary,
          '$what$name: il percorso arriva lì',
        ),
      );
    } else if (info.allEntrancesInaccessible) {
      rows.add(
        row(
          Icons.door_front_door_outlined,
          colors.danger,
          'Gli ingressi segnati non sono accessibili',
        ),
      );
    } else if (info.entrances.isNotEmpty) {
      rows.add(
        row(
          Icons.door_front_door_outlined,
          colors.textTertiary,
          'Ingressi segnati senza informazioni sull\'accessibilità',
        ),
      );
    }

    switch (info.toilets) {
      case 'yes':
        rows.add(row(Icons.wc_rounded, colors.success, 'Bagno accessibile'));
      case 'no':
        rows.add(row(Icons.wc_rounded, colors.danger, 'Bagno non accessibile'));
    }

    final parking = info.disabledParkingMeters;
    if (parking != null) {
      rows.add(
        row(
          Icons.local_parking_rounded,
          colors.success,
          'Parcheggio per disabili a ${formatDistance(parking)}',
        ),
      );
    }

    final description = info.description;
    if (description != null) {
      rows.add(
        row(Icons.info_outline_rounded, colors.textSecondary, '«$description»'),
      );
    }

    return Semantics(
      container: true,
      label: 'Accessibilità, dati OpenStreetMap',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

/// Segnaposto di un ingresso sulla mappa: verde se accessibile, rosso se
/// non lo è, grigio senza informazioni. Toccandolo il percorso arriva lì.
class EntranceMarker extends StatelessWidget {
  const EntranceMarker({
    super.key,
    required this.entrance,
    required this.isDestination,
    required this.onTap,
  });

  final PlaceEntrance entrance;
  final bool isDestination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Color color;
    final String label;
    if (entrance.isAccessible) {
      color = colors.success;
      label = entrance.wheelchair == 'yes'
          ? 'Ingresso accessibile'
          : 'Ingresso parzialmente accessibile';
    } else if (entrance.isNotAccessible) {
      color = colors.danger;
      label = 'Ingresso non accessibile';
    } else {
      color = colors.textTertiary;
      label = entrance.isMain ? 'Ingresso principale' : 'Ingresso';
    }
    final semantics = isDestination ? '$label, arrivo del percorso' : label;
    return Tooltip(
      message: semantics,
      child: Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isDestination ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              entrance.isNotAccessible
                  ? Icons.not_accessible_rounded
                  : Icons.door_front_door_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
