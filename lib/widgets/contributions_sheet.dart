import 'package:flutter/material.dart';

import '../models/contributions.dart';
import '../models/obstacle.dart';
import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';
import 'obstacle_sheets.dart' show timeAgo;

/// Apre "Le tue segnalazioni". Toccando una segnalazione (o "Verifica"
/// sull'ostacolo suggerito) la scheda si chiude e restituisce l'ostacolo, da
/// mostrare sulla mappa.
Future<Obstacle?> showContributionsSheet(
  BuildContext context,
  Contributions contributions, {
  VerifySuggestion? suggestion,
}) {
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
        suggestion: suggestion,
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
    this.suggestion,
    this.controller,
    this.now,
  });

  final Contributions contributions;

  /// Un ostacolo vicino da verificare ("Aiuta ancora").
  final VerifySuggestion? suggestion;
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
        if (suggestion != null) ...[
          const SizedBox(height: 18),
          VerifySuggestionCard(
            suggestion: suggestion!,
            now: today,
            onVerify: () => onOpen(suggestion!.obstacle),
          ),
        ],
        const SizedBox(height: 18),
        NextBadgeCard(contributions: c),
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
        const SizedBox(height: 18),
        BadgeGrid(contributions: c),
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

/// "Can you tell us more about the place?": un ostacolo vicino, segnalato da
/// altri, che nessuno conferma da tempo.
class VerifySuggestionCard extends StatelessWidget {
  const VerifySuggestionCard({
    super.key,
    required this.suggestion,
    required this.onVerify,
    this.now,
  });

  final VerifySuggestion suggestion;
  final VoidCallback onVerify;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final o = suggestion.obstacle;
    final today = now ?? DateTime.now();
    final confirmed = o.lastConfirmedAt;
    final reported = o.reportedAt;
    final details = [
      'a ${formatDistance(suggestion.distance)} da te',
      if (confirmed != null)
        'ultima conferma ${timeAgo(confirmed, now: today)}'
      else if (reported != null)
        'segnalato ${timeAgo(reported, now: today)}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.add_task_rounded, color: colors.info, size: 18),
              const SizedBox(width: 8),
              Text(
                'AIUTA ANCORA',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.info,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "C'è ancora questo ostacolo vicino a te?",
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: o.color.withValues(alpha: 0.14),
                child: Icon(o.icon, color: o.color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.type, style: textTheme.titleSmall),
                    Text(details, style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onVerify, child: const Text('Verifica')),
        ],
      ),
    );
  }
}

/// "Your next badge is close!": il badge più vicino e quanto manca.
class NextBadgeCard extends StatelessWidget {
  const NextBadgeCard({super.key, required this.contributions});

  final Contributions contributions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final c = contributions;
    final badge = c.nextBadge;
    if (badge == null) {
      return Text(
        'Hai ottenuto tutti i badge. Grazie per tutto quello che fai!',
        style: textTheme.titleMedium,
      );
    }
    final progress = badge.progress(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          c.earnedBadges.isEmpty
              ? 'Il tuo primo badge'
              : 'Il tuo prossimo badge è vicino!',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          '«${badge.title}»',
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: '${badge.task}: $progress su ${badge.target}',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(badge.icon, color: badge.color, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(badge.task, style: textTheme.bodyMedium)),
                const SizedBox(width: 8),
                Text('$progress/${badge.target}', style: textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tutti i badge: colorati quelli ottenuti, con il lucchetto gli altri.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.contributions});

  final Contributions contributions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final c = contributions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Badge (${c.earnedBadges.length} su ${contributionBadges.length})',
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            // Due per riga, tre sugli schermi larghi.
            final perRow = constraints.maxWidth >= 500 ? 3 : 2;
            final width = (constraints.maxWidth - 10.0 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final badge in contributionBadges)
                  _BadgeTile(
                    badge: badge,
                    contributions: c,
                    width: width,
                    colors: colors,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.contributions,
    required this.width,
    required this.colors,
  });

  final ContributionBadge badge;
  final Contributions contributions;
  final double width;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final earned = badge.isEarned(contributions);
    final progress = badge.progress(contributions);
    return Semantics(
      label: earned
          ? 'Badge ${badge.title}, ottenuto'
          : 'Badge ${badge.title}, da ottenere: ${badge.task}, '
                '$progress su ${badge.target}',
      excludeSemantics: true,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: earned
              ? badge.color.withValues(alpha: 0.10)
              : colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              earned ? badge.icon : Icons.lock_outline_rounded,
              color: earned ? badge.color : colors.textTertiary,
              size: 22,
            ),
            const SizedBox(height: 6),
            Text(badge.title, style: textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              earned ? badge.task : '${badge.task} ($progress/${badge.target})',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
