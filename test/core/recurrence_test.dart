import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/domain/recurrence.dart';
import 'package:split_mate/core/utils/recurring_engine.dart';

void main() {
  group('occurrence', () {
    test('monthly clamps to month end without drifting', () {
      final start = DateTime(2026, 1, 31, 9);
      final m = RecurrenceInterval.monthly;
      expect(Recurrence.occurrence(start, m, 1), DateTime(2026, 2, 28, 9));
      expect(Recurrence.occurrence(start, m, 2), DateTime(2026, 3, 31, 9));
      expect(Recurrence.occurrence(start, m, 3), DateTime(2026, 4, 30, 9));
      expect(Recurrence.occurrence(start, m, 12), DateTime(2027, 1, 31, 9));
      expect(Recurrence.occurrence(DateTime(2028, 1, 31), m, 1), DateTime(2028, 2, 29));
    });

    test('weekly adds calendar weeks', () {
      final start = DateTime(2026, 3, 1, 10);
      expect(Recurrence.occurrence(start, RecurrenceInterval.weekly, 2), DateTime(2026, 3, 15, 10));
    });
  });

  group('dueOccurrences', () {
    test('never generated → includes the start occurrence', () {
      final due = Recurrence.dueOccurrences(
        start: DateTime(2026, 11, 1),
        interval: RecurrenceInterval.monthly,
        lastGenerated: null,
        now: DateTime(2026, 11, 15),
      );
      expect(due, [DateTime(2026, 11, 1)]);
    });

    test('catches up every missed period (v1 generated only one)', () {
      final due = Recurrence.dueOccurrences(
        start: DateTime(2026, 1, 10),
        interval: RecurrenceInterval.monthly,
        lastGenerated: DateTime(2026, 1, 10),
        now: DateTime(2026, 5, 11),
      );
      expect(due, [
        DateTime(2026, 2, 10),
        DateTime(2026, 3, 10),
        DateTime(2026, 4, 10),
        DateTime(2026, 5, 10),
      ]);
    });

    test('future start date generates nothing yet', () {
      final due = Recurrence.dueOccurrences(
        start: DateTime(2026, 12, 1),
        interval: RecurrenceInterval.weekly,
        lastGenerated: null,
        now: DateTime(2026, 11, 15),
      );
      expect(due, isEmpty);
    });

    test('capped at maxCatchUp', () {
      final due = Recurrence.dueOccurrences(
        start: DateTime(2020, 1, 1),
        interval: RecurrenceInterval.weekly,
        lastGenerated: null,
        now: DateTime(2026, 1, 1),
      );
      expect(due.length, Recurrence.maxCatchUp);
    });
  });

  test('nextOccurrence and deterministic ids', () {
    final next = Recurrence.nextOccurrence(
      start: DateTime(2026, 1, 31),
      interval: RecurrenceInterval.monthly,
      lastGenerated: DateTime(2026, 2, 28),
    );
    expect(next, DateTime(2026, 3, 31));
    expect(Recurrence.instanceId('t1', DateTime(2026, 3, 1)), 't1_20260301');
  });

  test('v1 templates with a wiped lastGeneratedDate only get the latest instance', () {
    final start = DateTime(2026, 1, 5);
    final now = DateTime(2026, 6, 10);
    final legacy = RecurringEngine.dueFor(const {}, start, RecurrenceInterval.monthly, null, now);
    expect(legacy, [DateTime(2026, 6, 5)]);
    final v2 = RecurringEngine.dueFor(const {'recurrenceVersion': 2}, start, RecurrenceInterval.monthly, null, now);
    expect(v2.length, 6);
  });
}
