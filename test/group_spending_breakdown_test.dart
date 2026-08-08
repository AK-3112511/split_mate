import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';

void main() {
  group('Group Spending Breakdown Calculations & Ranking Tests', () {
    test('Computes category totals, member payer ranking, and verifies total spend cross-check equality', () {
      final List<String> members = ['user-1', 'user-2', 'user-3'];
      final List<GroupExpenseModel> expenses = [
        GroupExpenseModel(
          expenseId: 'exp-1',
          payerUid: 'user-1',
          amount: 8200.0,
          category: 'Food',
          description: 'Team Dinner',
          splitType: 'equal',
          splits: {'user-1': SplitEntry(amountOwed: 2733.34, settled: true), 'user-2': SplitEntry(amountOwed: 2733.33, settled: false), 'user-3': SplitEntry(amountOwed: 2733.33, settled: false)},
          createdAt: DateTime(2026, 7, 10),
          isDeleted: false,
          isRecurringTemplate: false,
        ),
        GroupExpenseModel(
          expenseId: 'exp-2',
          payerUid: 'user-2',
          amount: 5100.0,
          category: 'Travel',
          description: 'Cab fare',
          splitType: 'equal',
          splits: {'user-1': SplitEntry(amountOwed: 1700.0, settled: false), 'user-2': SplitEntry(amountOwed: 1700.0, settled: true), 'user-3': SplitEntry(amountOwed: 1700.0, settled: false)},
          createdAt: DateTime(2026, 7, 12),
          isDeleted: false,
          isRecurringTemplate: false,
        ),
        // Soft-deleted expense (must be ignored)
        GroupExpenseModel(
          expenseId: 'exp-3-deleted',
          payerUid: 'user-3',
          amount: 3000.0,
          category: 'Food',
          description: 'Cancelled Meal',
          splitType: 'equal',
          splits: {'user-1': SplitEntry(amountOwed: 1000.0, settled: false), 'user-2': SplitEntry(amountOwed: 1000.0, settled: false), 'user-3': SplitEntry(amountOwed: 1000.0, settled: true)},
          createdAt: DateTime(2026, 7, 15),
          isDeleted: true,
          isRecurringTemplate: false,
        ),
        // Recurring template expense (must be ignored)
        GroupExpenseModel(
          expenseId: 'exp-4-template',
          payerUid: 'user-1',
          amount: 1000.0,
          category: 'Rent',
          description: 'Template Rent',
          splitType: 'equal',
          splits: {'user-1': SplitEntry(amountOwed: 500.0, settled: true), 'user-2': SplitEntry(amountOwed: 500.0, settled: false)},
          createdAt: DateTime(2026, 7, 1),
          isDeleted: false,
          isRecurringTemplate: true,
        ),
      ];

      // 1. Filter active expenses
      final activeExpenses = expenses.where((e) => !e.isDeleted && !e.isRecurringTemplate).toList();

      // 2. Compute Total Group Spend
      final double totalGroupSpend = activeExpenses.fold(0.0, (sum, e) => sum + e.amount);
      expect(totalGroupSpend, 13300.0); // 8200 + 5100 = 13300

      // 3. Category Totals
      final Map<String, double> categorySums = {};
      for (final e in activeExpenses) {
        categorySums[e.category] = (categorySums[e.category] ?? 0.0) + e.amount;
      }

      expect(categorySums['Food'], 8200.0);
      expect(categorySums['Travel'], 5100.0);
      expect(categorySums['Rent'], isNull);

      // CROSS-CHECK: Sum of category totals equals total group spend
      final double categoryTotalsSum = categorySums.values.fold(0.0, (a, b) => a + b);
      expect(categoryTotalsSum, equals(totalGroupSpend));

      // 4. Member Payer Ranking ("Who Paid The Most")
      final Map<String, double> payerSums = {
        for (var uid in members) uid: 0.0,
      };
      for (final e in activeExpenses) {
        payerSums[e.payerUid] = (payerSums[e.payerUid] ?? 0.0) + e.amount;
      }

      final sortedPayerUids = members.toList()
        ..sort((a, b) => (payerSums[b] ?? 0.0).compareTo(payerSums[a] ?? 0.0));

      expect(sortedPayerUids[0], 'user-1'); // user-1 paid 8200.0 (Rank #1 Top Payer)
      expect(payerSums['user-1'], 8200.0);

      expect(sortedPayerUids[1], 'user-2'); // user-2 paid 5100.0 (Rank #2)
      expect(payerSums['user-2'], 5100.0);

      expect(sortedPayerUids[2], 'user-3'); // user-3 paid 0.0 (Rank #3)
      expect(payerSums['user-3'], 0.0);

      // 5. Member Individual Spend Math ("How Much Everyone Spent")
      final Map<String, double> memberIndividualSpend = {
        for (var uid in members) uid: 0.0,
      };
      for (final e in activeExpenses) {
        e.splitsAmountOwed.forEach((uid, amountOwed) {
          if (memberIndividualSpend.containsKey(uid)) {
            memberIndividualSpend[uid] = (memberIndividualSpend[uid] ?? 0.0) + amountOwed;
          }
        });
      }

      // user-1 share: 2733.34 + 1700.0 = 4433.34
      expect(memberIndividualSpend['user-1'], 4433.34);
      // user-2 share: 2733.33 + 1700.0 = 4433.33
      expect(memberIndividualSpend['user-2'], 4433.33);
      // user-3 share: 2733.33 + 1700.0 = 4433.33
      expect(memberIndividualSpend['user-3'], 4433.33);

      // CROSS-CHECK: Sum of individual member shares equals total group spend
      final double totalIndividualSharesSum = memberIndividualSpend.values.fold(0.0, (a, b) => a + b);
      expect(totalIndividualSharesSum, equals(totalGroupSpend));
    });
  });
}
