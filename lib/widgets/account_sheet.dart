import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/info_page.dart';
import '../services/account_data_service.dart';
import '../theme/app_theme.dart';
import 'info_sheet.dart';

/// Apre la scheda "I tuoi dati": informativa, copia dei dati ed
/// eliminazione di account e dati.
Future<void> showAccountSheet(
  BuildContext context, {
  AccountDataService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AccountSheet(service: service ?? AccountDataService()),
  );
}

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key, required this.service});

  final AccountDataService service;

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  bool _exporting = false;
  bool _deleting = false;
  String? _message;

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _export() async {
    setState(() {
      _exporting = true;
      _message = null;
    });
    try {
      final json = await widget.service.exportJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      setState(
        () => _message =
            'Dati copiati negli appunti (JSON): incollali in un file per '
            'conservarli.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message = 'Non è stato possibile leggere i dati. Riprova.',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare account e dati?'),
        content: const Text(
          'Verranno cancellati per sempre: le tue segnalazioni con le foto, '
          'le conferme e i voti che hai dato, le ricerche e i luoghi salvati '
          'su questo dispositivo e il tuo account. Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.of(context).danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina tutto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _message = null;
    });
    try {
      final result = await widget.service.deleteEverything();
      if (!mounted) return;
      if (result == DeletionResult.needsRecentLogin) {
        setState(
          () => _message =
              'I tuoi dati sono stati eliminati. Per sicurezza, per eliminare '
              "anche l'account esci, rientra e ripeti \"Elimina account e "
              'dati".',
        );
      } else {
        // L'app torna da sola alla schermata di accesso.
        Navigator.of(context).maybePop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _message =
            'Non è stato possibile eliminare tutto. Controlla la connessione '
            'e riprova: quello che è già stato cancellato non torna.',
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final user = _user;
    final who = user == null
        ? ''
        : user.isAnonymous
        ? 'Stai usando FREE WAY come ospite.'
        : 'Account: ${user.email ?? user.displayName ?? 'senza email'}';
    final busy = _exporting || _deleting;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('I tuoi dati', style: textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              who,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text("Leggi l'informativa"),
              onPressed: busy
                  ? null
                  : () => showInfoSheet(context, privacyPage),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.content_copy_rounded),
              label: const Text('Copia i miei dati'),
              onPressed: busy ? null : _export,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: colors.danger),
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded),
              label: const Text('Elimina account e dati'),
              onPressed: busy ? null : _delete,
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_message!, style: textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
