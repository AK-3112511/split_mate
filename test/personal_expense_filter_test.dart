import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/personal_expenses/domain/expense_model.dart';

void main() {
  group('Personal Expenses Date Range & Daily Reset Unit Tests', () {
    final now = DateTime.now();
    final todayExpense = ExpenseModel(
      id: 'exp-today',
      amount: 450.0,
      category: 'Food',
      description: 'Today Lunch',
      createdAt: now,
      isRecurringTemplate: false,
    );

    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayExpense = ExpenseModel(
      id: 'exp-yesterday',
      amount: 1200.0,
      category: 'Travel',
      description: 'Uber ride yesterday',
      createdAt: yesterday,
      isRecurringTemplate: false,
    );

    final lastMonth = DateTime(now.year, now.month - 1, 15);
    final lastMonthExpense = ExpenseModel(
      id: 'exp-last-month',
      amount: 3500.0,
      category: 'Rent',
      description: 'Last month rent',
      createdAt: lastMonth,
      isRecurringTemplate: false,
    );

    final templateExpense = ExpenseModel(
      id: 'template-1',
      amount: 900.0,
      category: 'Entertainment',
      description: 'Weekly template',
      createdAt: now,
      isRecurringTemplate: true,
    );

    final List<ExpenseModel> allExpenses = [
      todayExpense,
      yesterdayExpense,
      lastMonthExpense,
      templateExpense,
    ];

    test('Today filter (Daily Fresh Reset) returns only non-template expenses created today', () {
      final filtered = allExpenses.where((e) {
        if (e.isRecurringTemplate) return false;
        final d = e.createdAt;
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();

      expect(filtered.length, 1);
      expect(filtered.first.id, 'exp-today');
      expect(filtered.first.amount, 450.0);
    });

    test('This Month filter returns all expenses created in current month', () {
      final filtered = allExpenses.where((e) {
        if (e.isRecurringTemplate) return false;
        final d = e.createdAt;
        return d.year == now.year && d.month == now.month;
      }).toList();

      // Should include today and yesterday (if yesterday is in same month)
      final expectedCount = yesterday.month == now.month ? 2 : 1;
      expect(filtered.length, expectedCount);
      expect(filtered.any((e) => e.id == 'exp-today'), isTrue);
      expect(filtered.any((e) => e.id == 'exp-last-month'), isFalse);
    });

    test('All Time filter returns all non-template expenses', () {
      final filtered = allExpenses.where((e) => !e.isRecurringTemplate).toList();
      expect(filtered.length, 3);
      expect(filtered.any((e) => e.id == 'template-1'), isFalse);
    });

    test('Custom Date Range filter respects custom start and end date bounds', () {
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final filtered = allExpenses.where((e) {
        if (e.isRecurringTemplate) return false;
        final d = e.createdAt;
        return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
            (d.isBefore(end) || d.isAtSameMomentAs(end));
      }).toList();

      expect(filtered.any((e) => e.id == 'exp-today'), isTrue);
      expect(filtered.any((e) => e.id == 'exp-yesterday'), isTrue);
      expect(filtered.any((e) => e.id == 'exp-last-month'), isFalse);
    });

    test('Combined date range and category filter narrows expenses correctly', () {
      // All time + Food category
      final filteredFood = allExpenses.where((e) {
        if (e.isRecurringTemplate) return false;
        return e.category == 'Food';
      }).toList();

      expect(filteredFood.length, 1);
      expect(filteredFood.first.id, 'exp-today');
      expect(filteredFood.first.category, 'Food');
    });
  });
}
