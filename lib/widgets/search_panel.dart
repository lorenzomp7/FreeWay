import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/travel_mode.dart';
import '../services/geo_utils.dart';
import '../services/geocoding_service.dart';
import '../services/saved_places_service.dart';
import '../theme/app_theme.dart';
import 'saved_places_widgets.dart';

typedef PointCallback = void Function({required bool isStart});

/// Larghezza massima dei pannelli di ricerca sugli schermi larghi, come la
/// casella di ricerca di Google Maps.
const double kSearchPanelMaxWidth = 408;

/// Le fasi della ricerca, nello stesso ordine di Google Maps.
enum SearchPhase {
  /// Un solo campo per cercare un luogo. Toccandolo compaiono le ricerche
  /// recenti, scrivendo i suggerimenti.
  search,

  /// Luogo trovato: la mappa lo evidenzia e in basso c'è la sua scheda con
  /// "Indicazioni".
  place,

  /// Partenza, arrivo e mezzo, poi il calcolo del percorso.
  directions,
}

/// Una riga dell'elenco sotto la casella di ricerca.
class SearchItem {
  const SearchItem(this.place, {this.isRecent = false, this.saved});

  final Map<String, dynamic> place;

  /// Viene dalla cronologia: icona dell'orologio e pulsante per toglierlo.
  final bool isRecent;

  /// Luogo salvato (Casa, Lavoro o con un nome): si mostra con il suo nome.
  final SavedPlace? saved;
}

/// Pannello di ricerca in alto, come la casella di Google Maps.
class SearchPanel extends StatelessWidget {
  const SearchPanel({
    super.key,
    required this.stage,
    required this.startController,
    required this.endController,
    required this.startFocus,
    required this.endFocus,
    required this.startItems,
    required this.endItems,
    required this.recentPlaces,
    this.home,
    this.work,
    this.savedPlaces = const [],
    this.onSavedShortcut,
    this.onRemoveSaved,
    required this.noResultsForStart,
    required this.noResultsForEnd,
    required this.userLocation,
    required this.isLocatingStart,
    required this.isLocatingEnd,
    required this.isCalculating,
    required this.canCalculate,
    required this.hasStartPoint,
    required this.hasEndPoint,
    required this.travelMode,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onSubmitted,
    required this.onSelectSuggestion,
    required this.onRemoveRecent,
    required this.onUseMyLocation,
    required this.onChooseOnMap,
    required this.onPaste,
    required this.onClear,
    required this.onSwap,
    required this.onCalculate,
    required this.onTravelModeChanged,
    required this.onOpenDirections,
    required this.onCloseDirections,
    required this.onClosePlace,
  });

  final SearchPhase stage;
  final TextEditingController startController;
  final TextEditingController endController;
  final FocusNode startFocus;
  final FocusNode endFocus;

  /// Suggerimenti per il campo della partenza e per quello dell'arrivo.
  final List<SearchItem> startItems;
  final List<SearchItem> endItems;

  /// Cronologia completa, mostrata quando il campo attivo è vuoto.
  final List<Map<String, dynamic>> recentPlaces;

  /// Casa e Lavoro, `null` se non impostati.
  final SavedPlace? home;
  final SavedPlace? work;

  /// Gli altri luoghi salvati con un nome.
  final List<SavedPlace> savedPlaces;

  /// Tocco su "Casa" o "Lavoro".
  final void Function(SavedKind kind, bool isStart)? onSavedShortcut;
  final ValueChanged<SavedPlace>? onRemoveSaved;

  /// Testo cercato senza risultati, o `null`.
  final String? noResultsForStart;
  final String? noResultsForEnd;
  final LatLng? userLocation;
  final bool isLocatingStart;
  final bool isLocatingEnd;
  final bool isCalculating;
  final bool canCalculate;

  /// Il campo contiene un luogo già scelto (non un testo in fase di ricerca).
  final bool hasStartPoint;
  final bool hasEndPoint;
  final TravelMode travelMode;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final void Function(bool isStart) onSubmitted;
  final void Function(Map<String, dynamic> place, bool isStart)
  onSelectSuggestion;
  final ValueChanged<Map<String, dynamic>> onRemoveRecent;
  final PointCallback onUseMyLocation;
  final PointCallback onChooseOnMap;

