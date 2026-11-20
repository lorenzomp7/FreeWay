import 'package:flutter/material.dart';

import '../models/route_option.dart';
import '../models/route_preferences.dart';
import '../services/geocoding_service.dart' show formatDistance;
import '../services/instruction_translator.dart';
import '../theme/app_theme.dart';

/// "Opzioni del percorso": pendenza massima, cordoli, fondo e velocità.
/// Restituisce le nuove scelte, o `null` se si chiude senza salvare.
Future<RoutePreferences?> showRoutePreferencesSheet(
  BuildContext context,
  RoutePreferences current, {
  bool showWheelchairOptions = true,
}) {
  return showModalBottomSheet<RoutePreferences>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => RoutePreferencesSheet(
      initial: current,
      showWheelchairOptions: showWheelchairOptions,
    ),
  );
}

class RoutePreferencesSheet extends StatefulWidget {
  const RoutePreferencesSheet({
    super.key,
    required this.initial,
    this.showWheelchairOptions = true,
  });

  final RoutePreferences initial;

  /// Pendenza, cordoli e fondo valgono solo per il profilo carrozzina.
  final bool showWheelchairOptions;

  @override
  State<RoutePreferencesSheet> createState() => _RoutePreferencesSheetState();
}

class _RoutePreferencesSheetState extends State<RoutePreferencesSheet> {
  late RoutePreferences _prefs = widget.initial;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    Widget title(String text, String hint) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: textTheme.titleSmall),
          Text(
            hint,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Opzioni del percorso', style: textTheme.titleLarge),
            if (widget.showWheelchairOptions) ...[
              title(
                'Pendenza massima',
                'Le salite e discese più ripide si evitano.',
              ),
              SegmentedButton<MaxIncline>(
                segments: [
                  for (final v in MaxIncline.values)
                    ButtonSegment(value: v, label: Text(v.label)),
                ],
                selected: {_prefs.maxIncline},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(
                  () => _prefs = _prefs.copyWith(maxIncline: s.first),
                ),
              ),
              title(
                'Cordoli e scalini',
                'Altezza massima che riesci a superare.',
              ),
              SegmentedButton<MaxKerb>(
                segments: [
                  for (final v in MaxKerb.values)
                    ButtonSegment(value: v, label: Text(v.label)),
                ],
                selected: {_prefs.maxKerb},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _prefs = _prefs.copyWith(maxKerb: s.first)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Evita ciottoli, ghiaia e sterrato'),
                subtitle: const Text('Il percorso può diventare più lungo.'),
                value: _prefs.avoidRoughSurfaces,
                onChanged: (v) => setState(
                  () => _prefs = _prefs.copyWith(avoidRoughSurfaces: v),
                ),
              ),
            ],
            title(
              'La tua velocità',
              'I tempi di viaggio si adattano al tuo passo.',
            ),
            SegmentedButton<TravelPace>(
              segments: [
                for (final v in TravelPace.values)
                  ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {_prefs.pace},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _prefs = _prefs.copyWith(pace: s.first)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _prefs = RoutePreferences.defaults),
                  child: const Text('Ripristina'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_prefs),
                  child: const Text('Applica'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Elenco indicazioni", come "Steps" di Google Maps: tutte le svolte del
/// percorso prima di partire.
Future<void> showRouteStepsSheet(
  BuildContext context,
  RouteOption route, {
  String language = 'it',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => RouteStepsList(
        route: route,
        language: language,
        controller: controller,
      ),
    ),
  );
}

class RouteStepsList extends StatelessWidget {
  const RouteStepsList({
    super.key,
    required this.route,
    this.language = 'it',
    this.controller,
  });

  final RouteOption route;
  final String language;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final translator = InstructionTranslator(language);
    final steps = route.steps;
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: steps.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox(height: 8) : Divider(color: colors.border),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Semantics(
            header: true,
            child: Text(
              'Indicazioni · ${route.distanceText}, ${route.durationText}',
              style: textTheme.titleMedium,
            ),
          );
        }
        final step = steps[i - 1];
        var text = translator.translate(step.instruction);
        // Prima di partire "Sei arrivato/a" suona strano: è l'arrivo.
        if (step.maneuverType == 'arrive') {
          text = text
              .replaceFirst('Sei arrivato/a', 'Arrivo')
              .replaceFirst('You have arrived', 'Arrival');
        }
        final isLast = i == steps.length;
        final then = !isLast && step.distance >= 1
            ? 'poi per ${formatDistance(step.distance)}'
            : null;
        return Semantics(
          label:
              'Passo $i di ${steps.length}: $text${then == null ? '' : ', $then'}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    maneuverEmoji(step.maneuverType, step.modifier),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text, style: textTheme.bodyLarge),
                      if (then != null)
                        Text(
                          then,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
