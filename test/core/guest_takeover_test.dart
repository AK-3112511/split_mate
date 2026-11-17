import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/groups/domain/group_model.dart';
import 'package:split_mate/features/groups/domain/guest.dart';

void main() {
  test('groups list guests after members as participants', () {
    final g = GroupModel.fromMap({
      'name': 'Goa',
      'members': ['arham', 'priya'],
      'admins': ['arham'],
      'createdBy': 'arham',
      'guests': {
        'guest_abc123def456': {'name': 'Rahul', 'addedBy': 'arham'},
      },
    }, 'g1');
    expect(g.guests['guest_abc123def456']!.name, 'Rahul');
    expect(g.participants, ['arham', 'priya', 'guest_abc123def456']);
    expect(g.isMember('guest_abc123def456'), isFalse); // guests never get group access
  });

  const guest = 'guest_abc123def456';

  test('payer, splits and items move from the guest to the real account', () {
    final data = {
      'payerUid': guest,
      'splits': {
        guest: {'amountOwed': 100.0, 'settled': true},
        'priya': {'amountOwed': 100.0, 'settled': false},
      },
      'items': [
        {'name': 'Pizza', 'amount': 150.0, 'memberUids': [guest, 'priya']},
        {'name': 'Coke', 'amount': 50.0, 'memberUids': ['priya']},
      ],
    };
    final update = guestTakeoverUpdate(data, guest, 'rahul')!;
    expect(update['payerUid'], 'rahul');
    expect((update['splits'] as Map).keys, unorderedEquals(['rahul', 'priya']));
    expect((update['splits'] as Map)['rahul'], {'amountOwed': 100.0, 'settled': true});
    expect((update['items'] as List)[0]['memberUids'], ['rahul', 'priya']);
    expect((update['items'] as List)[1]['memberUids'], ['priya']);
  });

  test('a member who was also added as a guest gets one merged share', () {
    final data = {
      'payerUid': 'priya',
      'splits': {
        guest: {'amountOwed': 33.33, 'settled': false},
        'rahul': {'amountOwed': 33.34, 'settled': true},
        'priya': {'amountOwed': 33.33, 'settled': true},
      },
    };
    final splits = guestTakeoverUpdate(data, guest, 'rahul')!['splits'] as Map;
    expect(splits.length, 2);
    expect(splits['rahul']['amountOwed'], 66.67);
    expect(splits['rahul']['settled'], isFalse); // still owes the guest's part
  });

  test('expenses without the guest are left alone', () {
    final data = {
      'payerUid': 'priya',
      'splits': {'priya': {'amountOwed': 50.0}, 'amit': {'amountOwed': 50.0}},
    };
    expect(guestTakeoverUpdate(data, guest, 'rahul'), isNull);
  });

  test('guest ids are recognisable and unique enough', () {
    final a = newGuestId();
    final b = newGuestId();
    expect(isGuestId(a), isTrue);
    expect(isGuestId('Xk3uFaS9'), isFalse);
    expect(a, isNot(b));
    expect(a.length, guestPrefix.length + 12);
  });
}
