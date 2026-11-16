import 'package:intl/intl.dart';

class Dates {
  Dates._();

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime endOfDayExclusive(DateTime d) => DateTime(d.year, d.month, d.day + 1);
  static DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month);
  static DateTime startOfNextMonth(DateTime d) => DateTime(d.year, d.month + 1);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

  /// Half-open range check: start <= d < endExclusive.
  static bool inRange(DateTime d, DateTime start, DateTime endExclusive) =>
      !d.isBefore(start) && d.isBefore(endExclusive);

  /// "Today", "Yesterday", "Mon, 12 Nov", or "12 Nov 2025" for other years.
  static String dayLabel(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (isSameDay(d, n)) return 'Today';
    if (isSameDay(d, DateTime(n.year, n.month, n.day - 1))) return 'Yesterday';
    if (d.year == n.year) return DateFormat('EEE, d MMM').format(d);
    return DateFormat('d MMM yyyy').format(d);
  }

  static String short(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (d.year == n.year) return DateFormat('d MMM').format(d);
    return DateFormat('d MMM yy').format(d);
  }

  static String full(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String monthName(DateTime d) => DateFormat('MMMM').format(d);
  static String monthShort(DateTime d) => DateFormat('MMM').format(d);

  /// "just now", "5m ago", "3h ago", "2d ago", else short date.
  static String relative(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = n.difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return short(d, now: n);
  }

  /// Keeps the time-of-day of [timeSource] on the calendar day of [day];
  /// used when the user back-dates an expense so entries keep a sensible order.
  static DateTime withTimeOf(DateTime day, DateTime timeSource) => DateTime(
        day.year,
        day.month,
        day.day,
        timeSource.hour,
        timeSource.minute,
        timeSource.second,
      );

  static String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  static String dayKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}
