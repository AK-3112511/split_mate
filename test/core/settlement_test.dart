import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/domain/settlement.dart';

class E implements LedgerEntry {
  @override
  final String payerUid;
  @override
  final double amount;
  @override
  final Map<String, double> shareByUid;
  @override
  final bool isDeleted;
  E(this.payerUid, this.amount, this.shareByUid, {this.isDeleted = false});
}

/// Payment from → to of [amt] is modelled as an expense paid by `from` that `to` consumed.
E pay(String from, String to, double amt) => E(from, amt, {to: amt});

void main() {
  group('netBalances', () {
    test('sums to zero and ignores deleted', () {
      final net = Settlement.netBalances([
        E('a', 300, {'a': 100, 'b': 100, 'c': 100}),
        E('b', 60, {'a': 30, 'b': 30}),
        E('c', 999, {'a': 999}, isDeleted: true),
      ], members: ['a', 'b', 'c', 'd']);
      expect(net, {'a': 170.0, 'b': -70.0, 'c': -100.0, 'd': 0.0});
      expect(net.values.fold<double>(0, (x, y) => x + y), closeTo(0, 1e-9));
    });

    test('payments reduce debt', () {
      final net = Settlement.netBalances([
        E('a', 100, {'a': 50, 'b': 50}),
        pay('b', 'a', 50),
      ]);
      expect(net['a'], 0);
      expect(net['b'], 0);
    });
  });

  group('simplify', () {
    test('minimises transfers for a chain', () {
      final t = Settlement.simplify({'a': 100, 'b': 0, 'c': -100});
      expect(t.length, 1);
      expect(t.first.fromUid, 'c');
      expect(t.first.toUid, 'a');
      expect(t.first.amount, 100);
    });
  });

  group('pairwise', () {
    // Spec §12 worked example: A pays ₹1000 food + ₹500 fun (equal, 2 people),
    // B pays ₹200 auto (equal). Pairwise: B owes A 750 − 100 = 650.
    final entries = [
      E('A', 1000, {'A': 500, 'B': 500}),
      E('A', 500, {'A': 250, 'B': 250}),
      E('B', 200, {'A': 100, 'B': 100}),
    ];

    test('pairwiseFor from each side', () {
      expect(Settlement.pairwiseFor('A', entries), {'B': 650.0});
      expect(Settlement.pairwiseFor('B', entries), {'A': -650.0});
    });

    test('pairwise debts list directions', () {
      final debts = Settlement.pairwiseDebts(entries);
      expect(debts.length, 1);
      expect(debts.first.fromUid, 'B');
      expect(debts.first.toUid, 'A');
      expect(debts.first.amount, 650);
    });

    test('settling the pair zeroes it', () {
      final after = [...entries, pay('B', 'A', 650)];
      expect(Settlement.pairwiseFor('A', after)['B'], 0);
      expect(Settlement.pairwiseDebts(after), isEmpty);
    });

    test('three people: pairwise only counts direct sharing', () {
      // C paid for B only; A is not involved with C.
      final e = [
        E('A', 90, {'A': 30, 'B': 30, 'C': 30}),
        E('C', 40, {'B': 40}),
      ];
      expect(Settlement.pairwiseFor('A', e), {'B': 30.0, 'C': 30.0});
      expect(Settlement.pairwiseFor('B', e), {'A': -30.0, 'C': -40.0});
      expect(Settlement.pairwiseFor('C', e), {'A': -30.0, 'B': 40.0});
    });
  });
}
