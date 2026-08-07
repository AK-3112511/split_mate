import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/utils/settlement_algorithm.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';

void main() {
  group('Settlement Algorithm Unit Tests', () {
    const String groupId = 'test-group-123';
    const String memberA = 'user-a';
    const String memberB = 'user-b';
    const String memberC = 'user-c';
    const List<String> members = [memberA, memberB, memberC];

    group('recomputeBalances tests', () {
      test('Empty expenses list resolves to zero balances for all members', () {
        final balances = recomputeBalances(groupId, [], members);
        expect(balances[memberA], 0.0);
        expect(balances[memberB], 0.0);
        expect(balances[memberC], 0.0);
      });

      test('Simple equal split without remainders', () {
        final expense = GroupExpenseModel(
          expenseId: 'exp-1',
          payerUid: memberA,
          amount: 300.0,
          category: 'Food',
          description: 'Dinner',
          splitType: 'equal',
          splits: {
            memberA: 100.0,
            memberB: 100.0,
            memberC: 100.0,
          },
          createdAt: DateTime.now(),
        );

        final balances = recomputeBalances(groupId, [expense], members);
        // A paid 300, owes 100 -> +200
        expect(balances[memberA], 200.0);
        // B paid 0, owes 100 -> -100
        expect(balances[memberB], -100.0);
        // C paid 0, owes 100 -> -100
        expect(balances[memberC], -100.0);
      });

      test('Equal split rounding remainders go to payer', () {
        // 100.0 split equally between A, B, C.
        // Each gets 33.33. Payer A gets 33.33 + 0.01 = 33.34.
        final expense = GroupExpenseModel(
          expenseId: 'exp-2',
          payerUid: memberA,
          amount: 100.0,
          category: 'Travel',
          description: 'Taxi',
          splitType: 'equal',
          splits: {
            memberA: 33.34,
            memberB: 33.33,
            memberC: 33.33,
          },
          createdAt: DateTime.now(),
        );

        final balances = recomputeBalances(groupId, [expense], members);
        // A paid 100, owes 33.34 -> +66.66
        expect(balances[memberA], 66.66);
        // B owes 33.33 -> -33.33
        expect(balances[memberB], -33.33);
        // C owes 33.33 -> -33.33
        expect(balances[memberC], -33.33);
      });

      test('Soft-deleted expenses are successfully ignored', () {
        final expenseActive = GroupExpenseModel(
          expenseId: 'exp-active',
          payerUid: memberA,
          amount: 150.0,
          category: 'Snacks',
          description: 'Grocery',
          splitType: 'equal',
          splits: {
            memberA: 50.0,
            memberB: 50.0,
            memberC: 50.0,
          },
          createdAt: DateTime.now(),
          isDeleted: false,
        );

        final expenseDeleted = GroupExpenseModel(
          expenseId: 'exp-deleted',
          payerUid: memberB,
          amount: 90.0,
          category: 'Drinks',
          description: 'Coke',
          splitType: 'equal',
          splits: {
            memberA: 30.0,
            memberB: 30.0,
            memberC: 30.0,
          },
          createdAt: DateTime.now(),
          isDeleted: true,
        );

        final balances = recomputeBalances(
          groupId,
          [expenseActive, expenseDeleted],
          members,
        );

        // Should only compute expenseActive:
        // A paid 150, owes 50 -> +100
        expect(balances[memberA], 100.0);
        // B owes 50 -> -50
        expect(balances[memberB], -50.0);
        // C owes 50 -> -50
        expect(balances[memberC], -50.0);
      });
    });

    group('settleUp tests', () {
      test('Single simple debt settlement', () {
        final netBalance = {
          memberA: 100.0,   // creditor
          memberB: -100.0,  // debtor
          memberC: 0.0,     // neutral
        };

        final transactions = settleUp(netBalance);
        expect(transactions.length, 1);
        expect(transactions.first['from'], memberB);
        expect(transactions.first['to'], memberA);
        expect(transactions.first['amount'], 100.0);
      });

      test('Minimizes transaction count for circular/indirect debts', () {
        // Indirect debt: B owes A 50. C owes B 50.
        // Net: A has +50, B has 0, C has -50.
        // Expected: C pays A 50 directly (1 transaction instead of 2).
        final netBalance = {
          memberA: 50.0,
          memberB: 0.0,
          memberC: -50.0,
        };

        final transactions = settleUp(netBalance);
        expect(transactions.length, 1);
        expect(transactions.first['from'], memberC);
        expect(transactions.first['to'], memberA);
        expect(transactions.first['amount'], 50.0);
      });

      test('Complex multi-person debt matching', () {
        // A: +60.0, B: +20.0
        // C: -50.0, D: -30.0
        // Expected transactions:
        // - C pays A 50.0 (C is zeroed out, A remains at +10.0)
        // - D pays A 10.0 (A is zeroed out, D remains at -20.0)
        // - D pays B 20.0 (B and D both zeroed out)
        final netBalance = {
          memberA: 60.0,
          memberB: 20.0,
          memberC: -50.0,
          'user-d': -30.0,
        };

        final transactions = settleUp(netBalance);
        expect(transactions.length, 3);

        // Assert transaction 1: C pays A 50.0
        final t1 = transactions[0];
        expect(t1['from'], memberC);
        expect(t1['to'], memberA);
        expect(t1['amount'], 50.0);

        // Assert transaction 2: D pays B 20.0
        final t2 = transactions[1];
        expect(t2['from'], 'user-d');
        expect(t2['to'], memberB);
        expect(t2['amount'], 20.0);

        // Assert transaction 3: D pays A 10.0
        final t3 = transactions[2];
        expect(t3['from'], 'user-d');
        expect(t3['to'], memberA);
        expect(t3['amount'], 10.0);
      });
    });
  });
}
