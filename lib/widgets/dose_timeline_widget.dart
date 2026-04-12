import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DoseVisualStatus {
  taken,
  missed,
  pending,
}

class DoseTimelineEntry {
  final DateTime scheduledTime;
  final DoseVisualStatus status;
  final DateTime? takenAt;
  final bool canTake;

  const DoseTimelineEntry({
    required this.scheduledTime,
    required this.status,
    required this.takenAt,
    required this.canTake,
  });
}

class DoseTimelineWidget extends StatelessWidget {
  final List<DoseTimelineEntry> entries;
  final ValueChanged<DateTime> onTake;

  const DoseTimelineWidget({
    super.key,
    required this.entries,
    required this.onTake,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('No doses scheduled for today.'),
      );
    }

    return Column(
      children: entries.map((entry) {
        final subtitle = switch (entry.status) {
          DoseVisualStatus.taken => entry.takenAt == null
              ? 'Taken'
              : 'Taken at ${DateFormat('hh:mm a').format(entry.takenAt!)}',
          DoseVisualStatus.missed => 'Missed',
          DoseVisualStatus.pending => 'Pending',
        };

        final trailing = switch (entry.status) {
          DoseVisualStatus.taken => const Icon(Icons.check_circle, color: Colors.green),
          DoseVisualStatus.missed => const Icon(Icons.cancel, color: Colors.redAccent),
          DoseVisualStatus.pending => entry.canTake
              ? FilledButton(
                  onPressed: () => onTake(entry.scheduledTime),
                  child: const Text('Take'),
                )
              : Chip(
                  label: const Text('Pending'),
                  backgroundColor: Colors.grey.shade200,
                ),
        };

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: CircleAvatar(
              child: Text(DateFormat('HH').format(entry.scheduledTime)),
            ),
            title: Text(DateFormat('hh:mm a').format(entry.scheduledTime)),
            subtitle: Text(subtitle),
            trailing: trailing,
          ),
        );
      }).toList(),
    );
  }
}
