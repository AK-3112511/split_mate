import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/domain/split_calculator.dart';
import 'package:split_mate/core/utils/currency.dart';
import 'package:split_mate/core/utils/money.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';
import 'package:split_mate/features/groups/domain/group_model.dart';

int sumPaise(Map<String, double> m) => m.values.fold(0, (a, v) => a + Money.toPaise(v));

void main() {
  group('split by shares', () {
    test('couple counts as 2 shares', () {
      final r = SplitCalculator.shares(total: 900, weights: {'couple': 2, 'solo': 1}, payerUid: 'solo');
      expect(r.shares, {'couple': 600.0, 'solo': 300.0});
    });

    test('+₹50 adjustment comes off the top, the rest by shares', () {
      final r = SplitCalculator.shares(total: 650, weights: {'a': 1, 'b': 1}, adjustments: {'b': 50}, payerUid: 'a');
      expect(r.shares, {'a': 300.0, 'b': 350.0});
    });

    test('someone with only an adjustment pays just that', () {
      final r = SplitCalculator.shares(
        total: 1000,
        weights: {'a': 1, 'b': 1, 'c': 0},
        adjustments: {'c': 100},
        payerUid: 'a',
      );
      expect(r.shares, {'a': 450.0, 'b': 450.0, 'c': 100.0});
    });

    test('half shares and leftover paise to the payer', () {
      final r = SplitCalculator.shares(total: 100, weights: {'a': 1.5, 'b': 1.5, 'c': 1}, payerUid: 'c');
      expect(sumPaise(r.shares), 10000);
      expect(r.shares['a'], 37.5);
      expect(r.shares['c'], 25.0);
    });

    test('adjustments bigger than the total are refused, in the right currency', () {
      final r = SplitCalculator.shares(
        total: 100,
        weights: {'a': 1},
        adjustments: {'a': 150},
        payerUid: 'a',
        fmt: (v) => Currencies.format(v, 'USD'),
      );
      expect(r.isValid, isFalse);
      expect(r.error, contains(r'US$50'));
    });

    test('no shares and nothing adjusted', () {
      expect(SplitCalculator.shares(total: 100, weights: {'a': 0}, payerUid: 'a').isValid, isFalse);
      expect(SplitCalculator.shares(total: 100, weights: {'a': -1}, payerUid: 'a').isValid, isFalse);
    });
  });

  group('currencies', () {
    test('foreign shares convert to rupees that add up exactly', () {
      final inr = Currencies.toRupees({'a': 33.33, 'b': 33.33, 'c': 33.34}, 83.517);
      expect(sumPaise(inr), (10000 * 83.517).round());
      expect(inr.length, 3);
    });

    test('formatting', () {
      expect(Currencies.format(1200, 'INR'), Money.format(1200));
      expect(Currencies.format(45.5, 'USD'), r'US$45.50');
      expect(Currencies.format(120, 'AED'), 'AED 120');
      expect(Currencies.format(500, 'THB'), '฿500');
    });

    test('expense keeps what was typed abroad', () {
      final e = GroupExpenseModel.fromMap({
        'payerUid': 'a',
        'amount': 8351.7,
        'description': 'Dinner',
        'splits': {
          'a': {'amountOwed': 4175.85, 'settled': true},
          'b': {'amountOwed': 4175.85, 'settled': false},
        },
        'splitType': 'shares',
        'shareWeights': {'a': 1, 'b': 1},
        'fx': {
          'currency': 'USD',
          'rate': 83.517,
          'amount': 100,
          'shares': {'a': 50, 'b': 50},
        },
        'commentCount': 2,
      }, 'e1');
      expect(e.splitMode, SplitMode.shares);
      expect(e.fx?.currency, 'USD');
      expect(e.fx?.shares, {'a': 50.0, 'b': 50.0});
      expect(e.shareWeights, {'a': 1.0, 'b': 1.0});
      expect(e.commentCount, 2);
      final again = GroupExpenseModel.fromMap(e.toMap()..remove('updatedAt'), 'e1');
      expect(again.fx?.rate, 83.517);
      expect(again.commentCount, 2);
    });

    test('older expenses read the same as before', () {
      final e = GroupExpenseModel.fromMap({
        'payerUid': 'a',
        'amount': 100,
        'splits': {'a': 50, 'b': 50},
      }, 'old');
      expect(e.fx, isNull);
      expect(e.shareWeights, isNull);
      expect(e.commentCount, 0);
      expect(e.toMap().containsKey('fx'), isFalse);
    });
  });

  group('trip mode', () {
    GroupModel trip(DateTime start, DateTime end) => GroupModel(
      groupId: 'g',
      name: 'Goa',
      members: const ['a'],
      admins: const ['a'],
      createdAt: DateTime(2026),
      createdBy: 'a',
      tripStart: start,
      tripEnd: end,
    );

    test('days, today and over', () {
      final g = trip(DateTime(2026, 12, 12), DateTime(2026, 12, 16));
      expect(g.isTrip, isTrue);
      expect(g.tripDays, 5);
      expect(g.tripDay(DateTime(2026, 12, 14, 22)), 3);
      expect(g.tripDay(DateTime(2026, 12, 11)), isNull);
      expect(g.tripOver(DateTime(2026, 12, 16, 23, 59)), isFalse);
      expect(g.tripOver(DateTime(2026, 12, 17)), isTrue);
    });

    test('a normal group is not a trip', () {
      final g = GroupModel.fromMap({
        'name': 'Flat',
        'members': ['a'],
        'createdBy': 'a',
      }, 'g');
      expect(g.isTrip, isFalse);
      expect(g.currency, isNull);
      expect(g.tripDay(DateTime.now()), isNull);
    });
  });
}
