import 'package:flutter/material.dart';

import '../models/info_page.dart';
import '../theme/app_theme.dart';
import 'common.dart';

Future<void> showInfoSheet(BuildContext context, InfoPage page) {
  return showAppBottomSheet<void>(context, (_) => InfoSheet(page: page));
}

class InfoSheet extends StatelessWidget {
  const InfoSheet({super.key, required this.page});

  final InfoPage page;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screen = MediaQuery.of(context).size;

    final body = <Widget>[
      for (final paragraph in page.paragraphs) ...[
        Text(
          paragraph,
          style: textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 12),
      ],
      if (page.bullets.isNotEmpty) ...[
        const SizedBox(height: 4),
        for (final bullet in page.bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppPalette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bullet,
                    style: textTheme.bodyLarge
                        ?.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primarySoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          page.footer,
          style: textTheme.titleSmall?.copyWith(
            color: isDark ? colors.textPrimary : AppPalette.primaryDark,
            height: 1.45,
          ),
        ),
      ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screen.height * 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: DragHandle()),
          SheetHeader(
            title: page.title,
            subtitle: page.subtitle,
            icon: page.icon,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collegamenti testuali alle schede informative (schermata di accesso).
class InfoLinks extends StatelessWidget {
  const InfoLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        for (final page in infoPages)
          TextButton(
            onPressed: () => showInfoSheet(context, page),
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              textStyle: Theme.of(context).textTheme.labelMedium,
            ),
            child: Text(page.title),
          ),
      ],
    );
  }
}
