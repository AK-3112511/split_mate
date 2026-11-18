import 'package:intl/intl.dart';
import '../../../core/utils/money.dart';
import 'group_expense_model.dart';
import 'group_model.dart';

/// The end-of-trip numbers: total, per day, who consumed and who paid what,
/// the biggest expense and the busiest day. Payments are not spending.
class TripSummary {
  final double total;
  final int days;
  final int expenseCount;

  /// What each person consumed (their shares) and what they paid up front.
  final Map<String, double> shareByUid;
  final Map<String, double> paidByUid;
  final GroupExpenseModel? biggest;
  final DateTime? busiestDay;
  final double busiestDayTotal;

  /// Foreign currencies used on the trip ("THB", "USD").
  final Set<String> currencies;

  const TripSummary({
    required this.total,
    required this.days,
    required this.expenseCount,
    required this.shareByUid,
    required this.paidByUid,
    required this.biggest,
    required this.busiestDay,
    required this.busiestDayTotal,
    required this.currencies,
  });

  double get perDay => days <= 0 ? total : Money.round2(total / days);

  /// Average consumed per person who took part.
  double get perPerson {
    final people = shareByUid.values.where((v) => v > 0).length;
    return people == 0 ? 0 : Money.round2(total / people);
  }

  static TripSummary compute(GroupModel group, List<GroupExpenseModel> all) {
    final spending = all.where((e) => !e.isPayment && !e.isDeleted).toList();
    var totalPaise = 0;
    final share = <String, int>{};
    final paid = <String, int>{};
    final byDay = <DateTime, int>{};
    GroupExpenseModel? biggest;
    for (final e in spending) {
      final p = Money.toPaise(e.amount);
      totalPaise += p;
      paid[e.payerUid] = (paid[e.payerUid] ?? 0) + p;
      e.shareByUid.forEach((u, v) => share[u] = (share[u] ?? 0) + Money.toPaise(v));
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      byDay[day] = (byDay[day] ?? 0) + p;
      if (biggest == null || e.amount > biggest.amount) biggest = e;
    }
    DateTime? busiest;
    var busiestPaise = 0;
    byDay.forEach((d, p) {
      if (p > busiestPaise) {
        busiest = d;
        busiestPaise = p;
      }
    });
    final days = group.isTrip
        ? group.tripDays
        : byDay.isEmpty
        ? 0
        : byDay.keys
                  .reduce((a, b) => a.isAfter(b) ? a : b)
                  .difference(byDay.keys.reduce((a, b) => a.isBefore(b) ? a : b))
                  .inDays +
              1;
    return TripSummary(
      total: Money.fromPaise(totalPaise),
      days: days,
      expenseCount: spending.length,
      shareByUid: share.map((k, v) => MapEntry(k, Money.fromPaise(v))),
      paidByUid: paid.map((k, v) => MapEntry(k, Money.fromPaise(v))),
      biggest: biggest,
      busiestDay: busiest,
      busiestDayTotal: Money.fromPaise(busiestPaise),
      currencies: {
        for (final e in spending)
          if (e.fx != null) e.fx!.currency,
      },
    );
  }

  /// "12–16 Dec 2026", "28 Dec – 2 Jan 2027", "5 Dec 2026".
  static String dateRange(DateTime start, DateTime end) {
    final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
    if (sameDay) return DateFormat('d MMM yyyy').format(start);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day}–${DateFormat('d MMM yyyy').format(end)}';
    }
    if (start.year == end.year) {
      return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
    }
    return '${DateFormat('d MMM yyyy').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
  }
}
