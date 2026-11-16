import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../../personal_expenses/domain/expense_model.dart';

enum RangeKind { all, today, week, month, custom }

/// A half-open date range [start, end).
class DateRange {
  final RangeKind kind;
  final DateTime start;
  final DateTime end;
  const DateRange(this.kind, this.start, this.end);

  factory DateRange.of(RangeKind kind, {DateTime? now, DateTime? from, DateTime? to}) {
    final n = now ?? DateTime.now();
    switch (kind) {
      case RangeKind.all:
        // Everything ever recorded (the app doesn't allow future dates).
        return DateRange(kind, DateTime(2000), DateTime(n.year + 100));
      case RangeKind.today:
        return DateRange(kind, Dates.startOfDay(n), Dates.endOfDayExclusive(n));
      case RangeKind.week:
        return DateRange(kind, Dates.startOfWeek(n), Dates.endOfDayExclusive(n));
      case RangeKind.month:
        return DateRange(kind, Dates.startOfMonth(n), Dates.startOfNextMonth(n));
      case RangeKind.custom:
        final a = Dates.startOfDay(from ?? n);
        final b = Dates.endOfDayExclusive(to ?? n);
        return b.isAfter(a) ? DateRange(kind, a, b) : DateRange(kind, Dates.startOfDay(to ?? n), Dates.endOfDayExclusive(from ?? n));
    }
  }

  factory DateRange.month(DateTime m) =>
      DateRange(RangeKind.custom, Dates.startOfMonth(m), Dates.startOfNextMonth(m));

  bool contains(DateTime d) => Dates.inRange(d, start, end);

  String get label {
    switch (kind) {
      case RangeKind.all:
        return 'All time';
      case RangeKind.today:
        return 'Today';
      case RangeKind.week:
        return 'This week';
      case RangeKind.month:
        return Dates.monthYear(start);
      case RangeKind.custom:
        final last = end.subtract(const Duration(days: 1));
        if (Dates.isSameDay(start, last)) return Dates.dayLabel(start);
        if (start.day == 1 && Dates.isSameDay(end, Dates.startOfNextMonth(start))) return Dates.monthYear(start);
        return '${Dates.short(start)} – ${Dates.short(last)}';
    }
  }
}

class CategoryTotal {
  final CategoryModel category;
  final double amount;
  final double share; // 0..1 of the range total
  const CategoryTotal(this.category, this.amount, this.share);
}

class MonthTotal {
  final DateTime month;
  final double amount;
  const MonthTotal(this.month, this.amount);
}

class BudgetStatus {
  final CategoryModel category;
  final double spent;
  final double budget;
  const BudgetStatus(this.category, this.spent, this.budget);

  double get ratio => budget <= 0 ? 0 : spent / budget;
  double get left => budget - spent;
  bool get warning => ratio >= 0.8 && ratio < 1;
  bool get over => ratio >= 1;
}

/// Pure aggregations for the Home dashboard.
class HomeStats {
  HomeStats._();

  static CategoryModel categoryOf(ExpenseModel e, List<CategoryModel> cats) =>
      CategoryResolver.resolve(id: e.categoryId, name: e.categoryName, categories: cats);

  static List<ExpenseModel> inRange(List<ExpenseModel> all, DateRange r, {String? categoryId, List<CategoryModel> cats = const []}) {
    return all.where((e) {
      if (!r.contains(e.date)) return false;
      if (categoryId != null && categoryOf(e, cats).id != categoryId) return false;
      return true;
    }).toList();
  }

  static double total(Iterable<ExpenseModel> list) =>
      Money.fromPaise(list.fold<int>(0, (a, e) => a + Money.toPaise(e.amount)));

  static List<CategoryTotal> byCategory(List<ExpenseModel> list, List<CategoryModel> cats) {
    final sum = total(list);
    final totals = CategoryResolver.totals<ExpenseModel>(
      items: list,
      categoryOf: (e) => categoryOf(e, cats),
      amountOf: (e) => e.amount,
    );
    return [for (final t in totals) CategoryTotal(t.key, Money.round2(t.value), sum <= 0 ? 0 : t.value / sum)];
  }

  /// Last [count] calendar months ending with the month of [now] (oldest first).
  static List<MonthTotal> monthly(List<ExpenseModel> all, {int count = 6, DateTime? now}) {
    final n = now ?? DateTime.now();
    final out = <MonthTotal>[];
    for (var i = count - 1; i >= 0; i--) {
      final m = DateTime(n.year, n.month - i);
      out.add(MonthTotal(m, total(all.where((e) => Dates.isSameMonth(e.date, m)))));
    }
    return out;
  }

  /// Month-to-date vs the same days of last month. Null when last month is empty.
  static double? monthTrend(List<ExpenseModel> all, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final thisStart = Dates.startOfMonth(n);
    final lastStart = DateTime(n.year, n.month - 1);
    final lastDays = DateTime(n.year, n.month, 0).day;
    final lastEnd = DateTime(lastStart.year, lastStart.month, (n.day < lastDays ? n.day : lastDays) + 1);
    final current = total(all.where((e) => Dates.inRange(e.date, thisStart, Dates.endOfDayExclusive(n))));
    final previous = total(all.where((e) => Dates.inRange(e.date, lastStart, lastEnd)));
    if (previous <= 0) return null;
    return (current - previous) / previous;
  }

  static List<BudgetStatus> budgets(List<ExpenseModel> all, List<CategoryModel> cats, {DateTime? now}) {
    final month = DateRange.of(RangeKind.month, now: now);
    final monthList = all.where((e) => month.contains(e.date)).toList();
    final out = <BudgetStatus>[];
    for (final c in cats.where((c) => c.hasBudget)) {
      final spent = total(monthList.where((e) => categoryOf(e, cats).id == c.id));
      out.add(BudgetStatus(c, spent, c.monthlyBudget!));
    }
    out.sort((a, b) => b.ratio.compareTo(a.ratio));
    return out;
  }

  /// Groups an already-sorted (newest first) list by calendar day.
  static List<MapEntry<DateTime, List<ExpenseModel>>> byDay(List<ExpenseModel> list) {
    final map = <DateTime, List<ExpenseModel>>{};
    for (final e in list) {
      map.putIfAbsent(Dates.startOfDay(e.date), () => []).add(e);
    }
    final days = map.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    return days;
  }

  /// Budget threshold crossed by adding [added] to [category] this month, if any.
  static String? budgetAlert({
    required List<ExpenseModel> before,
    required CategoryModel category,
    required double added,
    required DateTime date,
    required List<CategoryModel> cats,
  }) {
    if (!category.hasBudget) return null;
    final now = DateTime.now();
    if (!Dates.isSameMonth(date, now)) return null;
    final month = DateRange.of(RangeKind.month, now: now);
    final spent = total(before.where((e) => month.contains(e.date) && categoryOf(e, cats).id == category.id));
    final budget = category.monthlyBudget!;
    final was = spent / budget;
    final nowRatio = (spent + added) / budget;
    if (was < 1 && nowRatio >= 1) {
      return 'You\'ve gone over your ${category.name} budget (${Money.format(budget)}).';
    }
    if (was < 0.8 && nowRatio >= 0.8) {
      return 'Heads up: ${(nowRatio * 100).round()}% of your ${category.name} budget used.';
    }
    return null;
  }
}
