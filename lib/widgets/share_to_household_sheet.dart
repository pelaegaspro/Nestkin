import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/event_model.dart';
import '../services/event_repository.dart';
import '../services/firestore_service.dart';

class ShareToHouseholdSheet extends StatefulWidget {
  final String householdId;
  final EventModel googleEvent;

  const ShareToHouseholdSheet({
    super.key,
    required this.householdId,
    required this.googleEvent,
  });

  @override
  State<ShareToHouseholdSheet> createState() => _ShareToHouseholdSheetState();
}

class _ShareToHouseholdSheetState extends State<ShareToHouseholdSheet> {
  final _eventRepository = EventRepository();
  final _firestoreService = FirestoreService();
  String _type = 'Other';
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final user = await _firestoreService.getUser(FirebaseAuth.instance.currentUser!.uid);
      if (user == null) {
        throw Exception('Could not find your profile.');
      }

      final event = widget.googleEvent.copyWith(
        id: '',
        createdBy: user.id,
        createdByName: user.displayName,
        description: _type == 'Other'
            ? widget.googleEvent.description
            : '${widget.googleEvent.description}\nType: $_type'.trim(),
        source: EventSource.google,
        isSharedFromGoogle: true,
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
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Share with Household', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(widget.googleEvent.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(widget.googleEvent.startDateTime.toString()),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Birthday', child: Text('Birthday')),
              DropdownMenuItem(value: 'Anniversary', child: Text('Anniversary')),
              DropdownMenuItem(value: 'School', child: Text('School')),
              DropdownMenuItem(value: 'Work', child: Text('Work')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _type = value);
              }
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _sharing ? null : _share,
            child: Text(_sharing ? 'Sharing...' : 'Share with Household'),
          ),
        ],
      ),
    );
  }
}
