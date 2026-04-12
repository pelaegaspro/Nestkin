import 'dart:async';

import 'package:flutter/material.dart';

import '../services/sos_service.dart';

class SOSActiveBanner extends StatefulWidget {
  final SOSAlertModel alert;
  final VoidCallback onSafe;

  const SOSActiveBanner({
    super.key,
    required this.alert,
    required this.onSafe,
  });

  @override
  State<SOSActiveBanner> createState() => _SOSActiveBannerState();
}

class _SOSActiveBannerState extends State<SOSActiveBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed =
        DateTime.now().difference(widget.alert.triggeredAt.toDate());
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);

    return Row(
      children: [
        const Expanded(
          child: Text(
            '\u{1F6A8} SOS Active',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text('${hours}h ${minutes}m'),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: widget.onSafe,
          child: const Text("I'm Safe"),
        ),
      ],
    );
  }
}
