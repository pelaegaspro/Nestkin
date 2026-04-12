import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../models/household_member_model.dart';
import '../services/event_repository.dart';
import '../services/firestore_service.dart';

class AddEventSheet extends StatefulWidget {
  final String householdId;
  final EventModel? existingEvent;
  final List<HouseholdMemberModel> members;
  final DateTime initialDate;

  const AddEventSheet({
    super.key,
    required this.householdId,
    required this.members,
    required this.initialDate,
    this.existingEvent,
  });

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventRepository = EventRepository();
  final _firestoreService = FirestoreService();

  late DateTime _startTime;
  late DateTime _endTime;
  late Set<String> _assignedTo;
  EventRecurrence _recurrence = EventRecurrence.none;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initialEvent = widget.existingEvent;
    _titleController.text = initialEvent?.title ?? '';
    _descriptionController.text = initialEvent?.description ?? '';
    _startTime = initialEvent?.startDateTime ?? DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      9,
    );
    _endTime = initialEvent?.endDateTime ?? _startTime.add(const Duration(hours: 1));
    _assignedTo = {...?initialEvent?.assignedTo};
    _recurrence = initialEvent?.recurrence ?? EventRecurrence.none;
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) {
      return;
    }

    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = value;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = value.isBefore(_startTime) ? _startTime.add(const Duration(hours: 1)) : value;
      }
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = await _firestoreService.getUser(FirebaseAuth.instance.currentUser!.uid);
      if (user == null) {
        throw Exception('Could not find your profile.');
      }

      final selectedMembers = widget.members.where((member) => _assignedTo.contains(member.userId)).toList();
      final color = selectedMembers.isNotEmpty
          ? (selectedMembers.first.color ?? '#0B5C68')
          : '#0B5C68';

      final event = EventModel(
        id: widget.existingEvent?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: Timestamp.fromDate(_startTime),
        endTime: Timestamp.fromDate(_endTime),
        createdBy: widget.existingEvent?.createdBy ?? user.id,
        createdByName: widget.existingEvent?.createdByName ?? user.displayName,
        assignedTo: selectedMembers.map((member) => member.userId).toList(),
        assignedToNames: selectedMembers
            .map((member) => (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString())
            .toList(),
        color: color,
        isRecurring: _recurrence != EventRecurrence.none,
        recurrence: _recurrence,
        source: widget.existingEvent?.source ?? EventSource.nestkin,
        isSharedFromGoogle: widget.existingEvent?.isSharedFromGoogle ?? false,
      );

      await _eventRepository.saveEvent(
        householdId: widget.householdId,
        event: event,
      );

      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existingEvent == null ? 'Add Event' : 'Edit Event',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Starts: ${_formatDateTime(_startTime)}'),
              trailing: const Icon(Icons.event_outlined),
              onTap: () => _pickDateTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Ends: ${_formatDateTime(_endTime)}'),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: () => _pickDateTime(isStart: false),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<EventRecurrence>(
              initialValue: _recurrence,
              decoration: const InputDecoration(
                labelText: 'Recurrence',
                border: OutlineInputBorder(),
              ),
              items: EventRecurrence.values
                  .map(
                    (value) => DropdownMenuItem<EventRecurrence>(
                      value: value,
                      child: Text(value.name[0].toUpperCase() + value.name.substring(1)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _recurrence = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Text('Assign members', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.members.map((member) {
                final label = (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString();
                final isSelected = _assignedTo.contains(member.userId);
                return FilterChip(
                  selected: isSelected,
                  avatar: CircleAvatar(
                    backgroundColor: _parseColor(member.color ?? '#0B5C68'),
                    child: Text(
                      label.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  label: Text(label),
                  onSelected: (_) {
                    setState(() {
                      if (isSelected) {
                        _assignedTo.remove(member.userId);
                      } else {
                        _assignedTo.add(member.userId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save Event'),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
