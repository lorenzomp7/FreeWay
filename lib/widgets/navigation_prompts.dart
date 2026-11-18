import 'package:flutter/material.dart';

import '../models/entrance_report.dart';
import '../models/obstacle.dart';
import '../theme/app_theme.dart';

/// Riquadro in basso durante la navigazione: domanda, testo e pulsanti.
class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
    required this.onClose,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    // liveRegion: i lettori di schermo leggono la domanda appena compare.
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(20),
          boxShadow: softShadow(colors),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(message, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
          ],
        ),
      ),
    );
  }
}

/// "C'è ancora?" su un ostacolo vicino, come le domande "Still there / Not
/// there" che Google Maps fa durante il viaggio.
class ObstacleVerifyCard extends StatelessWidget {
  const ObstacleVerifyCard({
    super.key,
    required this.obstacle,
    required this.canRemove,
    required this.onStillThere,
    required this.onGone,
    required this.onSkip,
  });

  final Obstacle obstacle;

  /// Un ospite non può togliere le segnalazioni degli altri: allora manca
  /// il pulsante "Non c'è più".
  final bool canRemove;
  final VoidCallback onStillThere;
  final VoidCallback onGone;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _PromptCard(
      icon: obstacle.icon,
      iconColor: obstacle.color,
      title: "C'è ancora?",
      message: '${obstacle.type}. La tua risposta aiuta chi passa dopo di te.',
      onClose: onSkip,
      actions: [
        FilledButton.icon(
          onPressed: onStillThere,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text("C'è ancora"),
        ),
        if (canRemove)
          OutlinedButton.icon(
            onPressed: onGone,
            icon: const Icon(Icons.remove_done_rounded, size: 18),
            label: const Text("Non c'è più"),
          ),
        TextButton(onPressed: onSkip, child: const Text('Non so')),
      ],
    );
  }
}

/// Avviso di un ostacolo segnalato sul percorso durante la navigazione, con
/// il percorso alternativo se c'è ("Rerouting to avoid road closure").
class RouteAlertCard extends StatelessWidget {
  const RouteAlertCard({
    super.key,
    required this.obstacle,
    required this.isSearching,
    required this.hasAlternative,
    required this.extraMinutes,
    required this.onUseAlternative,
    required this.onKeepRoute,
  });

  final Obstacle obstacle;

  /// Si sta ancora cercando un percorso alternativo.
  final bool isSearching;
  final bool hasAlternative;

  /// Minuti in più (o in meno, se negativi) del percorso alternativo.
  final int extraMinutes;
  final VoidCallback onUseAlternative;
  final VoidCallback onKeepRoute;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final String message;
    if (isSearching) {
      message = '${obstacle.type}. Cerco un percorso che lo eviti…';
    } else if (hasAlternative) {
      final delta = extraMinutes > 0
          ? '$extraMinutes min in più'
          : extraMinutes < 0
          ? '${-extraMinutes} min in meno'
          : 'stesso tempo';
      message = '${obstacle.type}. Percorso alternativo trovato: $delta.';
    } else {
      message = '${obstacle.type}. Nessun altro percorso lo evita.';
    }
    return _PromptCard(
      icon: Icons.warning_amber_rounded,
      iconColor: colors.warning,
      title: 'Nuovo ostacolo sul percorso',
      message: message,
      onClose: onKeepRoute,
      actions: [
        if (isSearching)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (hasAlternative) ...[
          FilledButton.icon(
            onPressed: onUseAlternative,
            icon: const Icon(Icons.alt_route_rounded, size: 18),
            label: const Text('Usa il nuovo percorso'),
          ),
          TextButton(
            onPressed: onKeepRoute,
            child: const Text('Resta su questo'),
          ),
        ] else
          TextButton(onPressed: onKeepRoute, child: const Text('Ho capito')),
      ],
    );
  }
}

/// "Stai ancora andando a…?": riprende una navigazione interrotta, come
/// "Still heading to…?" di Google Maps.
class ResumeTripCard extends StatelessWidget {
  const ResumeTripCard({
    super.key,
    required this.destination,
    required this.onResume,
    required this.onDismiss,
  });

  final String destination;
  final VoidCallback onResume;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return _PromptCard(
      icon: Icons.navigation_rounded,
      iconColor: AppPalette.primary,
      title: 'Stai ancora andando a $destination?',
      message: 'La navigazione si è interrotta prima dell\'arrivo.',
      onClose: onDismiss,
      actions: [
        FilledButton.icon(
          onPressed: onResume,
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Riprendi'),
        ),
        TextButton(onPressed: onDismiss, child: const Text('No')),
      ],
    );
  }
}

/// "Com'era l'ingresso?" all'arrivo, come la domanda sul parcheggio che
/// alcuni navigatori fanno a destinazione. Le risposte compaiono nella
/// scheda del luogo per chi ci andrà dopo.
class ArrivalEntranceCard extends StatelessWidget {
  const ArrivalEntranceCard({
    super.key,
    required this.onAnswer,
    required this.onSkip,
  });

  final ValueChanged<EntranceAnswer> onAnswer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _PromptCard(
      icon: Icons.door_front_door_outlined,
      iconColor: AppPalette.primary,
      title: "Com'era l'ingresso?",
      message:
          'La tua risposta compare nella scheda del luogo per chi ci '
          'andrà dopo di te.',
      onClose: onSkip,
      actions: [
        FilledButton.icon(
          onPressed: () => onAnswer(EntranceAnswer.accessible),
          icon: const Icon(Icons.accessible_rounded, size: 18),
          label: Text(EntranceAnswer.accessible.label),
        ),
        OutlinedButton.icon(
          onPressed: () => onAnswer(EntranceAnswer.steps),
          icon: const Icon(Icons.stairs_outlined, size: 18),
          label: Text(EntranceAnswer.steps.label),
        ),
        OutlinedButton(
          onPressed: () => onAnswer(EntranceAnswer.notFound),
          child: Text(EntranceAnswer.notFound.label),
        ),
      ],
    );
  }
}
