import 'dart:math';
import '../../../core/utils/money.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;

/// Someone in a group who isn't on SplitMate yet. They take part in splits
/// under a `guest_…` id until they (or a member) claim the spot.
class GuestMember {
  final String id;
  final String name;
  final String addedBy;
  final DateTime? createdAt;

  const GuestMember({required this.id, required this.name, required this.addedBy, this.createdAt});

  factory GuestMember.fromMap(String id, Map<String, dynamic> map) => GuestMember(
        id: id,
        name: (map['name'] ?? 'Guest').toString(),
        addedBy: (map['addedBy'] ?? '').toString(),
        createdAt: readDate(map['createdAt']),
      );
}

const String guestPrefix = 'guest_';

bool isGuestId(String id) => id.startsWith(guestPrefix);

String newGuestId([Random? random]) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = random ?? Random.secure();
  return guestPrefix + String.fromCharCodes(Iterable.generate(12, (_) => chars.codeUnitAt(r.nextInt(chars.length))));
}

/// The fields of one expense document that change when [guestId]'s spot is
/// taken over by [uid], or null when the expense doesn't involve the guest.
///
/// If [uid] already has a share in the same expense (a member who was also
/// added as a guest), the two shares are merged.
Map<String, dynamic>? guestTakeoverUpdate(Map<String, dynamic> data, String guestId, String uid) {
  final update = <String, dynamic>{};

  if (data['payerUid'] == guestId) update['payerUid'] = uid;

  final rawSplits = data['splits'];
  if (rawSplits is Map && rawSplits.containsKey(guestId)) {
    final splits = <String, dynamic>{
      for (final e in rawSplits.entries) e.key.toString(): e.value,
    };
    final guest = Map<String, dynamic>.from(splits.remove(guestId) as Map);
    final existing = splits[uid];
    if (existing is Map) {
      final a = (existing['amountOwed'] as num?)?.toDouble() ?? 0;
      final b = (guest['amountOwed'] as num?)?.toDouble() ?? 0;
      splits[uid] = {
        ...Map<String, dynamic>.from(existing),
        'amountOwed': Money.fromPaise(Money.toPaise(a) + Money.toPaise(b)),
        'settled': existing['settled'] == true && guest['settled'] == true,
      };
    } else {
      splits[uid] = guest;
    }
    update['splits'] = splits;
  }

  final rawItems = data['items'];
  if (rawItems is List && rawItems.any((i) => i is Map && (i['memberUids'] as List?)?.contains(guestId) == true)) {
    update['items'] = [
      for (final i in rawItems)
        if (i is Map && (i['memberUids'] as List?)?.contains(guestId) == true)
          {
            ...Map<String, dynamic>.from(i),
            'memberUids': {
              for (final m in (i['memberUids'] as List)) m.toString() == guestId ? uid : m.toString(),
            }.toList(),
          }
        else
          i,
    ];
  }

  return update.isEmpty ? null : update;
}
