import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../theme/app_theme.dart';

/// Impostazioni della voce di navigazione: lingua, voce attiva, volume e
/// velocità, con una frase di prova. Le scelte si applicano subito.
Future<void> showVoiceSettingsSheet(
  BuildContext context, {
  required TtsService tts,
  required String language,
  required ValueChanged<String> onLanguageChanged,
  required ValueChanged<bool> onMutedChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.of(context).surface,
    showDragHandle: true,
    builder: (context) => VoiceSettingsSheet(
      tts: tts,
      initialLanguage: language,
      onLanguageChanged: onLanguageChanged,
      onMutedChanged: onMutedChanged,
    ),
  );
}

class VoiceSettingsSheet extends StatefulWidget {
  const VoiceSettingsSheet({
    super.key,
    required this.tts,
    required this.initialLanguage,
    required this.onLanguageChanged,
    required this.onMutedChanged,
  });

  final TtsService tts;
  final String initialLanguage;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onMutedChanged;

  @override
  State<VoiceSettingsSheet> createState() => _VoiceSettingsSheetState();
}

class _VoiceSettingsSheetState extends State<VoiceSettingsSheet> {
  late String _language = widget.initialLanguage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tts = widget.tts;
    Widget title(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(text, style: textTheme.titleSmall),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voce di navigazione', style: textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Istruzioni a voce'),
              value: !tts.muted,
              onChanged: (on) {
                setState(() => tts.muted = !on);
                if (!on) tts.stop();
                widget.onMutedChanged(!on);
              },
            ),
            title('Lingua'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'it', label: Text('Italiano')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {_language},
              onSelectionChanged: (value) {
                setState(() => _language = value.first);
                widget.onLanguageChanged(value.first);
              },
            ),
            title('Annunci'),
            SegmentedButton<VoiceGuidanceMode>(
              segments: [
                for (final m in VoiceGuidanceMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {tts.guidance},
              onSelectionChanged: (value) {
                setState(() => tts.guidance = value.first);
                tts.saveSettings();
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tts.guidance == VoiceGuidanceMode.full
                    ? 'Annuncia ogni svolta in anticipo e quando è il momento.'
                    : 'Solo quando è il momento di svoltare, all\'arrivo e '
                          'per gli ostacoli.',
                style: textTheme.bodySmall,
              ),
            ),
            title('Volume'),
            SegmentedButton<VoiceVolume>(
              segments: [
                for (final v in VoiceVolume.values)
                  ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {tts.volume},
              onSelectionChanged: (value) {
                setState(() => tts.volume = value.first);
                tts.saveSettings();
              },
            ),
            title('Velocità'),
            SegmentedButton<VoiceSpeed>(
              segments: [
                for (final v in VoiceSpeed.values)
                  ButtonSegment(value: v, label: Text(v.label)),
              ],
              selected: {tts.speed},
              onSelectionChanged: (value) {
                setState(() => tts.speed = value.first);
                tts.saveSettings();
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: tts.muted ? null : () => tts.test(_language),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Prova la voce'),
            ),
            const SizedBox(height: 4),
            Text(
              'Tocca l\'istruzione in alto per sentirla di nuovo.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
