import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/domain/settlement.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../friends/data/friends_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group_expense_model.dart';
import '../../groups/domain/group_model.dart';
import 'auth_repository.dart';

/// How the user proves it's really them before the account is deleted.
enum ReauthMethod { password, google }

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  return AccountDeletionService(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(groupsRepositoryProvider),
    ref.watch(friendsRepositoryProvider),
    ref.watch(authRepositoryProvider),
  );
});

/// Deletes a user's account and personal data from the device (no Cloud
/// Functions on the free plan).
///
/// Deleted: profile, friend code, friendships, personal expenses / receipts /
/// reminders, private profile, own notifications, pending invites, sign-in.
/// Kept: shared group records (other members' balances depend on them); the
/// user shows up there as "Deleted user".
class AccountDeletionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GroupsRepository _groups;
  final FriendsRepository _friends;
  final AuthRepository _authRepo;

  AccountDeletionService(this._auth, this._db, this._groups, this._friends, this._authRepo);

  static const _server = GetOptions(source: Source.server);

  String get _me {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AppException('Please sign in again.');
    return uid;
  }

  /// Every way this account can confirm, the one used for the current
  /// sign-in first (an email account signed in with Google once has both).
  Future<List<ReauthMethod>> reauthMethods() async {
    final user = _auth.currentUser;
    if (user == null) return const [];
    final linked = user.providerData.map((p) => p.providerId).toSet();
    final methods = <ReauthMethod>[
      if (linked.contains('password')) ReauthMethod.password,
      if (linked.contains('google.com')) ReauthMethod.google,
    ];
    String? current;
    try {
      current = (await user.getIdTokenResult()).signInProvider;
    } catch (_) {}
    if (current == 'google.com' && methods.length > 1) return methods.reversed.toList();
    return methods;
  }

  /// Net per person across all groups, fresh from the server
  /// (positive = they owe me, negative = I owe them).
  Future<Map<String, double>> openBalances() async {
    final me = _me;
    final groups = await _db.collection('groups').where('members', arrayContains: me).get(_server);
    final paise = <String, int>{};
    for (final g in groups.docs) {
      if (g.data()['isDeleted'] == true) continue;
      final snap = await g.reference.collection('expenses').where('isDeleted', isEqualTo: false).get(_server);
      final list = snap.docs
          .map((d) => GroupExpenseModel.fromMap(d.data(), d.id))
          .where((e) => !e.isRecurringTemplate)
          .toList();
      Settlement.pairwiseFor(me, list).forEach((uid, v) {
        paise[uid] = (paise[uid] ?? 0) + Money.toPaise(v);
      });
    }
    return {
      for (final e in paise.entries)
        if (e.value != 0) e.key: Money.fromPaise(e.value),
    };
  }

  /// Firebase only deletes a sign-in that was confirmed recently, so this runs
  /// first: if it fails, nothing has been touched yet.
  Future<void> reauthenticate(ReauthMethod method, {String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('Please sign in again.');
    switch (method) {
      case ReauthMethod.password:
        final email = user.email;
        if (email == null) throw const AppException('Please sign in again.');
        if (password == null || password.isEmpty) throw const AppException('Enter your password to confirm.');
        await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: password));
      case ReauthMethod.google:
        final account = await GoogleSignIn().signIn();
        if (account == null) throw const AppException('Google confirmation was cancelled.');
        final tokens = await account.authentication;
        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(accessToken: tokens.accessToken, idToken: tokens.idToken),
        );
    }
  }

  /// Call right after [reauthenticate]. Refuses while the user still owes
  /// anyone, so nobody is left unpaid.
  Future<void> deleteAccount({void Function(String step)? onStep}) async {
    final me = _me;

    onStep?.call('Checking balances');
    final open = await openBalances();
    if (open.values.any((v) => v < 0)) {
      throw const AppException('Settle up what you owe before deleting your account.');
    }

    onStep?.call('Leaving your groups');
    final groups = await _db.collection('groups').where('members', arrayContains: me).get(_server);
    for (final doc in groups.docs) {
      var group = GroupModel.fromMap(doc.data(), doc.id);
      if (group.isDeleted) continue;
      final others = group.members.where((m) => m != me).toList();
      final otherAdmins = group.activeAdmins.where((a) => a != me);
      if (others.isNotEmpty && group.isAdmin(me) && otherAdmins.isEmpty) {
        // Hand the group over so it isn't left without an admin.
        await _groups.setAdmin(group, others.first, admin: true);
        final fresh = await doc.reference.get(_server);
        group = GroupModel.fromMap(fresh.data()!, fresh.id);
      }
      await _groups.leaveGroup(group);
    }

    onStep?.call('Removing friends');
    final edges = await _db.collection('friends').doc(me).collection('friendList').get(_server);
    for (final edge in edges.docs) {
      await _friends.remove(edge.id);
    }

    onStep?.call('Clearing invites and notifications');
    final received = await _db.collection('group_invites').where('recipientUid', isEqualTo: me).get(_server);
    for (final inv in received.docs) {
      if (inv.data()['status'] == 'pending') await inv.reference.update({'status': 'declined'});
    }
    await _deleteQuery(_db.collection('group_invites').where('senderUid', isEqualTo: me));
    await _deleteQuery(_db.collection('notifications').where('recipientUid', isEqualTo: me));

    onStep?.call('Deleting your data');
    final userDoc = _db.collection('users').doc(me);
    for (final sub in const ['expenses', 'receipts', 'reminders', 'private']) {
      await _deleteQuery(userDoc.collection(sub));
    }
    final code = (await userDoc.get(_server)).data()?['appCode'];
    if (code is String && code.isNotEmpty) {
      final codeDoc = _db.collection('app_codes').doc(code.toUpperCase());
      final owner = await codeDoc.get(_server);
      if (owner.exists && owner.data()?['uid'] == me) await codeDoc.delete();
    }
    await userDoc.delete();

    onStep?.call('Deleting your sign-in');
    await _auth.currentUser!.delete();
    try {
      await _authRepo.signOut();
    } catch (_) {}
  }

  Future<void> _deleteQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snap = await query.limit(400).get(_server);
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }
}
