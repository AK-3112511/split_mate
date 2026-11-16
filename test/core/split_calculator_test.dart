import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/domain/split_calculator.dart';
import 'package:split_mate/core/utils/money.dart';

double sum(Map<String, double> m) => Money.fromPaise(m.values.fold(0, (a, b) => a + Money.toPaise(b)));

void main() {
  group('equal', () {
    test('remainder goes to payer when participating', () {
      final r = SplitCalculator.equal(total: 100, participants: ['a', 'b', 'c'], payerUid: 'b');
      expect(r.isValid, isTrue);
      expect(r.shares, {'a': 33.33, 'b': 33.34, 'c': 33.33});
      expect(sum(r.shares), 100);
    });

    test('remainder goes to first participant when payer is not in split', () {
      final r = SplitCalculator.equal(total: 10, participants: ['a', 'b', 'c'], payerUid: 'z');
      expect(r.shares, {'a': 3.34, 'b': 3.33, 'c': 3.33});
      expect(r.shares.containsKey('z'), isFalse);
    });

    test('rejects empty participants and zero total', () {
      expect(SplitCalculator.equal(total: 10, participants: [], payerUid: 'a').isValid, isFalse);
      expect(SplitCalculator.equal(total: 0, participants: ['a'], payerUid: 'a').isValid, isFalse);
    });
  });

  group('exact', () {
    test('valid when sum matches', () {
      final r = SplitCalculator.exact(total: 100, amounts: {'a': 60, 'b': 40, 'c': 0});
      expect(r.isValid, isTrue);
      expect(r.shares, {'a': 60, 'b': 40});
    });

    test('negative values are rejected (v1 let 150 + -50 pass)', () {
      final r = SplitCalculator.exact(total: 100, amounts: {'a': 150, 'b': -50});
      expect(r.isValid, isFalse);
      expect(r.error, contains('negative'));
    });

    test('reports remaining and overflow', () {
      final under = SplitCalculator.exact(total: 100, amounts: {'a': 30});
      expect(under.isValid, isFalse);
      expect(under.remaining, 70);
      expect(under.error, contains('left to assign'));
      final over = SplitCalculator.exact(total: 100, amounts: {'a': 130});
      expect(over.remaining, -30);
      expect(over.error, contains('over'));
    });
  });

  group('percent', () {
    test('thirds sum exactly to total', () {
      final r = SplitCalculator.percent(
        total: 100,
        percents: {'a': 33.33, 'b': 33.33, 'c': 33.34},
        payerUid: 'a',
      );
      expect(r.isValid, isTrue);
      expect(sum(r.shares), 100);
    });

    test('must total 100%', () {
      final r = SplitCalculator.percent(total: 100, percents: {'a': 50, 'b': 40}, payerUid: 'a');
      expect(r.isValid, isFalse);
      expect(r.error, contains('10% left'));
    });

    test('round-trips stored shares to percents that re-validate (v1 bug)', () {
      // 100 split as 33.33/33.33/33.34 → percents → back to shares unchanged.
      final shares = {'a': 33.33, 'b': 33.33, 'c': 33.34};
      final pct = SplitCalculator.percentsFromShares(shares, 100);
      final r = SplitCalculator.percent(total: 100, percents: pct, payerUid: 'c');
      expect(r.isValid, isTrue);
      expect(sum(r.shares), 100);

      final odd = {'a': 70.01, 'b': 29.99};
      final pct2 = SplitCalculator.percentsFromShares(odd, 100);
      expect(pct2.values.fold<double>(0, (a, b) => a + b), closeTo(100, 1e-9));
    });
  });

  group('itemized', () {
    test('each item split among its members, remainder to payer', () {
      final r = SplitCalculator.itemized(
        items: const [
          SplitItem(name: 'Pizza', amount: 100, memberUids: ['a', 'b', 'c']),
          SplitItem(name: 'Coke', amount: 50, memberUids: ['b']),
        ],
        payerUid: 'a',
      );
      expect(r.isValid, isTrue);
      expect(r.total, 150);
      expect(r.shares, {'a': 33.34, 'b': 83.33, 'c': 33.33});
      expect(sum(r.shares), 150);
    });

    test('item with nobody assigned is rejected (v1 inflated the payer)', () {
      final r = SplitCalculator.itemized(
        items: const [SplitItem(name: 'Fries', amount: 80, memberUids: [])],
        payerUid: 'a',
      );
      expect(r.isValid, isFalse);
      expect(r.error, contains('Fries'));
    });

    test('item without price rejected', () {
      final r = SplitCalculator.itemized(
        items: const [SplitItem(name: '', amount: 0, memberUids: ['a'])],
        payerUid: 'a',
      );
      expect(r.isValid, isFalse);
    });
  });

  test('SplitMode storage keys stay compatible with v1 data', () {
    expect(SplitMode.fromStorage('custom'), SplitMode.exact);
    expect(SplitMode.fromStorage('percentage'), SplitMode.percent);
    expect(SplitMode.fromStorage('itemized'), SplitMode.itemized);
    expect(SplitMode.fromStorage(null), SplitMode.equal);
  });
}
