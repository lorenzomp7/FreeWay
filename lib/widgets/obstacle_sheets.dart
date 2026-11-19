import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/obstacle.dart';
import '../services/obstacle_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Tipo di ostacolo scelto e, se c'è, la foto.
class ReportDraft {
  const ReportDraft(this.type, {this.photo});

  final String type;
  final Uint8List? photo;
}

/// Scatta o sceglie una foto; `null` se annullato.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// Foto ridotta a 1280 px e compressa, così resta sotto il limite delle
/// regole di Firestore anche quando viene da una fotocamera moderna.
Future<Uint8List?> pickReportPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 70,
  );
  return file?.readAsBytes();
}

/// Chiede il tipo di ostacolo da segnalare e una foto facoltativa;
/// restituisce `null` se annullato.
Future<ReportDraft?> showReportObstacleSheet(
  BuildContext context, {
  PhotoPicker pickPhoto = pickReportPhoto,
}) {
  return showAppBottomSheet<ReportDraft>(
    context,
    (_) => ReportObstacleSheet(pickPhoto: pickPhoto),
  );
}

/// Carica la foto di una segnalazione.
typedef PhotoLoader = Future<Uint8List?> Function(String obstacleId);

/// Azione scelta nella scheda di un ostacolo.
enum ObstacleAction {
  confirm,
  remove,
  thank,
  passYes,
  passHard,
  passNo;

  /// La risposta a "Si riesce a passare?", per le azioni che lo sono.
  PassVote? get passVote => switch (this) {
    ObstacleAction.passYes => PassVote.yes,
    ObstacleAction.passHard => PassVote.hard,
    ObstacleAction.passNo => PassVote.no,
    _ => null,
  };

  static ObstacleAction forVote(PassVote vote) => switch (vote) {
    PassVote.yes => ObstacleAction.passYes,
    PassVote.hard => ObstacleAction.passHard,
    PassVote.no => ObstacleAction.passNo,
  };
}

/// Mostra i dettagli di un ostacolo e restituisce l'azione scelta.
Future<ObstacleAction?> showObstacleDetailsSheet(
  BuildContext context,
  Obstacle obstacle, {
  String? currentUserId,
  PhotoLoader? loadPhoto,
}) {
  return showAppBottomSheet<ObstacleAction>(
    context,
    (_) => ObstacleDetailsSheet(
      obstacle: obstacle,
      currentUserId: currentUserId,
      loadPhoto: loadPhoto,
    ),
  );
}

/// Scelta davanti a una segnalazione uguale già presente lì vicino.
enum DuplicateChoice { confirmExisting, reportAnyway }

/// Avvisa che c'è già una segnalazione dello stesso tipo a [distance] metri.
Future<DuplicateChoice?> showDuplicateDialog(
  BuildContext context,
  Obstacle existing,
  double distance, {
  required bool canConfirm,
}) {
  final when = existing.reportedAt == null
      ? ''
      : ' (${timeAgo(existing.reportedAt!)})';
  return showDialog<DuplicateChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ostacolo già segnalato'),
      content: Text(
        'A ${distance.round()} m da qui c\'è già la segnalazione '
        '"${existing.type}"$when. '
        '${canConfirm ? 'Puoi confermarla invece di crearne una nuova.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DuplicateChoice.reportAnyway),
          child: const Text('Segnala comunque'),
        ),
        if (canConfirm)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(DuplicateChoice.confirmExisting),
            child: const Text('Conferma quella'),
          ),
      ],
    ),
  );
}

/// Tempo trascorso da [date] in forma breve ("3 giorni fa").
String timeAgo(DateTime date, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(date);
  if (elapsed.inMinutes < 1) return 'proprio ora';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min fa';
  if (elapsed.inHours < 24) return '${elapsed.inHours} h fa';
  final days = elapsed.inDays;
  if (days == 1) return 'ieri';
  if (days < 30) return '$days giorni fa';
  final months = days ~/ 30;
  return months == 1 ? 'un mese fa' : '$months mesi fa';
}

class ReportObstacleSheet extends StatefulWidget {
  const ReportObstacleSheet({super.key, this.pickPhoto = pickReportPhoto});

