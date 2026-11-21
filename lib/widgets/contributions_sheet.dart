import 'package:flutter/material.dart';

import '../models/contributions.dart';
import '../models/obstacle.dart';
import '../theme/app_theme.dart';

/// Apre "Le tue segnalazioni". Toccando una segnalazione la scheda si chiude
/// e restituisce l'ostacolo, da mostrare sulla mappa.
Future<Obstacle?> showContributionsSheet(
  BuildContext context,
  Contributions contributions,
) {
  return showModalBottomSheet<Obstacle>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => ContributionsView(
        contributions: contributions,
        controller: controller,
        onOpen: (obstacle) => Navigator.pop(context, obstacle),
      ),
    ),
  );
}

class ContributionsView extends StatelessWidget {
  const ContributionsView({
    super.key,
    required this.contributions,
    required this.onOpen,
    this.controller,
    this.now,
  });

  final Contributions contributions;
  final ValueChanged<Obstacle> onOpen;
  final ScrollController? controller;

  /// Adesso; per i test.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final c = contributions;
    final today = now ?? DateTime.now();
    final toNext = c.pointsToNextLevel;
    final next = c.level.next;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text('Le tue segnalazioni', style: textTheme.titleLarge),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          label:
              'Livello ${c.level.title}, ${c.points} punti'
              '${toNext == null ? '' : ', ne mancano $toNext per ${next!.title}'}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppPalette.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(c.level.title, style: textTheme.titleMedium),
                    ),
                    Text('${c.points} punti', style: textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: c.levelProgress,
                    minHeight: 6,
                    backgroundColor: colors.surface,
                    valueColor: const AlwaysStoppedAnimation(
                      AppPalette.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  toNext == null
                      ? 'Hai raggiunto il livello più alto. Grazie!'
                      : 'Ancora $toNext punt${toNext == 1 ? 'o' : 'i'} per '
                            '«${next!.title}». Una segnalazione vale 3 punti, '
                            'una conferma 1.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Stat(
              icon: Icons.flag_rounded,
              value: c.reports.length,
              label: c.reports.length == 1 ? 'segnalazione' : 'segnalazioni',
            ),
            _Stat(
              icon: Icons.verified_rounded,
              value: c.confirmationsReceived,
              label: c.confirmationsReceived == 1
                  ? 'conferma ricevuta'
                  : 'conferme ricevute',
            ),
            _Stat(
              icon: Icons.favorite_rounded,
              value: c.thanksReceived,
              label: c.thanksReceived == 1 ? 'grazie' : 'grazie ricevuti',
            ),
            _Stat(
              icon: Icons.handshake_rounded,
              value: c.confirmationsGiven + c.passVotesGiven,
              label: 'aiuti agli altri',
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (c.reports.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Non hai ancora fatto segnalazioni. Quando trovi un gradino, '
              'un\'auto sullo scivolo o un cantiere, toccalo sulla mappa: '
              'aiuterai chi passa dopo di te.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          )
        else ...[
          Text(
            '${c.visibleReports(today)} di ${c.reports.length} visibili '
            'sulla mappa',
            style: textTheme.labelLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          for (final report in c.reports)
            _ReportTile(
              obstacle: report,
              status: ReportStatus.of(report, today),
              now: today,
              onTap: () => onOpen(report),
            ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppPalette.primary),
            const SizedBox(width: 6),
            Text('$value', style: textTheme.titleSmall),
            const SizedBox(width: 4),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.obstacle,
    required this.status,
    required this.now,
    required this.onTap,
  });

  final Obstacle obstacle;
  final ReportStatus status;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final o = obstacle;
    final confirmations = o.confirmedBy
        .where((uid) => !o.isReportedBy(uid))
        .length;
    final facts = [
      _when(o.reportedAt, now),
      if (confirmations > 0)
        confirmations == 1 ? '1 conferma' : '$confirmations conferme',
      if (o.thankedBy.isNotEmpty)
        o.thankedBy.length == 1 ? '1 grazie' : '${o.thankedBy.length} grazie',
      ?o.passLabel,
    ];
    final visible = status == ReportStatus.visible;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: o.color.withValues(alpha: visible ? 0.16 : 0.08),
        foregroundColor: visible ? o.color : colors.textTertiary,
        child: Icon(o.icon, size: 20),
      ),
      title: Text(o.type, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facts.join(' · ')),
          Text(
            status.label,
            style: textTheme.bodySmall?.copyWith(
              color: visible ? colors.success : colors.textTertiary,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  static const List<String> _months = [
    'gen',
    'feb',
    'mar',
    'apr',
    'mag',
    'giu',
    'lug',
    'ago',
    'set',
    'ott',
    'nov',
    'dic',
  ];

  static String _when(DateTime? date, DateTime now) {
    if (date == null) return 'Data non nota';
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (days <= 0) return 'Oggi';
    if (days == 1) return 'Ieri';
    final year = date.year == now.year ? '' : ' ${date.year}';
    return '${date.day} ${_months[date.month - 1]}$year';
  }
}
