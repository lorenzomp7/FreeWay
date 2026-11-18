import 'package:flutter/material.dart';

import '../services/along_route_service.dart';
import '../services/geocoding_service.dart' show formatDistance;
import '../theme/app_theme.dart';
import 'route_options_sheet.dart' show alongRouteIcon;

Color alongRouteColor(AlongRouteCategory category) => switch (category) {
  AlongRouteCategory.toilets => AppPalette.userBlue,
  AlongRouteCategory.benches => const Color(0xFF8A5A2B),
  AlongRouteCategory.water => const Color(0xFF0E8FA3),
};

/// Testo di un luogo lungo il percorso, per suggerimenti e lettori di schermo.
String alongRouteLabel(AlongRoutePlace place) {
  final limited = place.isLimited ? ' (parzialmente accessibile)' : '';
  return '${place.name}$limited · a ${formatDistance(place.metersFromStart)} '
      'dalla partenza';
}

/// Segnaposto di un bagno, una panchina o una fontanella lungo il percorso.
class AlongPlaceMarker extends StatelessWidget {
  const AlongPlaceMarker({super.key, required this.place, required this.onTap});

  final AlongRoutePlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = alongRouteLabel(place);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: alongRouteColor(place.category),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              alongRouteIcon(place.category),
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Segnaposto numerato di una tappa intermedia.
class StopMarker extends StatelessWidget {
  const StopMarker({super.key, required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tappa $number: $label',
      excludeSemantics: true,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF6B4BD6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Scheda di un luogo trovato lungo il percorso: nome, distanza e
/// "Aggiungi come tappa". Restituisce `true` se si sceglie di aggiungerlo.
Future<bool?> showAlongPlaceSheet(
  BuildContext context,
  AlongRoutePlace place, {
  required bool canAddStop,
  required String? reason,
}) {
  final colors = AppColors.of(context);
  final textTheme = Theme.of(context).textTheme;
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  alongRouteIcon(place.category),
                  color: alongRouteColor(place.category),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(place.name, style: textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A ${formatDistance(place.metersFromStart)} dalla partenza'
              '${place.isLimited ? ' · parzialmente accessibile' : ''}',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: canAddStop
                  ? () => Navigator.of(context).pop(true)
                  : null,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Aggiungi come tappa'),
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      ),
    ),
  );
}
