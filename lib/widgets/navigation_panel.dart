import 'package:flutter/material.dart';

import '../models/route_option.dart';
import '../services/instruction_translator.dart';
import '../services/navigation_service.dart';
import '../theme/app_theme.dart';

/// Pannello scuro con l'indicazione corrente durante la navigazione.
class NavigationPanel extends StatelessWidget {
  const NavigationPanel({
    super.key,
    required this.update,
    required this.firstStep,
    required this.gpsFailed,
    required this.language,
    required this.isMuted,
    required this.onStop,
    required this.onToggleMute,
    required this.onLanguageChanged,
  });

  final NavigationUpdate? update;
  final RouteStep firstStep;
  final bool gpsFailed;
  final String language;
  final bool isMuted;
  final VoidCallback onStop;
  final VoidCallback onToggleMute;
  final ValueChanged<String> onLanguageChanged;

  @override
  Widget build(BuildContext context) {
    final isItalian = language == 'it';
    final step = update?.currentStep ?? firstStep;
    final instruction =
        InstructionTranslator(language).translate(step.instruction);
    final emoji = maneuverEmoji(step.maneuverType, step.modifier);
    final remaining = update?.distanceToNextStep ?? 0.0;
    final distance = remaining >= 1000
        ? '${(remaining / 1000).toStringAsFixed(1)} km'
        : '${remaining.round()} m';
    final arrived = update?.hasArrived ?? false;
    final progress = update?.progress ?? 0.0;
    final status = gpsFailed
        ? (isItalian
            ? 'GPS non disponibile. Controlla i permessi di posizione.'
            : 'GPS unavailable. Check location permissions.')
        : (isItalian ? 'In attesa del GPS…' : 'Waiting for GPS…');

    final children = <Widget>[];
    if (!gpsFailed && update?.isOffRoute == true) {
      children.add(
        Container(
          width: double.infinity,
          color: AppPalette.offRouteBanner,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 15,
                color: AppPalette.offRouteText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isItalian
                      ? 'Fuori percorso — ricalcolo in corso…'
                      : 'Off route — recalculating…',
                  style: const TextStyle(
                    color: AppPalette.offRouteText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppPalette.brandGradient,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gpsFailed || update == null)
                    Text(status, style: const TextStyle(color: Colors.white))
                  else if (!arrived)
                    Text(
                      distance,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    arrived
                        ? (isItalian
                            ? 'Sei arrivato/a a destinazione'
                            : 'You have reached your destination')
                        : instruction,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: arrived
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.82),
                      fontSize: arrived ? 17 : 14.5,
                      fontWeight: arrived ? FontWeight.w700 : FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    children.add(
      Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
    );

    children.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(
                          AppPalette.primaryLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _NavIconButton(
              icon:
                  isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              tooltip: isMuted
                  ? (isItalian ? 'Attiva voce' : 'Unmute')
                  : (isItalian ? 'Disattiva voce' : 'Mute'),
              onTap: onToggleMute,
              isMuted: isMuted,
            ),
            const SizedBox(width: 6),
            _NavLanguageButton(
              label: language.toUpperCase(),
              tooltip: isItalian
                  ? 'Cambia lingua della voce'
                  : 'Change voice language',
              onTap: () => onLanguageChanged(isItalian ? 'en' : 'it'),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined, size: 17),
              label: Text(
                isItalian ? 'Termina' : 'Stop',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppPalette.primary.withValues(alpha: 0.16),
                foregroundColor: AppPalette.primaryLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppPalette.navigationPanel,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                offset: const Offset(0, 10),
                blurRadius: 24,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isMuted,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppPalette.navigationButton,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: isMuted ? 0.4 : 0.9),
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _NavLanguageButton extends StatelessWidget {
  const _NavLanguageButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppPalette.navigationButton,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
