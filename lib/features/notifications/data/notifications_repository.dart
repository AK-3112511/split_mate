import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/notification_model.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final userNotificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(notificationsRepositoryProvider).streamUserNotifications(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(userNotificationsStreamProvider);
  return notificationsAsync.when(
    data: (list) => list.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

final hasRecentPaymentRequestProvider = StreamProvider.family<bool, ({String recipientUid, String groupId})>((ref, arg) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return ref.watch(notificationsRepositoryProvider).streamHasRecentPaymentRequest(
        senderUid: user.uid,
        recipientUid: arg.recipientUid,
        groupId: arg.groupId,
      );
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

class NotificationsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  NotificationsRepository(this._firestore, this._auth);

  Stream<List<NotificationModel>> streamUserNotifications(String uid) {
    return retryOnPermissionDenied(() => _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => NotificationModel.fromMap(d.data(), d.id)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }));
  }

  Stream<bool> streamHasRecentPaymentRequest({
    required String senderUid,
    required String recipientUid,
    required String groupId,
  }) {
    return retryOnPermissionDenied(() => _firestore
        .collection('notifications')
        .where('senderUid', isEqualTo: senderUid)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          for (final doc in snap.docs) {
            final data = doc.data();
            if (data['recipientUid'] == recipientUid &&
                data['groupId'] == groupId &&
                data['type'] == 'payment_request') {
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : data['createdAt'] is String
                      ? DateTime.tryParse(data['createdAt'])
                      : null;
              if (createdAt != null) {
                final diff = now.difference(createdAt);
                if (diff.inHours < 24) {
                  return true;
                }
              }
            }
          }
          return false;
        }));
  }

  Future<void> sendPaymentRequest({
    required String recipientUid,
    required String groupId,
    required String groupName,
    required double amount,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');
    final senderUid = currentUser.uid;
    final senderName = currentUser.displayName ?? 'Member';

    final docRef = _firestore.collection('notifications').doc();
    final notification = NotificationModel(
      id: docRef.id,
      recipientUid: recipientUid,
      senderUid: senderUid,
      senderName: senderName,
      groupId: groupId,
      groupName: groupName,
      amount: amount,
      type: 'payment_request',
      message: '$senderName requested ₹${amount.toStringAsFixed(2)} payment clearance in "$groupName"',
      createdAt: DateTime.now(),
      isRead: false,
    );

    await docRef.set(notification.toMap());
  }

  Future<void> sendPaymentRecorded({
    required String recipientUid,
    required String groupId,
    required String groupName,
    required double amount,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final senderUid = currentUser.uid;
    final senderName = currentUser.displayName ?? 'Member';

    final docRef = _firestore.collection('notifications').doc();
    final notification = NotificationModel(
      id: docRef.id,
      recipientUid: recipientUid,
      senderUid: senderUid,
      senderName: senderName,
      groupId: groupId,
      groupName: groupName,
      amount: amount,
      type: 'payment_recorded',
      message: '$senderName recorded a payment clearance of ₹${amount.toStringAsFixed(2)} in "$groupName"',
      createdAt: DateTime.now(),
      isRead: false,
    );

    await docRef.set(notification.toMap());
  }

  Future<void> sendExpenseAdded({
    required List<String> recipientUids,
    required String groupId,
    required String groupName,
    required String description,
    required double amount,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final senderUid = currentUser.uid;
    final senderName = currentUser.displayName ?? 'Member';

    final batch = _firestore.batch();
    for (final rUid in recipientUids) {
      if (rUid == senderUid) continue; // Don't notify self
      final docRef = _firestore.collection('notifications').doc();
      final notification = NotificationModel(
        id: docRef.id,
        recipientUid: rUid,
        senderUid: senderUid,
        senderName: senderName,
        groupId: groupId,
        groupName: groupName,
        amount: amount,
        type: 'expense_added',
        message: '$senderName added "$description" (₹${amount.toStringAsFixed(2)}) in "$groupName"',
        createdAt: DateTime.now(),
        isRead: false,
      );
      batch.set(docRef, notification.toMap());
    }
    await batch.commit();
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String recipientUid) async {
    final snap = await _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: recipientUid)
        .get();

    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      if (doc.data()['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
