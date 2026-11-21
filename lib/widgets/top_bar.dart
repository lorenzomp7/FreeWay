import 'package:flutter/material.dart';

import '../models/info_page.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'info_sheet.dart';

/// Barra superiore della mappa: logo, menu informazioni e logout.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.onLogout, this.onOpenContributions});

  final VoidCallback onLogout;

  /// "Le tue segnalazioni"; senza, il pulsante non c'è.
  final VoidCallback? onOpenContributions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(999),
        boxShadow: softShadow(colors),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LogoBadge(),
          const SizedBox(width: 8),
          const Wordmark(),
          const SizedBox(width: 12),
          PopupMenuButton<InfoPage>(
            tooltip: 'Informazioni',
            elevation: 8,
            offset: const Offset(0, 44),
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.border),
            ),
            onSelected: (page) => showInfoSheet(context, page),
            itemBuilder: (context) => [
              for (final page in infoPages)
                PopupMenuItem<InfoPage>(
                  value: page,
                  height: 46,
                  child: Row(
                    children: [
                      Icon(page.icon, color: AppPalette.primary, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        page.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
            ],
            child: CircleIconBadge(
              icon: Icons.info_outline_rounded,
              background: colors.surfaceMuted,
              foreground: colors.textSecondary,
            ),
          ),
          if (onOpenContributions != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Le tue segnalazioni',
              child: Semantics(
                button: true,
                label: 'Le tue segnalazioni',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onOpenContributions,
                  child: CircleIconBadge(
                    icon: Icons.emoji_events_outlined,
                    background: colors.surfaceMuted,
                    foreground: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Tooltip(
            message: 'Esci',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onLogout,
              child: CircleIconBadge(
                icon: Icons.logout_rounded,
                background: colors.surfaceMuted,
                foreground: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
