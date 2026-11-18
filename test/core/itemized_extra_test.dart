import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/domain/split_calculator.dart';
import 'package:split_mate/core/utils/money.dart';

void main() {
  const items = [
    SplitItem(name: 'Paneer Tikka', amount: 300, memberUids: ['a']),
    SplitItem(name: 'Beer', amount: 600, memberUids: ['b']),
    SplitItem(name: 'Naan', amount: 100, memberUids: ['a', 'b']),
  ];

  int sum(SplitResult r) => r.shares.values.fold(0, (a, v) => a + Money.toPaise(v));

  test('no extra: same as before', () {
    final r = SplitCalculator.itemized(items: items, payerUid: 'a');
    expect(r.shares, {'a': 350.0, 'b': 650.0});
    expect(r.total, 1000);
  });

  test('tax and service charge follow what each person had', () {
    final r = SplitCalculator.itemized(items: items, payerUid: 'a', extra: 100);
    expect(r.total, 1100);
    expect(r.shares, {'a': 385.0, 'b': 715.0});
    expect(sum(r), 110000);
  });

  test('discount reduces shares proportionally', () {
    final r = SplitCalculator.itemized(items: items, payerUid: 'a', extra: -100);
    expect(r.total, 900);
    expect(r.shares, {'a': 315.0, 'b': 585.0});
  });

  test('uneven paise: leftover goes to the payer, total exact', () {
    const three = [
      SplitItem(name: 'x', amount: 10, memberUids: ['a']),
      SplitItem(name: 'y', amount: 10, memberUids: ['b']),
      SplitItem(name: 'z', amount: 10, memberUids: ['c']),
    ];
    final r = SplitCalculator.itemized(items: three, payerUid: 'c', extra: 1);
    expect(sum(r), 3100);
    expect(r.shares['a'], 10.33);
    expect(r.shares['b'], 10.33);
    expect(r.shares['c'], 10.34);
  });

  test('a discount bigger than the bill is refused', () {
    final r = SplitCalculator.itemized(items: items, payerUid: 'a', extra: -1000);
    expect(r.isValid, isFalse);
    expect(r.error, contains('discount'));
  });
}
