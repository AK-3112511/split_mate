import '../../../core/utils/dates.dart';
import '../../categories/domain/category_model.dart';
import '../../home/domain/home_stats.dart';
import '../../personal_expenses/domain/expense_model.dart';

/// Numbers behind the "Your `Month`" recap.
class RecapStats {
  final DateTime month;
  final double total;
  final int count;
  final double previousTotal;
  final List<CategoryTotal> byCategory;
  final ExpenseModel? biggest;
  final DateTime? busiestDay;
  final double busiestDayTotal;
  final int noSpendDays;
  final int longestNoSpendStreak;
  final int daysCounted;

  const RecapStats({
    required this.month,
    required this.total,
    required this.count,
    required this.previousTotal,
    required this.byCategory,
    required this.biggest,
    required this.busiestDay,
    required this.busiestDayTotal,
    required this.noSpendDays,
    required this.longestNoSpendStreak,
    required this.daysCounted,
  });

  bool get isEmpty => count == 0;
  CategoryTotal? get topCategory => byCategory.isEmpty ? null : byCategory.first;
  double get perDay => daysCounted == 0 ? 0 : total / daysCounted;

  /// Change vs previous month (null when the previous month had no spending).
  double? get change => previousTotal <= 0 ? null : (total - previousTotal) / previousTotal;

  static RecapStats compute(List<ExpenseModel> all, DateTime month, List<CategoryModel> cats, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final start = Dates.startOfMonth(month);
    final end = Dates.startOfNextMonth(month);
    final list = all.where((e) => Dates.inRange(e.date, start, end)).toList();
    final prevStart = DateTime(start.year, start.month - 1);
    final previous = HomeStats.total(all.where((e) => Dates.inRange(e.date, prevStart, start)));

    final perDay = <int, double>{};
    for (final e in list) {
      perDay[e.date.day] = (perDay[e.date.day] ?? 0) + e.amount;
    }
    // Count days up to today for the current month, the whole month otherwise.
    final lastDay = Dates.isSameMonth(month, n) ? n.day : DateTime(start.year, start.month + 1, 0).day;
    var noSpend = 0;
    var streak = 0;
    var best = 0;
    for (var d = 1; d <= lastDay; d++) {
      if ((perDay[d] ?? 0) <= 0) {
        noSpend++;
        streak++;
        if (streak > best) best = streak;
      } else {
        streak = 0;
      }
    }
    int? busiest;
    var busiestTotal = 0.0;
    perDay.forEach((d, v) {
      if (v > busiestTotal) {
        busiestTotal = v;
        busiest = d;
      }
    });
    ExpenseModel? biggest;
    for (final e in list) {
      if (biggest == null || e.amount > biggest.amount) biggest = e;
    }
    return RecapStats(
      month: start,
      total: HomeStats.total(list),
      count: list.length,
      previousTotal: previous,
      byCategory: HomeStats.byCategory(list, cats),
      biggest: biggest,
      busiestDay: busiest == null ? null : DateTime(start.year, start.month, busiest!),
      busiestDayTotal: busiestTotal,
      noSpendDays: noSpend,
      longestNoSpendStreak: best,
      daysCounted: lastDay,
    );
  }
}
