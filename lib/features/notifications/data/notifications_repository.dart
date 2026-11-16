import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/notification_model.dart';

/// Newest first, capped for display.
final userNotificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationsRepositoryProvider).stream(uid);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(userNotificationsStreamProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});

/// When I last reminded [recipientUid] about a debt in [groupId] (or null).
final lastReminderProvider =
    StreamProvider.autoDispose.family<DateTime?, ({String groupId, String recipientUid})>((ref, a) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(notificationsRepositoryProvider).streamLastReminder(uid, a.groupId, a.recipientUid);
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(firestoreProvider), ref.watch(currentUidProvider), ref);
});

class NotificationsRepository {
  static const int displayLimit = 100;
  static const Duration reminderCooldown = Duration(hours: 24);

  final FirebaseFirestore _db;
  final String? _uid;
  final Ref _ref;

  NotificationsRepository(this._db, this._uid, this._ref);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('notifications');

  Stream<List<NotificationModel>> stream(String uid) {
    return retryOnPermissionDenied(() => _col.where('recipientUid', isEqualTo: uid).snapshots().map((s) {
          final list = s.docs.map((d) => NotificationModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list.length > displayLimit ? list.sublist(0, displayLimit) : list;
        }));
  }

  String get _senderName {
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    final auth = _ref.read(firebaseAuthProvider).currentUser;
    return profile?.displayName ?? auth?.displayName ?? 'Someone';
  }

  /// Sends one notification per recipient (never to yourself). Best effort.
  Future<void> send({
    required Iterable<String> recipients,
    required String type,
    required String message,
    String? groupId,
    String? groupName,
    String? expenseId,
    double amount = 0,
  }) async {
    final me = _uid;
    if (me == null) return;
    final targets = recipients.where((r) => r.isNotEmpty && r != me).toSet();
    if (targets.isEmpty) return;
    for (final chunk in chunked(targets.toList(), 400)) {
      final batch = _db.batch();
      for (final r in chunk) {
        final doc = _col.doc();
        batch.set(
          doc,
          NotificationModel(
            id: doc.id,
            recipientUid: r,
            senderUid: me,
            senderName: _senderName,
            type: type,
            message: message,
            createdAt: DateTime.now(),
            groupId: groupId,
            groupName: groupName,
            expenseId: expenseId,
            amount: amount,
          ).toMap(),
        );
      }
      await batch.commit();
    }
  }

  String get senderName => _senderName;

  Future<void> markRead(String id) => _col.doc(id).update({'isRead': true});

  Future<void> markAllRead(List<NotificationModel> items) async {
    final unread = items.where((n) => !n.isRead).map((n) => n.id).toList();
    for (final chunk in chunked(unread, 450)) {
      final batch = _db.batch();
      for (final id in chunk) {
        batch.update(_col.doc(id), {'isRead': true});
      }
      await batch.commit();
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  Future<void> clearAll(List<NotificationModel> items) async {
    for (final chunk in chunked(items.map((n) => n.id).toList(), 450)) {
      final batch = _db.batch();
      for (final id in chunk) {
        batch.delete(_col.doc(id));
      }
      await batch.commit();
    }
  }

  /// Housekeeping on launch: drop read notifications older than 30 days.
  Future<void> cleanupOld(String uid) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final snap = await _col.where('recipientUid', isEqualTo: uid).get();
    final stale = snap.docs
        .map((d) => NotificationModel.fromMap(d.data(), d.id))
        .where((n) => n.isRead && n.createdAt.isBefore(cutoff))
        .map((n) => n.id)
        .toList();
    for (final chunk in chunked(stale, 450)) {
      final batch = _db.batch();
      for (final id in chunk) {
        batch.delete(_col.doc(id));
      }
      await batch.commit();
    }
  }

  // ── Reminder cooldown (stored privately on the sender) ────────────────────

  DocumentReference<Map<String, dynamic>> _reminderDoc(String me, String groupId, String to) =>
      _db.collection('users').doc(me).collection('reminders').doc('${groupId}_$to');

  Stream<DateTime?> streamLastReminder(String me, String groupId, String to) {
    return _reminderDoc(me, groupId, to).snapshots().map((s) {
      final raw = s.data()?['sentAt'];
      return raw is Timestamp ? raw.toDate() : (s.exists ? DateTime.now() : null);
    });
  }

  static bool canRemind(DateTime? last, {DateTime? now}) =>
      last == null || (now ?? DateTime.now()).difference(last) >= reminderCooldown;

  Future<void> sendReminder({
    required String recipientUid,
    required String groupId,
    required String groupName,
    required double amount,
    required String message,
  }) async {
    final me = _uid;
    if (me == null) return;
    await _reminderDoc(me, groupId, recipientUid).set({'sentAt': FieldValue.serverTimestamp()});
    await send(
      recipients: [recipientUid],
      type: NotificationModel.paymentRequest,
      message: message,
      groupId: groupId,
      groupName: groupName,
      amount: amount,
    );
  }
}
