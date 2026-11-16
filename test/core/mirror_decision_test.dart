import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/groups/data/group_mirror_service.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';
import 'package:split_mate/features/personal_expenses/domain/expense_model.dart';

GroupExpenseModel exp({
  String payer = 'A',
  Map<String, SplitEntry>? splits,
  bool deleted = false,
  String? type,
  String desc = 'Pizza',
  DateTime? date,
}) =>
    GroupExpenseModel(
      expenseId: 'e1',
      type: type ?? GroupExpenseModel.typeExpense,
      payerUid: payer,
      amount: 100,
      category: 'Food',
      description: desc,
      splitType: 'equal',
      splits: splits ??
          const {
            'A': SplitEntry(amountOwed: 50, settled: true),
            'B': SplitEntry(amountOwed: 50, settled: false),
          },
      date: date ?? DateTime(2026, 11, 1),
      createdAt: DateTime(2026, 11, 1),
      isDeleted: deleted,
    );

ExpenseModel mirror({double amount = 50, bool hidden = false, String desc = 'Pizza'}) => ExpenseModel(
      id: 'mirror_e1',
      amount: amount,
      categoryId: 'food',
      categoryName: 'Food',
      description: desc,
      date: DateTime(2026, 11, 1),
      createdAt: DateTime(2026, 11, 1),
      isFromGroup: true,
      sourceExpenseId: 'e1',
      hidden: hidden,
    );

void main() {
  test('payer mirrors immediately; debtor waits for settlement', () {
    expect(decideMirror(me: 'A', expense: exp(), existing: null), MirrorOp.upsert);
    expect(decideMirror(me: 'B', expense: exp(), existing: null), MirrorOp.none);
    final settled = exp(splits: const {
      'A': SplitEntry(amountOwed: 50, settled: true),
      'B': SplitEntry(amountOwed: 50, settled: true),
    });
    expect(decideMirror(me: 'B', expense: settled, existing: null), MirrorOp.upsert);
  });

  test('v1 wrong-user mirror (creator not payer, unsettled) is removed', () {
    expect(decideMirror(me: 'B', expense: exp(), existing: mirror()), MirrorOp.remove);
  });

  test('up-to-date mirror is left alone; changed amount/desc/date updates it', () {
    expect(decideMirror(me: 'A', expense: exp(), existing: mirror()), MirrorOp.none);
    expect(decideMirror(me: 'A', expense: exp(), existing: mirror(amount: 40)), MirrorOp.upsert);
    expect(decideMirror(me: 'A', expense: exp(desc: 'Pasta'), existing: mirror()), MirrorOp.upsert);
    expect(decideMirror(me: 'A', expense: exp(date: DateTime(2026, 11, 2)), existing: mirror()),
        MirrorOp.upsert);
  });

  test('deleted group expense hides the mirror', () {
    expect(decideMirror(me: 'A', expense: exp(deleted: true), existing: mirror()), MirrorOp.hide);
    expect(decideMirror(me: 'A', expense: exp(deleted: true), existing: null), MirrorOp.none);
  });

  test('user-hidden mirrors are never resurrected (v1 bug)', () {
    expect(decideMirror(me: 'A', expense: exp(), existing: mirror(hidden: true)), MirrorOp.none);
  });

  test('payments never produce mirrors', () {
    expect(decideMirror(me: 'A', expense: exp(type: 'payment'), existing: null), MirrorOp.none);
  });

  test('share removed in an edit drops the mirror', () {
    final edited = exp(splits: const {'A': SplitEntry(amountOwed: 100, settled: true)});
    expect(decideMirror(me: 'B', expense: edited, existing: mirror()), MirrorOp.remove);
  });

  test('mergeSettledFlags keeps settled only for unchanged shares', () {
    final prev = exp(splits: const {
      'A': SplitEntry(amountOwed: 40, settled: true),
      'B': SplitEntry(amountOwed: 30, settled: true),
      'C': SplitEntry(amountOwed: 30, settled: true),
    });
    final merged = GroupExpenseModel.mergeSettledFlags(
      newShares: {'A': 40, 'B': 30, 'C': 20, 'D': 10},
      newPayer: 'A',
      previous: prev,
    );
    expect(merged['A']!.settled, isTrue); // payer
    expect(merged['B']!.settled, isTrue); // unchanged
    expect(merged['C']!.settled, isFalse); // share changed
    expect(merged['D']!.settled, isFalse); // new
  });
}
