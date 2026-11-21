import 'package:flutter/material.dart';

/// Chiede conferma prima di condividere la posizione, dicendo chiaramente chi
/// la vede e per quanto.
Future<bool> showShareTripConsent(
  BuildContext context,
  String destination,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.share_location_rounded),
      title: const Text('Condividi il viaggio'),
      content: Text(
        'Chi ha il link vedrà sulla mappa dove sei, la destinazione '
        '($destination) e quando arrivi. La condivisione finisce all\'arrivo, '
        'quando la interrompi o dopo 4 ore. Non vengono condivisi nome né '
        'email.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Condividi e copia il link'),
        ),
      ],
    ),
  );
  return result ?? false;
}

enum ShareTripAction { copyLink, stop }

/// Con la condivisione attiva: ricopiare il link o interromperla.
Future<ShareTripAction?> showShareTripOptions(BuildContext context) {
  return showModalBottomSheet<ShareTripAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.share_location_rounded),
            title: Text('Stai condividendo il viaggio'),
            subtitle: Text('Chi ha il link vede dove sei fino all\'arrivo.'),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Copia di nuovo il link'),
            onTap: () => Navigator.of(context).pop(ShareTripAction.copyLink),
          ),
          ListTile(
            leading: Icon(
              Icons.location_off_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Interrompi la condivisione'),
            onTap: () => Navigator.of(context).pop(ShareTripAction.stop),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