  /// Incolla nel campo il testo copiato (per esempio un indirizzo).
  final PointCallback onPaste;
  final PointCallback onClear;
  final VoidCallback onSwap;
  final VoidCallback onCalculate;
  final ValueChanged<TravelMode> onTravelModeChanged;
  final VoidCallback onOpenDirections;
  final VoidCallback onCloseDirections;
  final VoidCallback onClosePlace;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDirections = stage == SearchPhase.directions;
    final children = isDirections
        ? _buildDirections(context, colors)
        : _buildSearch(context);

    // Toccare un suggerimento non deve togliere il fuoco al campo prima che
    // il tocco arrivi alla riga (sul web il campo perde il fuoco subito).
    return TextFieldTapRegion(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(isDirections ? 24 : 28),
          boxShadow: softShadow(colors),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  /// Fasi "ricerca" e "luogo": un solo campo per la destinazione.
  List<Widget> _buildSearch(BuildContext context) {
    final colors = AppColors.of(context);
    final isPlace = stage == SearchPhase.place;
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(isPlace ? 4 : 16, 4, 6, 4),
        child: Row(
          children: [
            if (isPlace)
              SmallIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onClosePlace,
                tooltip: 'Torna alla ricerca',
              )
            else
              Icon(Icons.search_rounded, size: 22, color: colors.textSecondary),
            SizedBox(width: isPlace ? 4 : 12),
            Expanded(
              child: SearchField(
                controller: endController,
                focusNode: endFocus,
                hint: 'Cerca un luogo',
                isLoading: isLocatingEnd,
                onChanged: onEndChanged,
                onSubmitted: () => onSubmitted(false),
                onClear: () => onClear(isStart: false),
              ),
            ),
            const SizedBox(width: 4),
            DirectionsButton(onTap: onOpenDirections),
          ],
        ),
      ),
      if (endFocus.hasFocus)
        _dropdown(
          isStart: false,
          query: endController.text,
          items: endItems,
          noResultsFor: noResultsForEnd,
          showLocationShortcuts: false,
        ),
    ];
  }

  /// Fase "indicazioni": partenza, arrivo, mezzo e calcolo del percorso.
  List<Widget> _buildDirections(BuildContext context, AppColors colors) {
    final focusedStart = startFocus.hasFocus;
    final focusedEnd = endFocus.hasFocus;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Row(
          children: [
            SmallIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: onCloseDirections,
              tooltip: 'Chiudi le indicazioni',
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
                    focusNode: startFocus,
                    hint: 'Scegli il punto di partenza',
                    isLoading: isLocatingStart,
                    onChanged: onStartChanged,
                    onSubmitted: () => onSubmitted(true),
                    onClear: () => onClear(isStart: true),
                  ),
                  Divider(height: 1, thickness: 1, color: colors.border),
                  SearchField(
                    controller: endController,
                    focusNode: endFocus,
                    hint: 'Scegli la destinazione',
                    isLoading: isLocatingEnd,
                    onChanged: onEndChanged,
                    onSubmitted: () => onSubmitted(false),
                    onClear: () => onClear(isStart: false),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            SwapButton(onTap: onSwap),
          ],
        ),
      ),
      if (focusedStart || focusedEnd)
        _dropdown(
          isStart: focusedStart,
          query: focusedStart ? startController.text : endController.text,
          items: focusedStart ? startItems : endItems,
          noResultsFor: focusedStart ? noResultsForStart : noResultsForEnd,
          showLocationShortcuts: true,
        )
      else ...[
        TravelModeBar(selected: travelMode, onSelected: onTravelModeChanged),
        if (isCalculating)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: LinearProgressIndicator(
              minHeight: 3,
              semanticsLabel: 'Calcolo del percorso in corso',
            ),
          )
        else if (canCalculate)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCalculate,
                icon: Icon(travelMode.icon, size: 20),
                label: const Text('Calcola percorso'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    ];
  }

  Widget _dropdown({
    required bool isStart,
    required String query,
    required List<SearchItem> items,
    required String? noResultsFor,
    required bool showLocationShortcuts,
  }) {
    // Campo vuoto, o con il luogo già scelto: si mostrano scorciatoie e
    // ricerche recenti, così si può cambiare idea con un tocco.
    final showZeroState =
        query.trim().isEmpty || (isStart ? hasStartPoint : hasEndPoint);
    return SearchDropdown(
      isStart: isStart,
      items: showZeroState
          ? [
              for (final place in recentPlaces)
                SearchItem(place, isRecent: true),
            ]
          : items,
      savedItems: showZeroState
          ? [
              for (final saved in savedPlaces)
                SearchItem(saved.place, saved: saved),
            ]
          : const [],
      showSavedShortcuts: showZeroState && onSavedShortcut != null,
      home: home,
      work: work,
      onSavedShortcut: onSavedShortcut == null
          ? null
          : (kind) => onSavedShortcut!(kind, isStart),
      onRemoveSaved: onRemoveSaved,
      showRecentHeader: showZeroState,
      noResultsFor: showZeroState ? null : noResultsFor,
      userLocation: userLocation,
      showLocationShortcuts: showLocationShortcuts,
      onSelect: onSelectSuggestion,
      onRemoveRecent: onRemoveRecent,
      onUseMyLocation: () => onUseMyLocation(isStart: isStart),
      onChooseOnMap: () => onChooseOnMap(isStart: isStart),
      showPaste: showZeroState,
      onPaste: () => onPaste(isStart: isStart),
    );
  }
}

