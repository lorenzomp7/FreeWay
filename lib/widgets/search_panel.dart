import 'package:flutter/material.dart';

import '../services/geocoding_service.dart';
import '../theme/app_theme.dart';

typedef PointCallback = void Function({required bool isStart});

/// Larghezza massima dei pannelli di ricerca sugli schermi larghi, come la
/// casella di ricerca di Google Maps.
const double kSearchPanelMaxWidth = 408;

/// Pannello di ricerca in due fasi, come in Google Maps:
///
/// * ricerca: un solo campo per cercare il luogo da raggiungere;
/// * indicazioni: partenza e arrivo, suggerimenti e calcolo del percorso.
class SearchPanel extends StatelessWidget {
  const SearchPanel({
    super.key,
    required this.isDirectionsMode,
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
    required this.onOpenDirections,
    required this.onCloseDirections,
  });

  final bool isDirectionsMode;
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
  final VoidCallback onOpenDirections;
  final VoidCallback onCloseDirections;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final children = isDirectionsMode
        ? _buildDirections(context, colors)
        : _buildSearch(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(isDirectionsMode ? 24 : 28),
        boxShadow: softShadow(colors),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  /// Fase 1: un solo campo per cercare la destinazione.
  List<Widget> _buildSearch(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 22,
              color: AppColors.of(context).textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchField(
                controller: endController,
                hint: 'Cerca un luogo',
                isLoading: isLocatingEnd,
                onChanged: onEndChanged,
                onClear: () => onClear(isStart: false),
              ),
            ),
            const SizedBox(width: 4),
            DirectionsButton(onTap: onOpenDirections),
          ],
        ),
      ),
      if (endSuggestions.isNotEmpty)
        SuggestionsList(
          suggestions: List.of(endSuggestions),
          isStart: false,
          onSelect: onSelectSuggestion,
        ),
    ];
  }

  /// Fase 2: scelta della partenza e calcolo del percorso.
  List<Widget> _buildDirections(BuildContext context, AppColors colors) {
    final suggestions = startSuggestions.isNotEmpty
        ? startSuggestions
        : (endSuggestions.isNotEmpty ? endSuggestions : const <Map<String, dynamic>>[]);
    final suggestionsForStart = startSuggestions.isNotEmpty;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Row(
          children: [
            SmallIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onCloseDirections,
              tooltip: 'Torna alla ricerca',
            ),
            const SizedBox(width: 2),
            const RouteDots(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SearchField(
                    controller: startController,
                    hint: 'Scegli il punto di partenza',
                    // Se manca la partenza il cursore va subito qui.
                    autofocus: startController.text.isEmpty,
                    isLoading: isLocatingStart,
                    onChanged: onStartChanged,
                    onClear: () => onClear(isStart: true),
                    onUseMyLocation: () => onUseMyLocation(isStart: true),
                  ),
                  Divider(height: 1, thickness: 1, color: colors.border),
                  SearchField(
                    controller: endController,
                    hint: 'Scegli la destinazione',
                    isLoading: isLocatingEnd,
                    onChanged: onEndChanged,
                    onClear: () => onClear(isStart: false),
                    onUseMyLocation: () => onUseMyLocation(isStart: false),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SwapButton(onTap: onSwap),
          ],
        ),
      ),
      if (suggestions.isNotEmpty)
        SuggestionsList(
          suggestions: List.of(suggestions),
          isStart: suggestionsForStart,
          onSelect: onSelectSuggestion,
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isCalculating || !canCalculate ? null : onCalculate,
            icon: isCalculating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.directions_walk_rounded, size: 20),
            label: Text(
              isCalculating ? 'Calcolo in corso…' : 'Calcola percorso pedonale',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              textStyle: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontSize: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Pulsante "Indicazioni" nella casella di ricerca.
class DirectionsButton extends StatelessWidget {
  const DirectionsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Indicazioni',
      child: Material(
        color: AppPalette.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.directions_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
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
      width: 14,
      height: 88,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.startGreen, width: 3),
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
            size: 16,
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
    this.onUseMyLocation,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  /// Se `null` il pulsante "Usa la mia posizione" non viene mostrato.
  final VoidCallback? onUseMyLocation;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.bodyLarge
                    ?.copyWith(fontSize: 15, color: colors.textTertiary),
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
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (onUseMyLocation != null)
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
          child: Icon(icon, color: AppColors.of(context).textTertiary, size: 20),
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.swap_vert_rounded,
            color: colors.textSecondary,
            size: 20,
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.place_outlined,
                      color: colors.textSecondary,
                      size: 18,
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
                          style: textTheme.titleSmall,
                        ),
                        if (label.subtitle.isNotEmpty)
                          Text(
                            label.subtitle,
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
    final style = Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(fontSize: 15, fontWeight: FontWeight.w500);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 48,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(999),
            boxShadow: softShadow(colors),
          ),
          child: Row(
            children: [
              const Icon(Icons.route_rounded, size: 20, color: AppPalette.primary),
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
                        size: 14,
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
              Icon(Icons.edit_outlined, color: colors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
