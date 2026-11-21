import 'package:flutter/material.dart';

import '../models/contributions.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'contributions_sheet.dart';

/// Cosa fare dopo aver chiuso "La tua settimana".
enum WeeklyReviewAction {
  /// "Contribuisci ancora": segnalare un ostacolo.
  contribute,

  /// Verificare l'ostacolo suggerito.
  verify,

  /// Aprire "Le tue segnalazioni".
  showAll,
}

/// Apre "La tua settimana", come l'email "Your week in review" che Google
/// Maps manda a chi contribuisce.
Future<WeeklyReviewAction?> showWeeklyReviewSheet(
  BuildContext context, {
  required WeeklyReview review,
  required Contributions contributions,
  VerifySuggestion? suggestion,
}) {
  return showAppBottomSheet<WeeklyReviewAction>(
    context,
    (_) => WeeklyReviewSheet(
      review: review,
      contributions: contributions,
      suggestion: suggestion,
    ),
  );
}

class WeeklyReviewSheet extends StatelessWidget {
  const WeeklyReviewSheet({
    super.key,
    required this.review,
    required this.contributions,
    this.suggestion,
    this.now,
  });

  final WeeklyReview review;
  final Contributions contributions;
  final VerifySuggestion? suggestion;

  /// Adesso; per i test.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final c = contributions;
    final r = review;
    final today = now ?? DateTime.now();
    final screen = MediaQuery.of(context).size;
    void close(WeeklyReviewAction action) => Navigator.of(context).pop(action);

    final tiles = <_Tile>[
      _Tile(
        Icons.flag_rounded,
        r.reports.length,
        'Segnalazione',
        'Segnalazioni',
        AppPalette.primary,
      ),
      _Tile(Icons.photo_camera_rounded, r.photos, 'Foto', 'Foto', colors.info),
      _Tile(
        Icons.verified_rounded,
        r.count(HelpKind.confirm),
        'Conferma',
        'Conferme',
        colors.success,
      ),
      _Tile(
        Icons.accessible_forward_rounded,
        r.count(HelpKind.pass),
        'Risposta "si passa?"',
        'Risposte "si passa?"',
        colors.info,
      ),
      _Tile(
        Icons.remove_done_rounded,
        r.count(HelpKind.gone),
        "Non c'è più",
        "Non c'è più",
        colors.warning,
      ),
    ].where((t) => t.count > 0).toList();

    final visible = c.visibleReports(today);
    final impact = <String>[
      if (r.reportsConfirmed > 0)
        r.reportsConfirmed == 1
            ? 'In quei giorni altre persone hanno confermato una tua '
                  'segnalazione.'
            : 'In quei giorni altre persone hanno confermato '
                  '${r.reportsConfirmed} tue segnalazioni.',
      if (c.confirmationsReceived > 0)
        c.confirmationsReceived == 1
            ? 'Le tue segnalazioni sono state confermate 1 volta: '
                  "un'informazione utile."
            : 'Le tue segnalazioni sono state confermate '
                  '${c.confirmationsReceived} volte: informazioni utili.',
      if (c.thanksReceived > 0)
        c.thanksReceived == 1
            ? 'Una persona ti ha detto grazie.'
            : '${c.thanksReceived} persone ti hanno detto grazie.',
      if (visible > 0)
        visible == 1
            ? 'Un ostacolo segnalato da te è sulla mappa e aiuta a '
                  'calcolare percorsi accessibili.'
            : '$visible ostacoli segnalati da te sono sulla mappa e aiutano '
                  'a calcolare percorsi accessibili.',
    ];

    final latest = r.reports.firstOrNull;
    final toNext = c.pointsToNextLevel;
    final next = c.level.next;

    final body = <Widget>[
      Text(
        'Grazie per aver condiviso quello che sai della tua città: ecco cosa '
        'hai fatto e quanto è servito alle altre persone.',
        style: textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: 20),
      Text(
        r.total == 1
            ? 'Hai fatto 1 contributo ${r.range.label}'
            : 'Hai fatto ${r.total} contributi ${r.range.label}',
        style: textTheme.titleMedium,
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) {
          // Quattro per riga se c'è spazio, altrimenti due.
          final perRow = constraints.maxWidth >= 390 ? 4 : 2;
          final width = (constraints.maxWidth - 10.0 * (perRow - 1)) / perRow;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final t in tiles) t.build(context, width)],
          );
        },
      ),
      if (latest != null) ...[
        const SizedBox(height: 20),
        Text('La tua segnalazione più recente', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: latest.color.withValues(alpha: 0.14),
                child: Icon(latest.icon, color: latest.color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(latest.type, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      ReportStatus.of(latest, today).label,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      if (impact.isNotEmpty) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.successSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Il tuo impatto',
                style: textTheme.titleSmall?.copyWith(color: colors.success),
              ),
              for (final line in impact) ...[
                const SizedBox(height: 6),
                Text(
                  line,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      Semantics(
        container: true,
        label:
            'Livello ${c.level.title}, ${c.points} punti'
            '${toNext == null ? '' : ', ne mancano $toNext per ${next!.title}'}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: AppPalette.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.level.title, style: textTheme.titleMedium),
                ),
                Text('${c.points} punti', style: textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              toNext == null
                  ? 'Hai raggiunto il livello più alto. Grazie!'
                  : 'Ancora $toNext punt${toNext == 1 ? 'o' : 'i'} per '
                        '«${next!.title}»',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: c.levelProgress,
                minHeight: 10,
                backgroundColor: colors.surfaceMuted,
                color: AppPalette.accent,
              ),
            ),
          ],
        ),
      ),
      if (suggestion != null) ...[
        const SizedBox(height: 20),
        VerifySuggestionCard(
          suggestion: suggestion!,
          now: today,
          onVerify: () => close(WeeklyReviewAction.verify),
        ),
      ],
      const SizedBox(height: 20),
      NextBadgeCard(contributions: c),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => close(WeeklyReviewAction.contribute),
        icon: const Icon(Icons.add_location_alt_rounded, size: 19),
        label: const Text('Contribuisci ancora'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => close(WeeklyReviewAction.showAll),
        child: const Text('Vedi le tue segnalazioni'),
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screen.height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: DragHandle()),
          const SheetHeader(
            title: 'La tua settimana',
            subtitle: 'Grazie per il tuo aiuto',
            icon: Icons.volunteer_activism_rounded,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un riquadro con il numero di contributi di un tipo.
class _Tile {
  const _Tile(this.icon, this.count, this.one, this.many, this.color);

  final IconData icon;
  final int count;
  final String one;
  final String many;
  final Color color;

  Widget build(BuildContext context, double width) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final label = count == 1 ? one : many;
    return Semantics(
      label: '$count $label',
      excludeSemantics: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 8),
            Text('$count', style: textTheme.titleMedium),
            Text(
              label,
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
