import 'package:flutter/material.dart';

import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

typedef PointCallback = void Function({required bool isStart});

/// Pannello di ricerca con partenza, arrivo, suggerimenti e calcolo percorso.
class SearchPanel extends StatelessWidget {
  const SearchPanel({
    super.key,
    required this.startController,
    required this.endController,
    required this.startSuggestions,
    required this.endSuggestions,
    required this.isLocatingStart,
    required this.isLocatingEnd,
    required this.isCalculating,
    required this.canCalculate,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onSelectSuggestion,
    required this.onUseMyLocation,
    required this.onClear,
    required this.onSwap,
    required this.onCalculate,
  });

  final TextEditingController startController;
  final TextEditingController endController;
  final List<Map<String, dynamic>> startSuggestions;
  final List<Map<String, dynamic>> endSuggestions;
  final bool isLocatingStart;
  final bool isLocatingEnd;
  final bool isCalculating;
  final bool canCalculate;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final void Function(Map<String, dynamic> place, bool isStart) onSelectSuggestion;
  final PointCallback onUseMyLocation;
  final PointCallback onClear;
  final VoidCallback onSwap;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final suggestions = startSuggestions.isNotEmpty
        ? startSuggestions
        : (endSuggestions.isNotEmpty ? endSuggestions : const <Map<String, dynamic>>[]);
    final suggestionsForStart = startSuggestions.isNotEmpty;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        child: Row(
          children: [
            const RouteDots(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchField(
                    controller: startController,
                    hint: 'Punto di partenza',
                    isLoading: isLocatingStart,
                    onChanged: onStartChanged,
                    onClear: () => onClear(isStart: true),
                    onUseMyLocation: () => onUseMyLocation(isStart: true),
                  ),
                  Divider(height: 1, thickness: 1, color: colors.border),
                  SearchField(
                    controller: endController,
                    hint: 'Dove vuoi andare?',
                    isLoading: isLocatingEnd,
                    onChanged: onEndChanged,
                    onClear: () => onClear(isStart: false),
                    onUseMyLocation: () => onUseMyLocation(isStart: false),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SwapButton(onTap: onSwap),
          ],
        ),
      ),
    ];

    if (suggestions.isNotEmpty) {
      children.add(SuggestionsList(
        suggestions: List.of(suggestions),
        isStart: suggestionsForStart,
        onSelect: onSelectSuggestion,
      ));
    }

    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isCalculating || !canCalculate ? null : onCalculate,
          icon: isCalculating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.directions_walk_rounded, size: 24),
          label: Text(
            isCalculating ? 'Calcolo in corso…' : 'Calcola percorso pedonale',
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 56),
            textStyle: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    ));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: softShadow(colors),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Indicatore verticale partenza → arrivo accanto ai campi di ricerca.
class RouteDots extends StatelessWidget {
  const RouteDots({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 16,
      height: 112,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.startGreen, width: 3.5),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                4,
                (_) => Container(
                  width: 2,
                  height: 3,
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
          const Icon(
            Icons.location_on_rounded,
            size: 20,
            color: AppPalette.primary,
          ),
        ],
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.isLoading,
    required this.onChanged,
    required this.onClear,
    required this.onUseMyLocation,
  });

  final TextEditingController controller;
  final String hint;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onUseMyLocation;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.textTheme.titleMedium,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.bodyLarge
                    ?.copyWith(color: colors.textTertiary),
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return SmallIconButton(
                icon: Icons.close_rounded,
                onTap: onClear,
                tooltip: 'Cancella',
              );
            },
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            SmallIconButton(
              icon: Icons.my_location_rounded,
              onTap: onUseMyLocation,
              tooltip: 'Usa la mia posizione',
            ),
        ],
      ),
    );
  }
}

class SmallIconButton extends StatelessWidget {
  const SmallIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.of(context).textTertiary, size: 24),
        ),
      ),
    );
  }
}

class SwapButton extends StatelessWidget {
  const SwapButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: 'Inverti partenza e arrivo',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.swap_vert_rounded,
            color: colors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class SuggestionsList extends StatelessWidget {
  const SuggestionsList({
    super.key,
    required this.suggestions,
    required this.isStart,
    required this.onSelect,
  });

  final List<Map<String, dynamic>> suggestions;
  final bool isStart;
  final void Function(Map<String, dynamic> place, bool isStart) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final place = suggestions[index];
          final label = formatPlace(place);
          return InkWell(
            onTap: () => onSelect(place, isStart),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.place_outlined,
                      color: colors.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                        if (label.subtitle.isNotEmpty)
                          Text(
                            label.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Barra compatta mostrata quando il pannello di ricerca è chiuso.
class CollapsedSearchBar extends StatelessWidget {
  const CollapsedSearchBar({
    super.key,
    required this.startText,
    required this.endText,
    required this.onTap,
  });

  final String startText;
  final String endText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(context).textTheme.titleMedium;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(999),
            boxShadow: softShadow(colors),
          ),
          child: Row(
            children: [
              const Icon(Icons.route_rounded, size: 24, color: AppPalette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        startText.isEmpty ? 'Partenza' : startText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.textTertiary,
                        size: 18,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        endText.isEmpty ? 'Arrivo' : endText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit_outlined, color: colors.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
