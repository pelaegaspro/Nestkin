import 'package:flutter/material.dart';

import '../models/event_model.dart';

class EventDetailSheet extends StatelessWidget {
  final EventModel event;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EventDetailSheet({
    super.key,
    required this.event,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('Starts: ${_formatDateTime(event.startDateTime)}'),
          const SizedBox(height: 4),
          Text('Ends: ${_formatDateTime(event.endDateTime)}'),
          const SizedBox(height: 12),
          if (event.description.isNotEmpty) Text(event.description),
          const SizedBox(height: 16),
          Text('Assigned members', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (event.assignedToNames.isEmpty)
            const Text('No members assigned.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: event.assignedToNames
                  .map(
                    (name) => Chip(
                      avatar: CircleAvatar(
                        backgroundColor: _parseColor(event.color),
                        child: Text(
                          name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      label: Text(name),
                    ),
                  )
                  .toList(),
            ),
          if (canEdit) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
