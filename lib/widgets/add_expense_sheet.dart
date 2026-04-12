import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense_model.dart';
import '../models/household_member_model.dart';
import '../services/expense_repository.dart';

class AddExpenseSheet extends StatefulWidget {
  final String householdId;
  final List<HouseholdMemberModel> members;

  const AddExpenseSheet({
    super.key,
    required this.householdId,
    required this.members,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _repository = ExpenseRepository();
  final _picker = ImagePicker();

  late DateTime _selectedDate;
  late String _paidByUid;
  late Set<String> _splitBetween;
  _ExpenseCategoryOption _selectedCategory = _expenseCategories.first;
  XFile? _receiptImage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    _selectedDate = DateTime.now();
    _paidByUid = widget.members.any((member) => member.userId == currentUid)
        ? currentUid!
        : (widget.members.isNotEmpty ? widget.members.first.userId : '');
    _splitBetween = widget.members.map((member) => member.userId).toSet();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickReceipt() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() => _receiptImage = image);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    HouseholdMemberModel? paidByMember;
    for (final member in widget.members) {
      if (member.userId == _paidByUid) {
        paidByMember = member;
        break;
      }
    }

    if (title.isEmpty) {
      _showMessage('Please enter a title.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount.');
      return;
    }
    if (paidByMember == null) {
      _showMessage('Select who paid.');
      return;
    }
    if (_splitBetween.isEmpty) {
      _showMessage('Select at least one member to split the expense.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.saveExpense(
        householdId: widget.householdId,
        expense: ExpenseModel(
          id: '',
          title: title,
          amount: amount,
          paidBy: paidByMember.userId,
          paidByName: (paidByMember.user['displayName'] ?? paidByMember.user['phoneNumber'] ?? 'Member')
              .toString(),
          paidByColor: paidByMember.color ?? '#0B5C68',
          splitBetween: _splitBetween.toList(),
          category: _selectedCategory.label,
          categoryEmoji: _selectedCategory.emoji,
          date: Timestamp.fromDate(_selectedDate),
          receiptImageUrl: null,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          isSettled: false,
          createdBy: FirebaseAuth.instance.currentUser!.uid,
        ),
        receiptImage: _receiptImage,
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
              'Add Expense',
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
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: 'Rs ',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _expenseCategories.map((category) {
                final isSelected = category.label == _selectedCategory.label;
                return ChoiceChip(
                  selected: isSelected,
                  label: Text('${category.emoji} ${category.label}'),
                  onSelected: (_) {
                    setState(() => _selectedCategory = category);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _paidByUid.isEmpty ? null : _paidByUid,
              decoration: const InputDecoration(
                labelText: 'Paid by',
                border: OutlineInputBorder(),
              ),
              items: widget.members
                  .map(
                    (member) => DropdownMenuItem<String>(
                      value: member.userId,
                      child: Text(
                        (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString(),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paidByUid = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Split between',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.members.map((member) {
                final label = (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString();
                final selected = _splitBetween.contains(member.userId);
                return FilterChip(
                  selected: selected,
                  label: Text(label),
                  onSelected: (_) {
                    setState(() {
                      if (selected) {
                        _splitBetween.remove(member.userId);
                      } else {
                        _splitBetween.add(member.userId);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickReceipt,
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(_receiptImage == null ? 'Attach Receipt' : 'Change Receipt'),
            ),
            if (_receiptImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_receiptImage!.path),
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseCategoryOption {
  final String label;
  final String emoji;

  const _ExpenseCategoryOption(this.label, this.emoji);
}

const List<_ExpenseCategoryOption> _expenseCategories = [
  _ExpenseCategoryOption('Food', '\u{1F354}'),
  _ExpenseCategoryOption('School', '\u{1F4DA}'),
  _ExpenseCategoryOption('Medical', '\u{1F48A}'),
  _ExpenseCategoryOption('Utilities', '\u{1F4A1}'),
  _ExpenseCategoryOption('Transport', '\u{1F697}'),
  _ExpenseCategoryOption('Other', '\u{1F4E6}'),
];
