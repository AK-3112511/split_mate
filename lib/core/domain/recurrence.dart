import '../utils/dates.dart';

enum RecurrenceInterval {
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly');

  final String key;
  final String label;
  const RecurrenceInterval(this.key, this.label);

  static RecurrenceInterval? fromKey(String? key) {
    for (final v in values) {
      if (v.key == key) return v;
    }
    return null;
  }
}

/// Pure date maths for recurring templates.
///
/// Occurrence k of a template that starts on [start] is:
///  - weekly: start + 7k calendar days
///  - monthly: same day-of-month as [start], k months later, clamped to the
///    last day of shorter months (Jan 31 → Feb 28/29 → Mar 31 …, no drift).
class Recurrence {
  Recurrence._();

  /// Safety valve: never generate more than this many instances in one run.
  static const int maxCatchUp = 12;

  static DateTime occurrence(DateTime start, RecurrenceInterval interval, int k) {
    switch (interval) {
      case RecurrenceInterval.weekly:
        return DateTime(start.year, start.month, start.day + 7 * k, start.hour, start.minute);
      case RecurrenceInterval.monthly:
        final monthIndex = start.month - 1 + k;
        final year = start.year + (monthIndex ~/ 12);
        final month = monthIndex % 12 + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        final day = start.day > lastDay ? lastDay : start.day;
        return DateTime(year, month, day, start.hour, start.minute);
    }
  }

  /// Occurrences that are due (<= [now]) and strictly after [lastGenerated]
  /// (or from the very first one when never generated), oldest first, capped.
  static List<DateTime> dueOccurrences({
    required DateTime start,
    required RecurrenceInterval interval,
    required DateTime? lastGenerated,
    required DateTime now,
    int cap = maxCatchUp,
  }) {
    final out = <DateTime>[];
    for (var k = 0; k < 1000 && out.length < cap; k++) {
      final occ = occurrence(start, interval, k);
      if (occ.isAfter(now)) break;
      if (lastGenerated != null && !occ.isAfter(lastGenerated)) continue;
      out.add(occ);
    }
    return out;
  }

  /// Next occurrence strictly after [lastGenerated] (or the first one), i.e.
  /// what the UI should show as "Next on …".
  static DateTime nextOccurrence({
    required DateTime start,
    required RecurrenceInterval interval,
    required DateTime? lastGenerated,
  }) {
    for (var k = 0; k < 10000; k++) {
      final occ = occurrence(start, interval, k);
      if (lastGenerated == null || occ.isAfter(lastGenerated)) return occ;
    }
    return start;
  }

  /// Deterministic id for the instance generated on [occurrence], so multiple
  /// devices / group members can never create the same instance twice.
  static String instanceId(String templateId, DateTime occurrence) =>
      '${templateId}_${Dates.dayKey(occurrence)}';
}
