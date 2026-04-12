import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/sos_service.dart';

class SOSHistoryScreen extends StatelessWidget {
  final String householdId;

  const SOSHistoryScreen({
    super.key,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    final service = SOSService();
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('SOS History')),
      body: StreamBuilder<List<SOSAlertModel>>(
        stream: service.historyStream(householdId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load SOS history right now.'));
          }

          final alerts = snapshot.data ?? const <SOSAlertModel>[];
          if (alerts.isEmpty) {
            return const Center(child: Text('No SOS alerts recorded yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final resolvedLabel = alert.resolvedAt == null
                  ? 'Still active'
                  : 'Resolved: ${formatter.format(alert.resolvedAt!.toDate())}';

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(alert.triggeredByColor),
                    child: const Text(
                      '!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(alert.triggeredByName),
                  subtitle: Text(
                    'Triggered: ${formatter.format(alert.triggeredAt.toDate())}\n$resolvedLabel',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
