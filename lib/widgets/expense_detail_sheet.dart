import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense_model.dart';
import '../models/household_member_model.dart';

class ExpenseDetailSheet extends StatelessWidget {
  final ExpenseModel expense;
  final List<HouseholdMemberModel> members;

  const ExpenseDetailSheet({
    super.key,
    required this.expense,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final splitAmount = expense.splitBetween.isEmpty ? 0.0 : expense.amount / expense.splitBetween.length;
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');
    final memberLookup = {
      for (final member in members)
        member.userId: (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString(),
    };

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _parseColor(expense.paidByColor),
                    child: Text(
                      expense.categoryEmoji,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          '${currency.format(expense.amount)} - ${DateFormat('dd MMM yyyy').format(expense.date.toDate())}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Paid by ${expense.paidByName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (expense.note != null && expense.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(expense.note!),
              ],
              if (expense.receiptImageUrl != null && expense.receiptImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    expense.receiptImageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Split Breakdown',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...expense.splitBetween.map(
                (uid) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: uid == expense.paidBy ? _parseColor(expense.paidByColor) : Colors.grey.shade200,
                    child: Text(
                      (memberLookup[uid] ?? 'M').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: uid == expense.paidBy ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  title: Text(memberLookup[uid] ?? 'Member'),
                  subtitle: Text(uid == expense.paidBy ? 'Paid the expense' : 'Owes their share'),
                  trailing: Text(
                    currency.format(splitAmount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