/// Elenco sotto la casella: scorciatoie, ricerche recenti e suggerimenti.
class SearchDropdown extends StatelessWidget {
  const SearchDropdown({
    super.key,
    required this.isStart,
    required this.items,
    required this.showRecentHeader,
    required this.noResultsFor,
    required this.userLocation,
    required this.showLocationShortcuts,
    required this.onSelect,
    required this.onRemoveRecent,
    required this.onUseMyLocation,
    required this.onChooseOnMap,
    this.showPaste = false,
    this.onPaste,
    this.savedItems = const [],
    this.showSavedShortcuts = false,
    this.home,
    this.work,
    this.onSavedShortcut,
    this.onRemoveSaved,
  });

  final bool isStart;
  final List<SearchItem> items;

  /// Luoghi salvati con un nome, sopra le ricerche recenti.
  final List<SearchItem> savedItems;
  final bool showSavedShortcuts;
  final SavedPlace? home;
  final SavedPlace? work;
  final ValueChanged<SavedKind>? onSavedShortcut;
  final ValueChanged<SavedPlace>? onRemoveSaved;
  final bool showRecentHeader;
  final String? noResultsFor;
  final LatLng? userLocation;
  final bool showLocationShortcuts;
  final void Function(Map<String, dynamic> place, bool isStart) onSelect;
  final ValueChanged<Map<String, dynamic>> onRemoveRecent;
  final VoidCallback onUseMyLocation;
  final VoidCallback onChooseOnMap;

  /// Riga "Incolla l'indirizzo copiato", come il suggerimento "From your
  /// clipboard" di Google Maps. Sul web gli appunti si leggono solo dopo un
  /// tocco, quindi il testo si vede dopo averla scelta.
  final bool showPaste;
  final VoidCallback? onPaste;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final rows = <Widget>[
      if (showPaste && onPaste != null)
        SearchRow(
          icon: Icons.content_paste_rounded,
          title: "Incolla l'indirizzo copiato",
          onTap: onPaste!,
        ),
      if (showLocationShortcuts) ...[
        SearchRow(
          icon: Icons.my_location_rounded,
          iconColor: AppPalette.startGreen,
          title: 'La tua posizione',
          onTap: onUseMyLocation,
        ),
        SearchRow(
          icon: Icons.push_pin_outlined,
          title: 'Scegli sulla mappa',
          onTap: onChooseOnMap,
        ),
      ],
      if (showSavedShortcuts && onSavedShortcut != null)
        SavedShortcuts(home: home, work: work, onTap: onSavedShortcut!),
      if (savedItems.isNotEmpty) ...[
        _header('Salvati', textTheme, colors),
        for (final item in savedItems) _placeRow(item),
      ],
      if (noResultsFor != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(
                Icons.search_off_rounded,
                color: colors.textTertiary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nessun risultato per «$noResultsFor». Controlla il nome o '
                  'aggiungi la città.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      if (showRecentHeader) _header('Recenti', textTheme, colors),
      if (showRecentHeader && items.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Text(
            'I luoghi che cerchi compariranno qui.',
            style: textTheme.bodySmall,
          ),
        ),
      for (final item in items) _placeRow(item),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: rows,
      ),
    );
  }

