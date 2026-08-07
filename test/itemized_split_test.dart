import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';

void main() {
  group('Itemized Split Model Tests', () {
    test('GroupExpenseItemModel parses and maps correctly', () {
      final map = {
        'name': 'Seafood Platter',
        'amount': 2450.0,
        'memberUids': ['user-1', 'user-2'],
      };

      final item = GroupExpenseItemModel.fromMap(map);
      expect(item.name, 'Seafood Platter');
      expect(item.amount, 2450.0);
      expect(item.memberUids, containsAll(['user-1', 'user-2']));

      final mapOut = item.toMap();
      expect(mapOut['name'], 'Seafood Platter');
      expect(mapOut['amount'], 2450.0);
      expect(mapOut['memberUids'], containsAll(['user-1', 'user-2']));
    });

    test('GroupExpenseModel parses items correctly', () {
      final map = {
        'payerUid': 'user-1',
        'amount': 3650.0,
        'category': 'Food',
        'description': 'Itemized Dinner',
        'splitType': 'itemized',
        'splits': {'user-1': 2450.0, 'user-2': 1200.0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 17)),
        'isDeleted': false,
        'items': [
          {
            'name': 'Seafood Platter',
            'amount': 2450.0,
            'memberUids': ['user-1'],
          },
          {
            'name': 'Kingfisher Ultra',
            'amount': 1200.0,
            'memberUids': ['user-2'],
          }
        ]
      };

      final expense = GroupExpenseModel.fromMap(map, 'exp-id');
      expect(expense.splitType, 'itemized');
      expect(expense.items, isNotNull);
      expect(expense.items!.length, 2);
      expect(expense.items![0].name, 'Seafood Platter');
      expect(expense.items![1].amount, 1200.0);

      final mapOut = expense.toMap();
      expect(mapOut['splitType'], 'itemized');
      expect(mapOut['items'], isNotNull);
      expect(mapOut['items'].length, 2);
    });
  });

  group('Itemized Split Math Division & Remainder Logic', () {
    test('Calculates simple itemized splits correctly', () {
      // Setup items list:
      // Item 1: 1200 split among 4 members -> 300 each
      // Item 2: 2450 split among 2 members -> 1225 each
      final items = [
        GroupExpenseItemModel(
          name: 'Kingfisher Ultra',
          amount: 1200.0,
          memberUids: ['user-1', 'user-2', 'user-3', 'user-4'],
        ),
        GroupExpenseItemModel(
          name: 'Seafood Platter',
          amount: 2450.0,
          memberUids: ['user-1', 'user-2'],
        ),
      ];

      // Simulated _calculateFinalSplits logic
      final Map<String, double> splits = {
        'user-1': 0.0,
        'user-2': 0.0,
        'user-3': 0.0,
        'user-4': 0.0,
      };

      final payerUid = 'user-1';

      for (final item in items) {
        if (item.memberUids.isEmpty) continue;
        int itemCents = (item.amount * 100).round();
        int count = item.memberUids.length;
        int baseCents = itemCents ~/ count;
        int remainderCents = itemCents % count;

        for (final uid in item.memberUids) {
          splits[uid] = (splits[uid] ?? 0.0) + (baseCents / 100.0);
        }

        if (remainderCents > 0) {
          final String targetUid = item.memberUids.contains(payerUid) ? payerUid : item.memberUids.first;
          splits[targetUid] = (splits[targetUid] ?? 0.0) + (remainderCents / 100.0);
        }
      }

      splits.forEach((uid, val) {
        splits[uid] = double.parse(val.toStringAsFixed(2));
      });

      // user-1: 300 (item 1) + 1225 (item 2) = 1525
      // user-2: 300 (item 1) + 1225 (item 2) = 1525
      // user-3: 300
      // user-4: 300
      expect(splits['user-1'], 1525.0);
      expect(splits['user-2'], 1525.0);
      expect(splits['user-3'], 300.0);
      expect(splits['user-4'], 300.0);
    });

    test('Distributes remainder cents correctly to target member', () {
      // Item: 10.01 split among 3 members -> 3.33 each with 0.02 remainder
      // Target: user-1 (payer)
      final items = [
        GroupExpenseItemModel(
          name: 'Item with remainder',
          amount: 10.01,
          memberUids: ['user-1', 'user-2', 'user-3'],
        ),
      ];

      final Map<String, double> splits = {
        'user-1': 0.0,
        'user-2': 0.0,
        'user-3': 0.0,
      };

      final payerUid = 'user-1';

      for (final item in items) {
        if (item.memberUids.isEmpty) continue;
        int itemCents = (item.amount * 100).round();
        int count = item.memberUids.length;
        int baseCents = itemCents ~/ count;
        int remainderCents = itemCents % count;

        for (final uid in item.memberUids) {
          splits[uid] = (splits[uid] ?? 0.0) + (baseCents / 100.0);
        }

        if (remainderCents > 0) {
          final String targetUid = item.memberUids.contains(payerUid) ? payerUid : item.memberUids.first;
          splits[targetUid] = (splits[targetUid] ?? 0.0) + (remainderCents / 100.0);
        }
      }

      splits.forEach((uid, val) {
        splits[uid] = double.parse(val.toStringAsFixed(2));
      });

      // baseCents = 1001 ~/ 3 = 333 cents -> 3.33
      // remainder = 1001 % 3 = 2 cents -> 0.02
      // target user-1 gets 3.33 + 0.02 = 3.35
      // user-2 gets 3.33
      // user-3 gets 3.33
      expect(splits['user-1'], 3.35);
      expect(splits['user-2'], 3.33);
      expect(splits['user-3'], 3.33);
    });
  });
}
