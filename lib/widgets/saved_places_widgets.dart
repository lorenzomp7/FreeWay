import 'package:flutter/material.dart';

import '../services/saved_places_service.dart';
import '../theme/app_theme.dart';

IconData savedKindIcon(SavedKind kind) => switch (kind) {
  SavedKind.home => Icons.home_rounded,
  SavedKind.work => Icons.work_rounded,
  SavedKind.other => Icons.bookmark_rounded,
};

/// Cosa ha scelto la persona nella scheda "Salva".
sealed class SaveChoice {
  const SaveChoice();
}

class SaveAs extends SaveChoice {
  const SaveAs(this.kind, [this.label]);

  final SavedKind kind;
  final String? label;
}

class RemoveSaved extends SaveChoice {
  const RemoveSaved(this.saved);

  final SavedPlace saved;
}

/// Scheda "Salva" del luogo: Casa, Lavoro o un nome a scelta, come le liste
/// di Google Maps. Se il luogo è già salvato, lo si può anche togliere.
Future<SaveChoice?> showSavePlaceSheet(
  BuildContext context, {
  required String placeName,
  required List<SavedPlace> current,
  SavedPlace? home,
  SavedPlace? work,
}) {
  return showModalBottomSheet<SaveChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SavePlaceSheet(
      placeName: placeName,
      current: current,
      home: home,
      work: work,
    ),
  );
}

class SavePlaceSheet extends StatefulWidget {
  const SavePlaceSheet({
    super.key,
    required this.placeName,
    required this.current,
    this.home,
    this.work,
  });

  final String placeName;
  final List<SavedPlace> current;

  /// Casa e Lavoro di adesso, per dire che verranno sostituiti.
  final SavedPlace? home;
  final SavedPlace? work;

  @override
  State<SavePlaceSheet> createState() => _SavePlaceSheetState();
}

class _SavePlaceSheetState extends State<SavePlaceSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.placeName,
  );
  bool _naming = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _isCurrent(SavedKind kind) => widget.current.any((s) => s.kind == kind);

  String? _replaces(SavedPlace? saved, SavedKind kind) {
    if (saved == null || _isCurrent(kind)) return null;
    final name = saved.place['name'] ?? saved.place['display_name'];
    return name == null ? 'Sostituisce quello di prima' : 'Ora: $name';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Salva «${widget.placeName}»',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
            ),
            if (!_naming) ...[
              _option(
                icon: Icons.home_rounded,
                title: 'Casa',
                subtitle: _isCurrent(SavedKind.home)
                    ? 'Già salvato come Casa'
                    : _replaces(widget.home, SavedKind.home),
                enabled: !_isCurrent(SavedKind.home),
                onTap: () =>
                    Navigator.pop(context, const SaveAs(SavedKind.home)),
              ),
              _option(
                icon: Icons.work_rounded,
                title: 'Lavoro',
                subtitle: _isCurrent(SavedKind.work)
                    ? 'Già salvato come Lavoro'
                    : _replaces(widget.work, SavedKind.work),
                enabled: !_isCurrent(SavedKind.work),
                onTap: () =>
                    Navigator.pop(context, const SaveAs(SavedKind.work)),
              ),
              _option(
                icon: Icons.bookmark_add_outlined,
                title: 'Con un nome',
                subtitle: 'Per esempio «Ambulatorio» o «Casa di Anna»',
                onTap: () => setState(() => _naming = true),
              ),
              if (widget.current.isNotEmpty) ...[
                Divider(color: colors.border, height: 16),
                for (final saved in widget.current)
                  _option(
                    icon: Icons.bookmark_remove_outlined,
                    iconColor: colors.danger,
                    title: 'Togli «${saved.label}» dai salvati',
                    onTap: () => Navigator.pop(context, RemoveSaved(saved)),
                  ),
              ],
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      autofocus: true,
                      maxLength: SavedPlacesService.maxLabelLength,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _saveNamed(),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _saveNamed,
                      icon: const Icon(Icons.bookmark_rounded),
                      label: const Text('Salva'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _saveNamed() =>
      Navigator.pop(context, SaveAs(SavedKind.other, _name.text));

  Widget _option({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? iconColor : null),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: onTap,
    );
  }
}

/// Scorciatoie "Casa" e "Lavoro" sopra le ricerche recenti, come in Google
/// Maps. Se non sono ancora impostate lo dicono.
class SavedShortcuts extends StatelessWidget {
  const SavedShortcuts({
    super.key,
    required this.home,
    required this.work,
    required this.onTap,
  });

  final SavedPlace? home;
  final SavedPlace? work;
  final ValueChanged<SavedKind> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _Shortcut(
              kind: SavedKind.home,
              title: 'Casa',
              saved: home,
              onTap: () => onTap(SavedKind.home),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Shortcut(
              kind: SavedKind.work,
              title: 'Lavoro',
              saved: work,
              onTap: () => onTap(SavedKind.work),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.kind,
    required this.title,
    required this.saved,
    required this.onTap,
  });

  final SavedKind kind;
  final String title;
  final SavedPlace? saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final name = saved?.place['name'] ?? saved?.place['display_name'];
    return Semantics(
      button: true,
      label: saved == null ? '$title, non impostato' : '$title, $name',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  savedKindIcon(kind),
                  size: 20,
                  color: saved == null
                      ? colors.textTertiary
                      : AppPalette.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: textTheme.titleSmall),
                      Text(
                        saved == null ? 'Imposta' : '$name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
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
