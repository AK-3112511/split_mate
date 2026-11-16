import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../../core/utils/write_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_profile.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/domain/notification_model.dart';
import '../domain/friend_model.dart';

/// Every friendship edge of the current user (accepted + pending both ways).
final friendsStreamProvider = StreamProvider<List<FriendModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(friendsRepositoryProvider).stream(uid);
});

final acceptedFriendsProvider = Provider<List<FriendModel>>((ref) {
  return (ref.watch(friendsStreamProvider).valueOrNull ?? const [])
      .where((f) => f.isAccepted)
      .toList();
});

final incomingFriendRequestCountProvider = Provider<int>((ref) {
  final me = ref.watch(currentUidProvider);
  if (me == null) return 0;
  return (ref.watch(friendsStreamProvider).valueOrNull ?? const [])
      .where((f) => f.isIncomingFor(me))
      .length;
});

/// How a person is shown everywhere: "You", my nickname for them, or their name.
final memberNameProvider = Provider.autoDispose.family<String, String>((ref, uid) {
  final me = ref.watch(currentUidProvider);
  if (uid == me) return 'You';
  final friends = ref.watch(friendsStreamProvider).valueOrNull ?? const [];
  for (final f in friends) {
    if (f.uid == uid && f.nickname != null) return f.nickname!;
  }
  final profile = ref.watch(userProfileProvider(uid)).valueOrNull;
  return profile?.displayName ?? 'Member';
});

/// Like [memberNameProvider] but never "You" (for third-person messages).
final realNameProvider = Provider.autoDispose.family<String, String>((ref, uid) {
  final friends = ref.watch(friendsStreamProvider).valueOrNull ?? const [];
  for (final f in friends) {
    if (f.uid == uid && f.nickname != null) return f.nickname!;
  }
  return ref.watch(userProfileProvider(uid)).valueOrNull?.displayName ?? 'Member';
});

enum FriendRequestResult { sent, accepted }

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
    ref.watch(notificationsRepositoryProvider),
  );
});

class FriendsRepository {
  final FirebaseFirestore _db;
  final String? _uid;
  final NotificationsRepository _notify;

  FriendsRepository(this._db, this._uid, this._notify);

  String get _me {
    final uid = _uid;
    if (uid == null) throw const AppException('Please sign in again.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _edge(String owner, String other) =>
      _db.collection('friends').doc(owner).collection('friendList').doc(other);

  Stream<List<FriendModel>> stream(String uid) {
    return retryOnPermissionDenied(() => _db
        .collection('friends')
        .doc(uid)
        .collection('friendList')
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => FriendModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
          return list;
        }));
  }

  static String normalizeCode(String code) => code.trim().toUpperCase().replaceAll(' ', '');

  /// Looks a person up by their 6-character friend code.
  Future<UserProfile> findByCode(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.length != 6) throw const AppException('Friend codes are 6 characters.');
    String? uid;
    final reg = await _db.collection('app_codes').doc(code).get();
    if (reg.exists) {
      uid = reg.data()?['uid'] as String?;
    } else {
      // v1 users who haven't opened v2 yet aren't in the registry.
      final q = await _db.collection('users').where('appCode', isEqualTo: code).limit(1).get();
      if (q.docs.isNotEmpty) uid = q.docs.first.id;
    }
    if (uid == null) throw AppException('No one has the code $code. Double-check it?');
    final profile = await _db.collection('users').doc(uid).get();
    return UserProfile.fromMap(uid, profile.data());
  }

  /// Sends a request, or accepts instantly if they already asked you.
  Future<FriendRequestResult> sendRequest(String rawCode) async {
    final me = _me;
    final target = await findByCode(rawCode);
    if (target.uid == me) throw const AppException('That\'s your own code 🙂');

    final existing = await _edge(me, target.uid).get();
    if (existing.exists) {
      final edge = FriendModel.fromMap(existing.data()!, existing.id);
      if (edge.isAccepted) throw AppException('${target.displayName} is already your friend.');
      if (edge.sentBy == me) throw AppException('Request already sent to ${target.displayName}.');
      await accept(target.uid);
      return FriendRequestResult.accepted;
    }

    final now = DateTime.now();
    final batch = _db.batch();
    batch.set(_edge(me, target.uid),
        FriendModel(uid: target.uid, status: FriendModel.pending, addedAt: now, sentBy: me).toMap());
    batch.set(_edge(target.uid, me),
        FriendModel(uid: me, status: FriendModel.pending, addedAt: now, sentBy: me).toMap());
    await commitWithTimeout(batch.commit());
    runInBackground(() => _notify.send(
          recipients: [target.uid],
          type: NotificationModel.friendRequest,
          message: '${_notify.senderName} sent you a friend request',
        ), label: 'friend request notify');
    return FriendRequestResult.sent;
  }

  Future<void> accept(String otherUid) async {
    final me = _me;
    final batch = _db.batch();
    batch.update(_edge(me, otherUid), {'status': FriendModel.accepted});
    batch.update(_edge(otherUid, me), {'status': FriendModel.accepted});
    await commitWithTimeout(batch.commit());
    runInBackground(() => _notify.send(
          recipients: [otherUid],
          type: NotificationModel.friendAccepted,
          message: '${_notify.senderName} accepted your friend request',
        ), label: 'friend accepted notify');
  }

  /// Decline an incoming request, cancel an outgoing one, or unfriend.
  Future<void> remove(String otherUid) async {
    final me = _me;
    final batch = _db.batch();
    batch.delete(_edge(me, otherUid));
    batch.delete(_edge(otherUid, me));
    await commitWithTimeout(batch.commit());
  }

  Future<void> setNickname(String otherUid, String? nickname) async {
    final clean = nickname?.trim() ?? '';
    if (clean.length > 24) throw const AppException('Keep nicknames under 24 characters.');
    await commitWithTimeout(_edge(_me, otherUid).update({
      'nickname': clean.isEmpty ? FieldValue.delete() : clean,
    }));
  }
}
