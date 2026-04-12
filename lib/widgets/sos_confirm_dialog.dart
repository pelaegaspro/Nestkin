import 'package:flutter/material.dart';

class SOSConfirmDialog extends StatelessWidget {
  const SOSConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send SOS'),
      content: const Text(
        'Send SOS to your family? They will see your location.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Send SOS \u{1F6A8}'),
        ),
      ],
    );
  }
}
