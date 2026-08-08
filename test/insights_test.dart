import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/personal_expenses/domain/expense_model.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';

void main() {
  group('Personal Spending Insights Math Tests', () {
    test('Groups and sums personal expenses by calendar month and category correctly', () {
      final now = DateTime(2026, 7, 19);
      final month1 = DateTime(2026, 7, 5);
      final month2 = DateTime(2026, 6, 15);

      final List<ExpenseModel> expenses = [
        ExpenseModel(
          id: 'exp-1',
          amount: 1500.0,
          category: 'Food',
          description: 'Groceries',
          createdAt: month1,
          isRecurringTemplate: false,
        ),
        ExpenseModel(
          id: 'exp-2',
          amount: 250.0,
          category: 'Food',
          description: 'Snacks',
          createdAt: month1,
          isRecurringTemplate: false,
        ),
        ExpenseModel(
          id: 'exp-3',
          amount: 1200.0,
          category: 'Rent',
          description: 'June Room Rent',
          createdAt: month2,
          isRecurringTemplate: false,
        ),
        // Template expense - should be skipped in insights calculation
        ExpenseModel(
          id: 'template-1',
          amount: 500.0,
          category: 'Travel',
          description: 'Weekly template',
          createdAt: month1,
          isRecurringTemplate: true,
        ),
      ];

      // Generate trailing 2 months for simulation
      final monthsList = [DateTime(2026, 6, 1), DateTime(2026, 7, 1)];

      final Map<String, double> monthlyTotals = {
        for (var m in monthsList) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0.0,
      };

      for (final exp in expenses) {
        if (exp.isRecurringTemplate) continue;
        final key = '${exp.createdAt.year}-${exp.createdAt.month.toString().padLeft(2, '0')}';
        if (monthlyTotals.containsKey(key)) {
          monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + exp.amount;
        }
      }

      // Assert monthly sums (July 2026 gets 1500 + 250 = 1750; June 2026 gets 1200)
      expect(monthlyTotals['2026-07'], 1750.0);
      expect(monthlyTotals['2026-06'], 1200.0);

      // Category breakdown for selected month (July 2026)
      final selectedMonthKey = '2026-07';
      final selectedExpenses = expenses.where((exp) {
        if (exp.isRecurringTemplate) return false;
        final key = '${exp.createdAt.year}-${exp.createdAt.month.toString().padLeft(2, '0')}';
        return key == selectedMonthKey;
      }).toList();

      final Map<String, double> categorySums = {};
      for (final exp in selectedExpenses) {
        categorySums[exp.category] = (categorySums[exp.category] ?? 0.0) + exp.amount;
      }

      expect(categorySums['Food'], 1750.0);
      expect(categorySums['Rent'], isNull);
    });
  });

  group('Group Spending Insights Math Tests', () {
    test('Groups and sums group expenses correctly, filtering deleted and templates', () {
      final month1 = DateTime(2026, 7, 10);

      final List<GroupExpenseModel> expenses = [
        GroupExpenseModel(
          expenseId: 'g-exp-1',
          payerUid: 'user-1',
          amount: 2000.0,
          category: 'Travel',
          description: 'Flight',
          splitType: 'equal',
          splits: {'user-1': SplitEntry(amountOwed: 1000.0, settled: true), 'user-2': SplitEntry(amountOwed: 1000.0, settled: false)},
          createdAt: month1,
          isDeleted: false,
          isRecurringTemplate: false,
        ),
        // Soft-deleted expense - should be ignored
        GroupExpenseModel(
          expenseId: 'g-exp-2',
          payerUid: 'user-1',
          amount: 150.0,
          category: 'Food',
          description: 'Drinks',
          splitType: 'equal',
          splits: {'user-1': SplitEntry(amountOwed: 75.0, settled: true), 'user-2': SplitEntry(amountOwed: 75.0, settled: false)},
          createdAt: month1,
          isDeleted: true,
          isRecurringTemplate: false,
        ),
        // Template expense - should be ignored
        GroupExpenseModel(
          expenseId: 'g-template-1',
          payerUid: 'user-1',
          amount: 90.0,
          category: 'Entertainment',
          description: 'Spotify template',
          splitType: 'equal',
          splits: {'user-1': SplitEntry(amountOwed: 45.0, settled: true), 'user-2': SplitEntry(amountOwed: 45.0, settled: false)},
          createdAt: month1,
          isDeleted: false,
          isRecurringTemplate: true,
        ),
      ];

      final monthsList = [DateTime(2026, 7, 1)];

      final Map<String, double> monthlyTotals = {
        for (var m in monthsList) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0.0,
      };

      for (final exp in expenses) {
        if (exp.isDeleted || exp.isRecurringTemplate) continue;
        final key = '${exp.createdAt.year}-${exp.createdAt.month.toString().padLeft(2, '0')}';
        if (monthlyTotals.containsKey(key)) {
          monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + exp.amount;
        }
      }

      // July 2026 should only sum active, non-template expenses: 2000.0
      expect(monthlyTotals['2026-07'], 2000.0);
    });
  });
}
