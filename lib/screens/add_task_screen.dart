import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/household_member_model.dart';
import '../services/firestore_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String householdId;

  const AddTaskScreen({super.key, required this.householdId});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController(text: '10');
  final _fs = FirestoreService();

  List<HouseholdMemberModel> _members = [];
  String? _selectedMemberId;
  bool _loading = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final members = await _fs.getHouseholdMembers(widget.householdId);
    members.sort((a, b) {
      if (a.role != b.role) {
        return a.role == 'admin' ? -1 : 1;
      }

      final aName = (a.user['displayName'] ?? a.user['phoneNumber'] ?? 'User').toString();
      final bName = (b.user['displayName'] ?? b.user['phoneNumber'] ?? 'User').toString();
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });

    if (!mounted) return;
    setState(() => _members = members);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked == null || picked == _selectedDate) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _createTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _fs.createTask(
        householdId: widget.householdId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        assignedToId: _selectedMemberId,
        createdById: FirebaseAuth.instance.currentUser!.uid,
        points: int.tryParse(_pointsController.text.trim()) ?? 10,
        dueDate: _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Task')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Points',
                  helperText: 'Recommended range: 5 to 50',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'No Due Date Set'
                      : 'Due Date: ${_selectedDate!.toString().substring(0, 10)}',
                ),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedMemberId,
                decoration: const InputDecoration(
                  labelText: 'Assign To (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Anyone'),
                  ),
                  ..._members.map(
                    (member) => DropdownMenuItem<String?>(
                      value: member.userId,
                      child: Text(member.user['displayName'] ?? 'User'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedMemberId = value),
              ),
              if (_members.where((member) => member.userId != FirebaseAuth.instance.currentUser?.uid).isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No other members have joined yet. You can still create an unassigned task or assign it to yourself.',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createTask,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Create Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
