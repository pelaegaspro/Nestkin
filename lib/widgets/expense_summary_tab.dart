import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/expense_model.dart';
import '../models/household_member_model.dart';
import '../models/settlement_model.dart';
import '../services/balance_calculator.dart';

class ExpenseSummaryTab extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final List<SettlementModel> settlements;
  final List<HouseholdMemberModel> members;
  final String currentUid;
  final DateTime selectedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool canGoNextMonth;
  final ValueChanged<MemberBalanceViewModel> onSettleUp;

  const ExpenseSummaryTab({
    super.key,
    required this.expenses,
    required this.settlements,
    required this.members,
    required this.currentUid,
    required this.selectedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.canGoNextMonth,
    required this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final summary = BalanceCalculator.calculate(
      expenses: expenses,
      settlements: settlements,
      members: members,
      currentUid: currentUid,
      selectedMonth: selectedMonth,
    );
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryValueCard(
                  label: 'You owe',
                  value: currency.format(summary.youOweTotal),
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryValueCard(
                  label: 'Owed to you',
                  value: currency.format(summary.owedToYouTotal),
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            IconButton(
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(selectedMonth),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: canGoNextMonth ? onNextMonth : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.categoryTotals.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'No expenses recorded for this month yet.',
              textAlign: TextAlign.center,
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spend by category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 48,
                      sectionsSpace: 2,
                      sections: [
                        for (var i = 0; i < summary.categoryTotals.length; i++)
                          PieChartSectionData(
                            color: _chartColors[i % _chartColors.length],
                            value: summary.categoryTotals[i].amount,
                            title:
                                '${summary.categoryTotals[i].emoji}\n${summary.categoryTotals[i].amount.toStringAsFixed(0)}',
                            radius: 72,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Balances',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (summary.memberBalances.isEmpty)
          const Text('No balances yet.')
        else
          ...summary.memberBalances.map(
            (balance) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: _parseColor(balance.colorHex),
                  child: Text(
                    balance.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(balance.name),
                subtitle: Text(
                  balance.owesCurrentUser
                      ? '${balance.name} owes you ${currency.format(balance.absoluteAmount)}'
                      : balance.currentUserOwes
                          ? 'You owe ${balance.name} ${currency.format(balance.absoluteAmount)}'
                          : 'All settled up',
                ),
                trailing: FilledButton(
                  onPressed: balance.absoluteAmount <= 0 ? null : () => onSettleUp(balance),
                  child: const Text('Settle Up'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

class _SummaryValueCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryValueCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
        ),
      ],
    );
  }
}

const List<Color> _chartColors = [
  Color(0xFF0B5C68),
  Color(0xFFE28F2D),
  Color(0xFF3B8B5A),
  Color(0xFFAA4A44),
  Color(0xFF5C6BC0),
  Color(0xFF9C6644),
];
