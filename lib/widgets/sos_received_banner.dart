import 'package:flutter/material.dart';

import '../services/sos_service.dart';

class SOSReceivedBanner extends StatelessWidget {
  final SOSAlertModel alert;
  final VoidCallback onViewLocation;

  const SOSReceivedBanner({
    super.key,
    required this.alert,
    required this.onViewLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${alert.triggeredByName} needs help! \u{1F6A8}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        FilledButton(
          onPressed: onViewLocation,
          child: const Text('View Location'),
        ),
      ],
    );
  }
}
