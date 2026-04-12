import '../models/expense_model.dart';
import '../models/household_member_model.dart';
import '../models/settlement_model.dart';

class MemberBalanceViewModel {
  final String uid;
  final String name;
  final String colorHex;
  final double netAmount;

  const MemberBalanceViewModel({
    required this.uid,
    required this.name,
    required this.colorHex,
    required this.netAmount,
  });

  double get absoluteAmount => netAmount.abs();
  bool get owesCurrentUser => netAmount > 0.009;
  bool get currentUserOwes => netAmount < -0.009;
}

class CategorySpendViewModel {
  final String category;
  final String emoji;
  final double amount;

  const CategorySpendViewModel({
    required this.category,
    required this.emoji,
    required this.amount,
  });
}

class ExpenseSummaryViewModel {
  final double youOweTotal;
  final double owedToYouTotal;
  final List<MemberBalanceViewModel> memberBalances;
  final List<CategorySpendViewModel> categoryTotals;

  const ExpenseSummaryViewModel({
    required this.youOweTotal,
    required this.owedToYouTotal,
    required this.memberBalances,
    required this.categoryTotals,
  });
}

class BalanceCalculator {
  static ExpenseSummaryViewModel calculate({
    required List<ExpenseModel> expenses,
    required List<SettlementModel> settlements,
    required List<HouseholdMemberModel> members,
    required String currentUid,
    required DateTime selectedMonth,
  }) {
    final pairLedger = <String, Map<String, double>>{};

    void addLedgerValue(String creditor, String debtor, double value) {
      if (creditor == debtor || value.abs() < 0.0001) {
        return;
      }
      final bucket = pairLedger.putIfAbsent(creditor, () => <String, double>{});
      bucket[debtor] = (bucket[debtor] ?? 0) + value;
    }

    for (final expense in expenses) {
      if (expense.splitBetween.isEmpty) {
        continue;
      }

      final share = expense.amount / expense.splitBetween.length;
      for (final participantUid in expense.splitBetween) {
        if (participantUid == expense.paidBy) {
          continue;
        }
        addLedgerValue(expense.paidBy, participantUid, share);
      }
    }

    for (final settlement in settlements) {
      addLedgerValue(settlement.toUid, settlement.fromUid, -settlement.amount);
    }

    final memberBalances = <MemberBalanceViewModel>[];
    double youOweTotal = 0;
    double owedToYouTotal = 0;

    for (final member in members) {
      if (member.userId == currentUid) {
        continue;
      }

      final amountMemberOwesCurrent = pairLedger[currentUid]?[member.userId] ?? 0;
      final amountCurrentOwesMember = pairLedger[member.userId]?[currentUid] ?? 0;
      final netAmount = double.parse(
        (amountMemberOwesCurrent - amountCurrentOwesMember).toStringAsFixed(2),
      );

      if (netAmount > 0) {
        owedToYouTotal += netAmount;
      } else {
        youOweTotal += netAmount.abs();
      }

      memberBalances.add(
        MemberBalanceViewModel(
          uid: member.userId,
          name: (member.user['displayName'] ?? member.user['phoneNumber'] ?? 'Member').toString(),
          colorHex: member.color ?? '#0B5C68',
          netAmount: netAmount,
        ),
      );
    }

    memberBalances.sort((a, b) => b.absoluteAmount.compareTo(a.absoluteAmount));

    final monthCategorySpend = <String, CategorySpendViewModel>{};
    for (final expense in expenses) {
      final expenseDate = expense.date.toDate();
      if (expenseDate.year != selectedMonth.year || expenseDate.month != selectedMonth.month) {
        continue;
      }

      final existing = monthCategorySpend[expense.category];
      monthCategorySpend[expense.category] = CategorySpendViewModel(
        category: expense.category,
        emoji: expense.categoryEmoji,
        amount: (existing?.amount ?? 0) + expense.amount,
      );
    }

    final categoryTotals = monthCategorySpend.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return ExpenseSummaryViewModel(
      youOweTotal: double.parse(youOweTotal.toStringAsFixed(2)),
      owedToYouTotal: double.parse(owedToYouTotal.toStringAsFixed(2)),
      memberBalances: memberBalances,
      categoryTotals: categoryTotals,
    );
  }
}
