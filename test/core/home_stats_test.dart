import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/categories/domain/category_model.dart';
import 'package:split_mate/features/home/domain/home_stats.dart';
import 'package:split_mate/features/personal_expenses/domain/expense_model.dart';
import 'package:split_mate/features/recap/domain/recap_stats.dart';

ExpenseModel e(String id, double amount, DateTime date, {String categoryId = 'food', String name = 'Food'}) =>
    ExpenseModel(
      id: id,
      amount: amount,
      categoryId: categoryId,
      categoryName: name,
      description: 'x$id',
      date: date,
      createdAt: date,
    );

void main() {
  final cats = [
    const CategoryModel(id: 'food', name: 'Food', iconCode: 'restaurant', colorHex: 'F97316', monthlyBudget: 1000),
    const CategoryModel(id: 'rent', name: 'Rent', iconCode: 'home', colorHex: '3B82F6'),
  ];
  final now = DateTime(2026, 11, 15, 12);

  group('DateRange', () {
    test('today / week / month are half-open and include end of day', () {
      final today = DateRange.of(RangeKind.today, now: now);
      expect(today.contains(DateTime(2026, 11, 15, 23, 59, 59, 999)), isTrue);
      expect(today.contains(DateTime(2026, 11, 16)), isFalse);
      final week = DateRange.of(RangeKind.week, now: now);
      expect(week.start, DateTime(2026, 11, 9)); // 15 Nov 2026 is a Sunday
      final month = DateRange.of(RangeKind.month, now: now);
      expect(month.contains(DateTime(2026, 11, 30, 23)), isTrue);
      expect(month.contains(DateTime(2026, 12, 1)), isFalse);
    });

    test('all time includes old and recent expenses', () {
      final all = DateRange.of(RangeKind.all, now: now);
      expect(all.label, 'All time');
      expect(all.contains(DateTime(2015, 1, 1)), isTrue);
      expect(all.contains(DateTime(2026, 11, 15, 23, 59)), isTrue);
    });

    test('custom range swaps reversed dates and includes the last day', () {
      final r = DateRange.of(RangeKind.custom, from: DateTime(2026, 11, 20), to: DateTime(2026, 11, 10));
      expect(r.contains(DateTime(2026, 11, 10, 8)), isTrue);
      expect(r.contains(DateTime(2026, 11, 20, 22)), isTrue);
      expect(r.label, '10 Nov – 20 Nov');
    });
  });

  group('aggregations', () {
    final list = [
      e('1', 300, DateTime(2026, 11, 2)),
      e('2', 700, DateTime(2026, 11, 14), categoryId: 'rent', name: 'Rent'),
      e('3', 500, DateTime(2026, 10, 3)),
      // v1 doc: only a category *name*, no id
      e('4', 100, DateTime(2026, 11, 3), categoryId: '', name: 'food'),
    ];

    test('category filter works by id and v1 names', () {
      final month = DateRange.of(RangeKind.month, now: now);
      final food = HomeStats.inRange(list, month, categoryId: 'food', cats: cats);
      expect(food.map((x) => x.id), ['1', '4']);
    });

    test('byCategory shares sum to 1 and are sorted', () {
      final month = DateRange.of(RangeKind.month, now: now);
      final by = HomeStats.byCategory(HomeStats.inRange(list, month), cats);
      expect(by.first.category.id, 'rent');
      expect(by.fold<double>(0, (a, t) => a + t.share), closeTo(1, 1e-9));
    });

    test('monthly totals and month-to-date trend', () {
      final m = HomeStats.monthly(list, count: 2, now: now);
      expect(m.map((x) => x.amount), [500, 1100]);
      expect(HomeStats.monthTrend(list, now: now), closeTo((1100 - 500) / 500, 1e-9));
    });

    test('budget alert fires once when crossing 80% and 100%', () {
      final food = cats.first;
      final before = [e('a', 700, DateTime(2026, 11, 1))];
      // Uses real "now" for the month check, so date it today.
      final today = DateTime.now();
      final b2 = [e('a', 700, today)];
      expect(
        HomeStats.budgetAlert(before: b2, category: food, added: 150, date: today, cats: cats),
        contains('85%'),
      );
      expect(
        HomeStats.budgetAlert(before: b2, category: food, added: 400, date: today, cats: cats),
        contains('over'),
      );
      expect(HomeStats.budgetAlert(before: before, category: cats[1], added: 9999, date: today, cats: cats), isNull);
    });
  });

  test('recap stats', () {
    final list = [
      e('1', 100, DateTime(2026, 10, 1)),
      e('2', 400, DateTime(2026, 10, 1)),
      e('3', 250, DateTime(2026, 10, 9), categoryId: 'rent', name: 'Rent'),
      e('4', 1000, DateTime(2026, 9, 9)),
    ];
    final s = RecapStats.compute(list, DateTime(2026, 10), cats, now: now);
    expect(s.total, 750);
    expect(s.count, 3);
    expect(s.biggest!.id, '2');
    expect(s.busiestDay, DateTime(2026, 10, 1));
    expect(s.noSpendDays, 29); // 31 days − 2 spending days
    expect(s.longestNoSpendStreak, 22); // 10th → 31st
    expect(s.change, closeTo(-0.25, 1e-9));
    expect(s.topCategory!.category.id, 'food');
  });
}
