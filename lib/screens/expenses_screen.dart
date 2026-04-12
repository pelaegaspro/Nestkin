import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense_model.dart';
import '../models/household_member_model.dart';
import '../models/settlement_model.dart';
import '../services/balance_calculator.dart';
import '../services/expense_repository.dart';
import '../services/firestore_service.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/expense_detail_sheet.dart';
import '../widgets/expense_summary_tab.dart';
import '../widgets/settle_up_sheet.dart';

class ExpensesScreen extends StatefulWidget {
  final String householdId;

  const ExpensesScreen({
    super.key,
    required this.householdId,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _repository = ExpenseRepository();
  final _firestoreService = FirestoreService();
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String get _currentUid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _openAddExpenseSheet(List<HouseholdMemberModel> members) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddExpenseSheet(
        householdId: widget.householdId,
        members: members,
      ),
    );
  }

  Future<void> _openExpenseDetail(ExpenseModel expense, List<HouseholdMemberModel> members) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExpenseDetailSheet(
        expense: expense,
        members: members,
      ),
    );
  }

  Future<void> _openSettleUpSheet(MemberBalanceViewModel balance) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SettleUpSheet(
        householdId: widget.householdId,
        currentUid: _currentUid,
        balance: balance,
      ),
    );
  }

  Future<bool?> _confirmDelete(ExpenseModel expense) async {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense'),
        content: Text('Delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    try {
      await _repository.deleteExpense(
        householdId: widget.householdId,
        expenseId: expense.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HouseholdMemberModel>>(
      stream: _firestoreService.householdMembersStream(widget.householdId),
      builder: (context, membersSnapshot) {
        if (membersSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (membersSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Expenses')),
            body: const Center(child: Text('Could not load members right now.')),
          );
        }

        final members = membersSnapshot.data ?? const <HouseholdMemberModel>[];

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Expenses'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Expenses'),
                  Tab(text: 'Summary'),
                ],
              ),
            ),
            floatingActionButton: members.isEmpty
                ? null
                : FloatingActionButton(
                    onPressed: () => _openAddExpenseSheet(members),
                    child: const Icon(Icons.add),
                  ),
            body: TabBarView(
              children: [
                StreamBuilder<List<ExpenseModel>>(
                  stream: _repository.streamExpenses(widget.householdId),
                  builder: (context, expensesSnapshot) {
                    if (expensesSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (expensesSnapshot.hasError) {
                      return const Center(child: Text('Could not load expenses right now.'));
                    }

                    final expenses = expensesSnapshot.data ?? const <ExpenseModel>[];
                    if (expenses.isEmpty) {
                      return const Center(
                        child: Text('No expenses yet. Tap + to add the first one.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        final canDelete = expense.createdBy == _currentUid;
                        final tile = Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              child: Text(expense.categoryEmoji),
                            ),
                            title: Text(
                              expense.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${expense.paidByName} - ${DateFormat('dd MMM yyyy').format(expense.date.toDate())}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _parseColor(expense.paidByColor),
                                  child: Text(
                                    expense.paidByName.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ')
                                      .format(expense.amount),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            onTap: () => _openExpenseDetail(expense, members),
                          ),
                        );

                        if (!canDelete) {
                          return tile;
                        }

                        return Dismissible(
                          key: ValueKey(expense.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(expense),
                          onDismissed: (_) => _deleteExpense(expense),
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.centerRight,
                            child: const Icon(Icons.delete_outline, color: Colors.white),
                          ),
                          child: tile,
                        );
                      },
                    );
                  },
                ),
                StreamBuilder<List<ExpenseModel>>(
                  stream: _repository.streamExpenses(widget.householdId),
                  builder: (context, expensesSnapshot) {
                    if (expensesSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (expensesSnapshot.hasError) {
                      return const Center(child: Text('Could not load the summary right now.'));
                    }

                    return StreamBuilder<List<SettlementModel>>(
                      stream: _repository.streamSettlements(widget.householdId),
                      builder: (context, settlementsSnapshot) {
                        if (settlementsSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (settlementsSnapshot.hasError) {
                          return const Center(child: Text('Could not load settlements right now.'));
                        }

                        return ExpenseSummaryTab(
                          expenses: expensesSnapshot.data ?? const <ExpenseModel>[],
                          settlements: settlementsSnapshot.data ?? const <SettlementModel>[],
                          members: members,
                          currentUid: _currentUid,
                          selectedMonth: _selectedMonth,
                          onPreviousMonth: () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                            });
                          },
                          onNextMonth: () {
                            setState(() {
                              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                            });
                          },
                          canGoNextMonth: !(_selectedMonth.year == DateTime.now().year &&
                              _selectedMonth.month == DateTime.now().month),
                          onSettleUp: _openSettleUpSheet,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}
