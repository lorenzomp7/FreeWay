import 'package:flutter/material.dart';

import '../models/info_page.dart';
import '../theme/app_theme.dart';
import 'account_sheet.dart';
import 'common.dart';
import 'info_sheet.dart';

/// Barra superiore della mappa: logo, menu informazioni e logout.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.onLogout});

  final VoidCallback onLogout;

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
          PopupMenuButton<Object>(
            tooltip: 'Informazioni',
            elevation: 8,
            offset: const Offset(0, 44),
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.border),
            ),
            onSelected: (value) {
              if (value is InfoPage) {
                showInfoSheet(context, value);
              } else {
                showAccountSheet(context);
              }
            },
            itemBuilder: (context) => [
              for (final page in infoPages)
                PopupMenuItem<Object>(
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
              const PopupMenuDivider(),
              PopupMenuItem<Object>(
                value: 'account',
                height: 46,
                child: Row(
                  children: [
                    const Icon(
                      Icons.manage_accounts_outlined,
                      color: AppPalette.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'I tuoi dati',
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
