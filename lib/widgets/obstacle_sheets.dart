import 'package:flutter/material.dart';

import '../models/obstacle.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Chiede il tipo di ostacolo da segnalare; restituisce `null` se annullato.
Future<String?> showReportObstacleSheet(BuildContext context) {
  return showAppBottomSheet<String>(
    context,
    (_) => const ReportObstacleSheet(),
  );
}

/// Azione scelta nella scheda di un ostacolo.
enum ObstacleAction { confirm, remove }

/// Mostra i dettagli di un ostacolo e restituisce l'azione scelta.
Future<ObstacleAction?> showObstacleDetailsSheet(
  BuildContext context,
  Obstacle obstacle, {
  String? currentUserId,
}) {
  return showAppBottomSheet<ObstacleAction>(
    context,
    (_) => ObstacleDetailsSheet(
      obstacle: obstacle,
      currentUserId: currentUserId,
    ),
  );
}

/// Tempo trascorso da [date] in forma breve ("3 giorni fa").
String timeAgo(DateTime date, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(date);
  if (elapsed.inMinutes < 1) return 'proprio ora';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min fa';
  if (elapsed.inHours < 24) return '${elapsed.inHours} h fa';
  final days = elapsed.inDays;
  if (days == 1) return 'ieri';
  if (days < 30) return '$days giorni fa';
  final months = days ~/ 30;
  return months == 1 ? 'un mese fa' : '$months mesi fa';
}

class ReportObstacleSheet extends StatefulWidget {
  const ReportObstacleSheet({super.key});

  @override
  State<ReportObstacleSheet> createState() => _ReportObstacleSheetState();
}

class _ReportObstacleSheetState extends State<ReportObstacleSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screen = MediaQuery.of(context).size;

    final items = <Widget>[];
    for (final entry in obstacleTypesByCategory.entries) {
      items.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              obstacleCategoryIcons[entry.key] ?? Icons.place_outlined,
              color: colors.textTertiary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              entry.key.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ));
      for (final type in entry.value) {
        items.add(ObstacleOption(
          label: type,
          isSelected: _selected == type,
          onTap: () => setState(() => _selected = type),
        ));
      }
      items.add(const SizedBox(height: 12));
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screen.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: DragHandle()),
          const SheetHeader(
            title: 'Segnala un ostacolo',
            subtitle: 'Cosa rende difficile il passaggio in questo punto?',
            icon: Icons.report_problem_outlined,
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: items,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Invia segnalazione'),
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

class ObstacleOption extends StatelessWidget {
  const ObstacleOption({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.primarySoft : colors.surfaceMuted,
            border: Border.all(
              color: isSelected ? AppPalette.primary : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isSelected && !isDark
                            ? AppPalette.primaryDark
                            : colors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? AppPalette.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppPalette.primary : colors.borderStrong,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ObstacleDetailsSheet extends StatelessWidget {
  const ObstacleDetailsSheet({
    super.key,
    required this.obstacle,
    this.currentUserId,
  });

  final Obstacle obstacle;
  final String? currentUserId;

  String get _formattedDate {
    final date = obstacle.reportedAt;
    if (date == null) return 'Data non disponibile';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        'alle ${two(date.hour)}:${two(date.minute)}';
  }

  String get _timeAgo {
    final date = obstacle.reportedAt;
    return date == null ? '' : timeAgo(date);
  }

  static String _formatDay(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String get _confirmationText {
    final count = obstacle.confirmationCount;
    final people = count == 1 ? '1 persona' : '$count persone';
    final last = obstacle.lastConfirmedAt;
    return last == null
        ? 'Confermato da $people'
        : 'Confermato da $people · ultima volta ${timeAgo(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final when = _timeAgo.isEmpty ? _formattedDate : '$_formattedDate · $_timeAgo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: DragHandle()),
          SheetHeader(
            title: 'Ostacolo segnalato',
            subtitle: obstacle.category,
            icon: obstacle.icon,
            color: obstacle.color,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(obstacle.type, style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: colors.textTertiary,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(when, style: textTheme.bodySmall)),
                        ],
                      ),
                      if (obstacle.expiresAt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.hourglass_bottom_rounded,
                              color: colors.textTertiary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ostacolo temporaneo: sparisce dalla mappa il '
                                '${_formatDay(obstacle.expiresAt!)} se nessuno '
                                "conferma che c'è ancora.",
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (obstacle.confirmationCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              color: colors.textTertiary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _confirmationText,
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!obstacle.isReportedBy(currentUserId)) ...[
                  OutlinedButton.icon(
                    onPressed: obstacle.canBeConfirmedBy(currentUserId)
                        ? () => Navigator.of(context).pop(ObstacleAction.confirm)
                        : null,
                    icon: const Icon(Icons.visibility_outlined, size: 19),
                    label: Text(
                      obstacle.canBeConfirmedBy(currentUserId)
                          ? "Confermo, c'è ancora"
                          : 'Hai già confermato questo ostacolo',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(ObstacleAction.remove),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
                  label: const Text("L'ostacolo non c'è più"),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.successSoft,
                    foregroundColor: colors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rimuovendolo aiuti le altre persone a ricevere percorsi aggiornati.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
