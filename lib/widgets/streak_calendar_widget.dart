import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum StreakDayStatus {
  taken,
  missed,
  pending,
}

class StreakDayEntry {
  final DateTime day;
  final StreakDayStatus status;

  const StreakDayEntry({
    required this.day,
    required this.status,
  });
}

class StreakCalendarWidget extends StatelessWidget {
  final List<StreakDayEntry> entries;

  const StreakCalendarWidget({
    super.key,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: entries.map((entry) {
        final (backgroundColor, labelColor) = switch (entry.status) {
          StreakDayStatus.taken => (Colors.green.shade100, Colors.green.shade800),
          StreakDayStatus.missed => (Colors.red.shade100, Colors.red.shade800),
          StreakDayStatus.pending => (Colors.grey.shade200, Colors.grey.shade700),
        };

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('E').format(entry.day),
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry.day.day}',
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
