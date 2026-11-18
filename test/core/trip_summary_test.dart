import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';
import 'package:split_mate/features/groups/domain/group_model.dart';
import 'package:split_mate/features/groups/domain/trip_summary.dart';

GroupExpenseModel e(
  String id,
  String payer,
  double amount,
  Map<String, double> shares,
  DateTime date, {
  String? type,
  Map<String, dynamic>? fx,
}) => GroupExpenseModel.fromMap({
  'type': type,
  'payerUid': payer,
  'amount': amount,
  'description': id,
  'splits': {
    for (final s in shares.entries) s.key: {'amountOwed': s.value, 'settled': s.key == payer},
  },
  'date': null,
  if (fx != null) 'fx': fx,
}, id).copyDate(date);

extension on GroupExpenseModel {
  GroupExpenseModel copyDate(DateTime d) => GroupExpenseModel(
    expenseId: expenseId,
    type: type,
    payerUid: payerUid,
    amount: amount,
    category: category,
    description: description,
    splitType: splitType,
    splits: splits,
    date: d,
    createdAt: d,
    fx: fx,
  );
}

void main() {
  final goa = GroupModel(
    groupId: 'g',
    name: 'Goa',
    members: const ['a', 'b', 'c'],
    admins: const ['a'],
    createdAt: DateTime(2026, 12),
    createdBy: 'a',
    tripStart: DateTime(2026, 12, 12),
    tripEnd: DateTime(2026, 12, 15),
  );

  test('totals, per day, who consumed and who paid, payments excluded', () {
    final s = TripSummary.compute(goa, [
      e('villa', 'a', 9000, {'a': 3000, 'b': 3000, 'c': 3000}, DateTime(2026, 12, 12)),
      e('dinner', 'b', 1500, {'a': 500, 'b': 500, 'c': 500}, DateTime(2026, 12, 13)),
      e('scooter', 'c', 1500, {'b': 750, 'c': 750}, DateTime(2026, 12, 13)),
      e('pay', 'b', 2500, {'a': 2500}, DateTime(2026, 12, 15), type: 'payment'),
    ]);
    expect(s.total, 12000);
    expect(s.days, 4);
    expect(s.perDay, 3000);
    expect(s.expenseCount, 3);
    expect(s.shareByUid, {'a': 3500.0, 'b': 4250.0, 'c': 4250.0});
    expect(s.paidByUid, {'a': 9000.0, 'b': 1500.0, 'c': 1500.0});
    expect(s.biggest?.description, 'villa');
    expect(s.busiestDay, DateTime(2026, 12, 12));
    expect(s.perPerson, 4000);
  });

  test('foreign currencies are listed', () {
    final s = TripSummary.compute(goa, [
      e(
        'tuk tuk',
        'a',
        250,
        {'a': 125, 'b': 125},
        DateTime(2026, 12, 12),
        fx: {
          'currency': 'THB',
          'rate': 2.5,
          'amount': 100,
          'shares': {'a': 50, 'b': 50},
        },
      ),
    ]);
    expect(s.currencies, {'THB'});
  });

  test('empty trip', () {
    final s = TripSummary.compute(goa, const []);
    expect(s.total, 0);
    expect(s.biggest, isNull);
    expect(s.perPerson, 0);
  });

  test('date ranges read naturally', () {
    expect(TripSummary.dateRange(DateTime(2026, 12, 12), DateTime(2026, 12, 16)), '12–16 Dec 2026');
    expect(TripSummary.dateRange(DateTime(2026, 11, 28), DateTime(2026, 12, 2)), '28 Nov – 2 Dec 2026');
    expect(TripSummary.dateRange(DateTime(2026, 12, 30), DateTime(2027, 1, 2)), '30 Dec 2026 – 2 Jan 2027');
    expect(TripSummary.dateRange(DateTime(2026, 12, 5), DateTime(2026, 12, 5)), '5 Dec 2026');
  });
}
