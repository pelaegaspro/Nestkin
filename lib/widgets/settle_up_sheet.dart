import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/settlement_model.dart';
import '../services/balance_calculator.dart';
import '../services/expense_repository.dart';

class SettleUpSheet extends StatefulWidget {
  final String householdId;
  final String currentUid;
  final MemberBalanceViewModel balance;

  const SettleUpSheet({
    super.key,
    required this.householdId,
    required this.currentUid,
    required this.balance,
  });

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _repository = ExpenseRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.balance.absoluteAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid settlement amount.');
      return;
    }

    setState(() => _saving = true);
    try {
      await _repository.logSettlement(
        householdId: widget.householdId,
        settlement: SettlementModel(
          id: '',
          fromUid: widget.balance.currentUserOwes ? widget.currentUid : widget.balance.uid,
          toUid: widget.balance.currentUserOwes ? widget.balance.uid : widget.currentUid,
          amount: amount,
          settledAt: Timestamp.now(),
          note: _noteController.text.trim(),
        ),
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
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
    final directionText = widget.balance.currentUserOwes
        ? 'You are settling with ${widget.balance.name}.'
        : 'Record a payment received from ${widget.balance.name}.';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Settle Up',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(directionText),
            const SizedBox(height: 12),
            Text(
              'Outstanding: ${currency.format(widget.balance.absoluteAmount)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
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
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Log Settlement'),
            ),
          ],
        ),
      ),
    );
  }
}