  final PhotoPicker pickPhoto;

  @override
  State<ReportObstacleSheet> createState() => _ReportObstacleSheetState();
}

class _ReportObstacleSheetState extends State<ReportObstacleSheet> {
  String? _selected;
  Uint8List? _photo;
  bool _pickingPhoto = false;

  Future<void> _addPhoto(ImageSource source) async {
    setState(() => _pickingPhoto = true);
    Uint8List? bytes;
    try {
      bytes = await widget.pickPhoto(source);
    } catch (_) {
      bytes = null;
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Non è stato possibile aprire la foto.')),
        );
      }
    }
    if (!mounted) return;
    if (bytes != null && !ObstacleService.photoFits(bytes)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('La foto è troppo grande: prova con un\'altra.'),
        ),
      );
      bytes = null;
    }
    setState(() {
      _pickingPhoto = false;
      if (bytes != null) _photo = bytes;
    });
  }

  Widget _photoSection(BuildContext context, AppColors colors) {
    final textTheme = Theme.of(context).textTheme;
    final photo = _photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: colors.textTertiary, size: 16),
              const SizedBox(width: 8),
              Text('FOTO (FACOLTATIVA)', style: textTheme.labelSmall),
            ],
          ),
        ),
        if (photo != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  photo,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto dell\'ostacolo',
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton.filledTonal(
                  tooltip: 'Togli la foto',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _photo = null),
                ),
              ),
            ],
          )
        else if (_pickingPhoto)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _addPhoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Scatta una foto'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Scegli dalla galleria'),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Aiuta gli altri a capire l\'ostacolo. Non inquadrare persone '
            'né targhe: la foto è visibile a chi usa FreeWay.',
            style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final screen = MediaQuery.of(context).size;

    final items = <Widget>[];
    for (final entry in obstacleTypesByCategory.entries) {
      items.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              obstacleCategoryIcons[entry.key] ?? Icons.place_outlined,
              color: colors.textTertiary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              entry.key.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ));
      for (final type in entry.value) {
        items.add(ObstacleOption(
          label: type,
          isSelected: _selected == type,
          onTap: () => setState(() => _selected = type),
        ));
      }
      items.add(const SizedBox(height: 12));
    }
    items.add(_photoSection(context, colors));

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screen.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: DragHandle()),
          const SheetHeader(
            title: 'Segnala un ostacolo',
            subtitle: 'Cosa rende difficile il passaggio in questo punto?',
            icon: Icons.report_problem_outlined,
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: items,
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _selected == null || _pickingPhoto
                        ? null
                        : () => Navigator.of(context)
                            .pop(ReportDraft(_selected!, photo: _photo)),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Invia segnalazione'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ObstacleOption extends StatelessWidget {
  const ObstacleOption({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.primarySoft : colors.surfaceMuted,
            border: Border.all(
              color: isSelected ? AppPalette.primary : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isSelected && !isDark
                            ? AppPalette.primaryDark
                            : colors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? AppPalette.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppPalette.primary : colors.borderStrong,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ObstacleDetailsSheet extends StatelessWidget {
  const ObstacleDetailsSheet({
    super.key,
    required this.obstacle,
    this.currentUserId,
    this.loadPhoto,
  });

  final Obstacle obstacle;
  final String? currentUserId;

  /// Per leggere la foto, se la segnalazione ne ha una.
  final PhotoLoader? loadPhoto;

  String get _formattedDate {
    final date = obstacle.reportedAt;
    if (date == null) return 'Data non disponibile';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        'alle ${two(date.hour)}:${two(date.minute)}';
  }

  String get _timeAgo {
    final date = obstacle.reportedAt;
    return date == null ? '' : timeAgo(date);
  }

  static String _formatDay(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String get _confirmationText {
    final count = obstacle.confirmationCount;
    final people = count == 1 ? '1 persona' : '$count persone';
    final last = obstacle.lastConfirmedAt;
    return last == null
        ? 'Confermato da $people'
        : 'Confermato da $people · ultima volta ${timeAgo(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final when = _timeAgo.isEmpty ? _formattedDate : '$_formattedDate · $_timeAgo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(child: DragHandle()),
          SheetHeader(
            title: 'Ostacolo segnalato',
            subtitle: obstacle.category,
            icon: obstacle.icon,
            color: obstacle.color,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (obstacle.hasPhoto && loadPhoto != null) ...[
                        ObstaclePhoto(
                          load: () => loadPhoto!(obstacle.id),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(obstacle.type, style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: colors.textTertiary,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(child: Text(when, style: textTheme.bodySmall)),
                        ],
                      ),
                      if (obstacle.expiresAt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.hourglass_bottom_rounded,
                              color: colors.textTertiary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ostacolo temporaneo: sparisce dalla mappa il '
                                '${_formatDay(obstacle.expiresAt!)} se nessuno '
                                "conferma che c'è ancora.",
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (obstacle.notThereBy.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.remove_done_rounded,
                              color: colors.textTertiary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                obstacle.notThereBy.length == 1
                                    ? "1 persona dice che non c'è più"
                                    : '${obstacle.notThereBy.length} persone '
                                        "dicono che non c'è più",
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (obstacle.thankedBy.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              color: colors.textTertiary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                thanksText(
                                  obstacle.thankedBy.length,
                                  mine: obstacle.isReportedBy(currentUserId),
                                ),
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (obstacle.passLabel != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.accessible_rounded,
                              color: colors.textTertiary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                obstacle.passLabel!,
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (obstacle.confirmationCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              color: colors.textTertiary,
                              size: 15,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _confirmationText,
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (obstacle.canVotePassBy(currentUserId)) ...[
                  Text(
                    'Si riesce a passare in sedia a rotelle?',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final vote in PassVote.values)
                        OutlinedButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(ObstacleAction.forVote(vote)),
                          child: Text(vote.label),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (obstacle.canBeThankedBy(currentUserId)) ...[
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(ObstacleAction.thank),
                    icon: const Icon(Icons.favorite_border_rounded, size: 19),
                    label: const Text("Grazie a chi l'ha segnalato"),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!obstacle.isReportedBy(currentUserId)) ...[
                  OutlinedButton.icon(
                    onPressed: obstacle.canBeConfirmedBy(currentUserId)
                        ? () => Navigator.of(context).pop(ObstacleAction.confirm)
                        : null,
                    icon: const Icon(Icons.visibility_outlined, size: 19),
                    label: Text(
                      obstacle.canBeConfirmedBy(currentUserId)
                          ? "Confermo, c'è ancora"
                          : 'Hai già confermato questo ostacolo',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(ObstacleAction.remove),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
                  label: const Text("L'ostacolo non c'è più"),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.successSoft,
                    foregroundColor: colors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rimuovendolo aiuti le altre persone a ricevere percorsi aggiornati.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto della segnalazione, caricata solo quando si apre la scheda.
class ObstaclePhoto extends StatefulWidget {
  const ObstaclePhoto({super.key, required this.load});

  final Future<Uint8List?> Function() load;

  @override
  State<ObstaclePhoto> createState() => _ObstaclePhotoState();
}

class _ObstaclePhotoState extends State<ObstaclePhoto> {
  late final Future<Uint8List?> _photo = widget.load();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    Widget placeholder(Widget child) => Container(
          height: 180,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        );
    final unavailable = placeholder(
      Text('Foto non disponibile', style: textTheme.bodySmall),
    );
    return FutureBuilder<Uint8List?>(
      future: _photo,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder(const CircularProgressIndicator());
        }
        final bytes = snapshot.data;
        if (bytes == null) return unavailable;
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            bytes,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: 'Foto dell\'ostacolo segnalato',
            errorBuilder: (_, _, _) => unavailable,
          ),
        );
      },
    );
  }
}

/// Riga dei ringraziamenti: chi ha segnalato vede "ti hanno ringraziato".
String thanksText(int count, {required bool mine}) {
  final people = count == 1 ? '1 persona' : '$count persone';
  if (mine) {
    return count == 1
        ? '1 persona ti ha ringraziato per questa segnalazione'
        : '$people ti hanno ringraziato per questa segnalazione';
  }
  return 'Ringraziato da $people';
}
