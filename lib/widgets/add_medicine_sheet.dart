import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household_member_model.dart';
import '../models/medicine_model.dart';
import '../services/medicine_notification_service.dart';
import '../services/medicine_repository.dart';

class AddMedicineSheet extends StatefulWidget {
  final String householdId;
  final List<HouseholdMemberModel> members;
  final MedicineModel? existingMedicine;

  const AddMedicineSheet({
    super.key,
    required this.householdId,
    required this.members,
    this.existingMedicine,
  });

  @override
  State<AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<AddMedicineSheet> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _repository = MedicineRepository();

  late String _assignedTo;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _ongoing = true;
  bool _saving = false;
  final List<String> _reminderTimes = [];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingMedicine;
    _nameController.text = existing?.name ?? '';
    _dosageController.text = existing?.dosage ?? '';
    _assignedTo = existing?.assignedTo ??
        (widget.members.any((member) => member.userId == FirebaseAuth.instance.currentUser?.uid)
            ? FirebaseAuth.instance.currentUser!.uid
            : widget.members.first.userId);
    _startDate = existing?.startDate.toDate() ?? DateTime.now();
    _endDate = existing?.endDate?.toDate();
    _ongoing = _endDate == null;
    _reminderTimes
      ..clear()
      ..addAll(existing?.reminderTimes ?? const ['08:00']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _addReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked == null) {
      return;
    }

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (_reminderTimes.contains(formatted)) {
      _showMessage('That reminder time is already added.');
      return;
    }

    setState(() {
      _reminderTimes.add(formatted);
      _reminderTimes.sort();
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final dosage = _dosageController.text.trim();
    HouseholdMemberModel? assignedMember;
    for (final member in widget.members) {
      if (member.userId == _assignedTo) {
        assignedMember = member;
        break;
      }
    }

    if (name.isEmpty) {
      _showMessage('Please enter a medicine name.');
      return;
    }
    if (dosage.isEmpty) {
      _showMessage('Please enter a dosage.');
      return;
    }
    if (assignedMember == null) {
      _showMessage('Please choose a family member.');
      return;
    }
    if (_reminderTimes.isEmpty) {
      _showMessage('Add at least one reminder time.');
      return;
    }

    setState(() => _saving = true);
    try {
      final medicine = MedicineModel(
        id: widget.existingMedicine?.id ?? '',
        name: name,
        dosage: dosage,
        assignedTo: assignedMember.userId,
        assignedToName:
            (assignedMember.user['displayName'] ?? assignedMember.user['phoneNumber'] ?? 'Member').toString(),
        assignedToColor: assignedMember.color ?? '#0B5C68',
        reminderTimes: [..._reminderTimes]..sort(),
        startDate: Timestamp.fromDate(_startDate),
        endDate: _ongoing || _endDate == null ? null : Timestamp.fromDate(_endDate!),
        createdBy: widget.existingMedicine?.createdBy ?? FirebaseAuth.instance.currentUser!.uid,
      );

      final savedMedicine = await _repository.saveMedicine(
        householdId: widget.householdId,
        medicine: medicine,
      );

      final today = DateTime.now();
      await _repository.ensureDoseSlotsForDay(
        householdId: widget.householdId,
        medicine: savedMedicine,
        day: today,
      );
      await MedicineNotificationService.instance.scheduleForMedicine(
        householdId: widget.householdId,
        medicine: savedMedicine,
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
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              widget.existingMedicine == null ? 'Add Medicine' : 'Edit Medicine',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _assignedTo,
              decoration: const InputDecoration(
                labelText: 'Assigned to',
                border: OutlineInputBorder(),
              ),
              items: widget.members
                  .map(
                    (member) => DropdownMenuItem(
                      value: member.userId,
                      child: Text(
                        (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString(),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _assignedTo = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Reminder times',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._reminderTimes.map(
                  (time) => Chip(
                    label: Text(time),
                    onDeleted: () {
                      setState(() => _reminderTimes.remove(time));
                    },
                  ),
                ),
                ActionChip(
                  label: const Text('Add Time'),
                  avatar: const Icon(Icons.add, size: 18),
                  onPressed: _addReminderTime,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Start date: ${_formatDate(_startDate)}'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () => _pickDate(isStart: true),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ongoing'),
              value: _ongoing,
              onChanged: (value) {
                setState(() {
                  _ongoing = value;
                  if (value) {
                    _endDate = null;
                  }
                });
              },
            ),
            if (!_ongoing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'End date: ${_endDate == null ? 'Select date' : _formatDate(_endDate!)}',
                ),
                trailing: const Icon(Icons.event_available_outlined),
                onTap: () => _pickDate(isStart: false),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save Medicine'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