  Widget _header(String text, TextTheme textTheme, AppColors colors) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
    child: Text(
      text,
      style: textTheme.labelMedium?.copyWith(color: colors.textSecondary),
    ),
  );

  Widget _placeRow(SearchItem item) {
    final place = item.place;
    final label = formatPlace(place);
    final saved = item.saved;
    final location = userLocation;
    String? distance;
    final lat = double.tryParse('${place['lat']}');
    final lon = double.tryParse('${place['lon']}');
    if (location != null && lat != null && lon != null) {
      distance = formatDistance(haversineDistance(location, LatLng(lat, lon)));
    }
    if (saved != null) {
      return SearchRow(
        icon: savedKindIcon(saved.kind),
        iconColor: AppPalette.primary,
        title: saved.label,
        subtitle: [
          if (label.title != saved.label) label.title,
          if (label.subtitle.isNotEmpty) label.subtitle,
        ].join(', '),
        trailingText: distance,
        onTap: () => onSelect(place, isStart),
        onRemove: onRemoveSaved == null || saved.kind != SavedKind.other
            ? null
            : () => onRemoveSaved!(saved),
        removeTooltip: 'Togli dai salvati',
      );
    }
    return SearchRow(
      icon: item.isRecent
          ? Icons.history_rounded
          : placeKindIcon(place['kind']),
      title: label.title,
      subtitle: label.subtitle,
      trailingText: distance,
      onTap: () => onSelect(place, isStart),
      onRemove: item.isRecent ? () => onRemoveRecent(place) : null,
    );
  }
}

IconData placeKindIcon(Object? kind) {
  switch (kind) {
    case 'city':
      return Icons.location_city_rounded;
    case 'street':
      return Icons.signpost_outlined;
    case 'address':
      return Icons.home_outlined;
    case 'transit':
      return Icons.directions_bus_outlined;
    case 'health':
      return Icons.local_hospital_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'shop':
      return Icons.storefront_outlined;
    default:
      return Icons.place_outlined;
  }
}

/// Riga dell'elenco: icona, nome, indirizzo e distanza da te.
class SearchRow extends StatelessWidget {
  const SearchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.iconColor,
    this.trailingText,
    this.onRemove,
    this.removeTooltip = 'Elimina dalla cronologia',
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final String? trailingText;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 6, onRemove != null ? 4 : 16, 6),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: iconColor ?? colors.textSecondary,
                      size: 18,
                    ),
                  ),
                  if (trailingText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        trailingText!,
                        maxLines: 1,
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (onRemove != null)
              SmallIconButton(
                icon: Icons.close_rounded,
                onTap: onRemove,
                tooltip: removeTooltip,
              ),
          ],
        ),
      ),
    );
  }
}

/// I mezzi tra cui scegliere, come la riga di icone delle indicazioni di
/// Google Maps.
class TravelModeBar extends StatelessWidget {
  const TravelModeBar({
    super.key,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.fromLTRB(12, 2, 12, 10),
  });

  final TravelMode selected;
  final ValueChanged<TravelMode> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in TravelMode.values)
            ChoiceChip(
              avatar: Icon(
                mode.icon,
                size: 18,
                color: mode == selected ? Colors.white : colors.textSecondary,
              ),
              label: Text(mode.label),
              selected: mode == selected,
              showCheckmark: false,
              selectedColor: AppPalette.primary,
              backgroundColor: colors.surface,
              side: BorderSide(color: colors.border),
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: mode == selected ? Colors.white : colors.textPrimary,
              ),
              onSelected: (_) => onSelected(mode),
            ),
        ],
      ),
    );
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
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  /// Invio sulla tastiera: si sceglie il primo suggerimento.
  final VoidCallback? onSubmitted;

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
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted?.call(),
              style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: colors.textTertiary,
                ),
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
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
          else
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
          child: Icon(
            icon,
            color: AppColors.of(context).textTertiary,
            size: 20,
          ),
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

/// Barra compatta mostrata quando il pannello di ricerca è chiuso.
class CollapsedSearchBar extends StatelessWidget {
  const CollapsedSearchBar({
    super.key,
    required this.startText,
    required this.endText,
    required this.travelMode,
    required this.onTap,
  });

  final String startText;
  final String endText;
  final TravelMode travelMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w500);
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
              Icon(travelMode.icon, size: 20, color: AppPalette.primary),
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
