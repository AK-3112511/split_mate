import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../../core/utils/write_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/domain/notification_model.dart';
import '../domain/group_activity_model.dart';
import '../domain/guest.dart';
import '../domain/group_invite_model.dart';
import '../domain/group_model.dart';

/// Groups I'm a member of (deleted groups hidden), newest first.
final groupsStreamProvider = StreamProvider<List<GroupModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(groupsRepositoryProvider).streamGroups(uid);
});

/// A single group, or null when it was deleted or I no longer have access.
final groupDetailsStreamProvider = StreamProvider.autoDispose.family<GroupModel?, String>((ref, groupId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(groupsRepositoryProvider).streamGroup(groupId, uid);
});

final incomingGroupInvitesProvider = StreamProvider<List<GroupInviteModel>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(groupsRepositoryProvider).streamIncomingInvites(uid);
});

final groupPendingInvitesProvider =
    StreamProvider.autoDispose.family<List<GroupInviteModel>, String>((ref, groupId) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(groupsRepositoryProvider).streamPendingInvites(groupId);
});

class JoinResult {
  final String groupId;
  final String groupName;
  final bool alreadyMember;
  const JoinResult(this.groupId, this.groupName, {this.alreadyMember = false});
}

class GroupCodeInfo {
  final String groupId;
  final String groupName;
  final String code;
  const GroupCodeInfo(this.groupId, this.groupName, this.code);
}

/// Names of guests (people not on SplitMate yet) across all my groups.
final guestNamesProvider = Provider<Map<String, String>>((ref) {
  final groups = ref.watch(groupsStreamProvider).valueOrNull ?? const [];
  return {
    for (final g in groups)
      for (final e in g.guests.entries) e.key: e.value.name,
  };
});

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
    ref.watch(notificationsRepositoryProvider),
  );
});

class GroupsRepository {
  final FirebaseFirestore _db;
  final String? _uid;
  final NotificationsRepository _notify;

  GroupsRepository(this._db, this._uid, this._notify);

  String get _me {
    final uid = _uid;
    if (uid == null) throw const AppException('Please sign in again.');
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _group(String id) => _db.collection('groups').doc(id);
  DocumentReference<Map<String, dynamic>> _code(String code) => _db.collection('group_codes').doc(code);
  CollectionReference<Map<String, dynamic>> get _invites => _db.collection('group_invites');

  String get _myName => _notify.senderName;

  void _activity(WriteBatch batch, String groupId, String type, String message, {String? expenseId}) {
    batch.set(_group(groupId).collection('activity').doc(), {
      'type': type,
      'actorUid': _me,
      'expenseId': expenseId,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<GroupModel>> streamGroups(String uid) {
    return retryOnPermissionDenied(() => _db
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => GroupModel.fromMap(d.data(), d.id))
              .where((g) => !g.isDeleted)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }));
  }

  Stream<GroupModel?> streamGroup(String groupId, String uid) async* {
    try {
      yield* retryOnPermissionDenied(() => _group(groupId).snapshots().map((s) {
            final data = s.data();
            if (data == null) return null;
            final g = GroupModel.fromMap(data, s.id);
            if (g.isDeleted || !g.isMember(uid)) return null;
            return g;
          }));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        yield null; // removed from the group
      } else {
        rethrow;
      }
    }
  }

  Stream<List<GroupInviteModel>> streamIncomingInvites(String uid) {
    return retryOnPermissionDenied(() => _invites
        .where('recipientUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) {
          final byGroup = <String, GroupInviteModel>{};
          for (final d in s.docs) {
            final inv = GroupInviteModel.fromMap(d.data(), d.id);
            final existing = byGroup[inv.groupId];
            if (existing == null || inv.createdAt.isAfter(existing.createdAt)) byGroup[inv.groupId] = inv;
          }
          final list = byGroup.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }));
  }

  Stream<List<GroupInviteModel>> streamPendingInvites(String groupId) {
    return retryOnPermissionDenied(() => _invites
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map((d) => GroupInviteModel.fromMap(d.data(), d.id)).toList()));
  }

  // ── Codes ─────────────────────────────────────────────────────────────────

  Future<String> _freeCode() async {
    for (var i = 0; i < 6; i++) {
      final code = AuthRepository.generateCode();
      final snap = await _code(code).get();
      if (!snap.exists) return code;
    }
    throw const AppException('Couldn\'t generate a group code. Please try again.');
  }

  static String normalizeCode(String code) => code.trim().toUpperCase().replaceAll(' ', '');

  /// Resolves a join code to the group it belongs to (for the Join preview).
  Future<GroupCodeInfo> lookupCode(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.length != 6) throw const AppException('Group codes are 6 characters.');
    final snap = await _code(code).get();
    final data = snap.data();
    if (data == null || data['groupId'] == null) {
      throw const AppException('That code doesn\'t match any group. Check it with your friend?');
    }
    return GroupCodeInfo(data['groupId'] as String, (data['groupName'] ?? 'Group').toString(), code);
  }

  /// Makes sure the group has a code registered in `group_codes` (v1 groups
  /// predate the registry). Safe to call repeatedly from any member's device.
  Future<void> ensureCodeRegistered(GroupModel group) async {
    try {
      var code = group.inviteCode;
      if (code == null || code.isEmpty) {
        final fresh = await _freeCode();
        await _db.runTransaction((tx) async {
          final snap = await tx.get(_group(group.groupId));
          if ((snap.data()?['inviteCode'] as String?)?.isNotEmpty == true) return;
          tx.update(_group(group.groupId), {'inviteCode': fresh});
          tx.set(_code(fresh), {'groupId': group.groupId, 'groupName': group.name});
        });
        return;
      }
      final reg = await _code(code).get();
      if (!reg.exists) {
        await _code(code).set({'groupId': group.groupId, 'groupName': group.name});
      }
    } catch (_) {
      // Best effort; joining by this code will simply report it as invalid.
    }
  }

  // ── Create / join ─────────────────────────────────────────────────────────

  Future<String> createGroup(String name, List<String> inviteUids) async {
    final me = _me;
    final clean = name.trim();
    if (clean.isEmpty) throw const AppException('Give your group a name.');
    if (clean.length > 40) throw const AppException('Keep the name under 40 characters.');

    final code = await _freeCode();
    final doc = _db.collection('groups').doc();
    final batch = _db.batch();
    batch.set(doc, {
      ...GroupModel(
        groupId: doc.id,
        name: clean,
        members: [me],
        admins: [me],
        createdAt: DateTime.now(),
        createdBy: me,
        inviteCode: code,
      ).toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_code(code), {'groupId': doc.id, 'groupName': clean});
    final invited = inviteUids.where((u) => u != me).toSet();
    for (final uid in invited) {
      _stageInvite(batch, doc.id, clean, uid);
    }
    _activity(batch, doc.id, GroupActivityModel.memberJoined, '$_myName created the group');
    await commitWithTimeout(batch.commit());
    if (invited.isNotEmpty) {
      runInBackground(() => _notify.send(
            recipients: invited,
            type: NotificationModel.groupInvite,
            message: '$_myName invited you to "$clean"',
            groupId: doc.id,
            groupName: clean,
          ), label: 'invite notify');
    }
    return doc.id;
  }

  void _stageInvite(WriteBatch batch, String groupId, String groupName, String recipient) {
    final doc = _invites.doc();
    batch.set(doc, GroupInviteModel(
      inviteId: doc.id,
      groupId: groupId,
      groupName: groupName,
      senderUid: _me,
      senderName: _myName,
      recipientUid: recipient,
      status: 'pending',
      createdAt: DateTime.now(),
    ).toMap());
  }

  Future<void> sendInvites(GroupModel group, List<String> uids) async {
    final pending = await _invites
        .where('groupId', isEqualTo: group.groupId)
        .where('status', isEqualTo: 'pending')
        .get();
    final alreadyInvited = pending.docs.map((d) => d.data()['recipientUid']).toSet();
    final targets = uids
        .where((u) => !group.members.contains(u) && !alreadyInvited.contains(u))
        .toSet();
    if (targets.isEmpty) throw const AppException('They\'re already in the group or invited.');
    final batch = _db.batch();
    for (final uid in targets) {
      _stageInvite(batch, group.groupId, group.name, uid);
    }
    await commitWithTimeout(batch.commit());
    runInBackground(() => _notify.send(
          recipients: targets,
          type: NotificationModel.groupInvite,
          message: '$_myName invited you to "${group.name}"',
          groupId: group.groupId,
          groupName: group.name,
        ), label: 'invite notify');
  }

  Future<void> cancelInvite(String inviteId) => commitWithTimeout(_invites.doc(inviteId).delete());

  Future<void> declineInvite(String inviteId) =>
      commitWithTimeout(_invites.doc(inviteId).update({'status': 'declined'}));

  Future<void> acceptInvite(GroupInviteModel invite) async {
    final me = _me;
    final batch = _db.batch();
    batch.update(_group(invite.groupId), {
      'members': FieldValue.arrayUnion([me]),
      'joinInviteId': invite.inviteId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_invites.doc(invite.inviteId), {'status': 'accepted'});
    _activity(batch, invite.groupId, GroupActivityModel.memberJoined, '$_myName joined the group');
    try {
      await batch.commit().timeout(const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        await _invites.doc(invite.inviteId).update({'status': 'declined'}).catchError((_) {});
        throw const AppException('This group no longer exists.');
      }
      rethrow;
    }
    runInBackground(() => _closeOtherInvites(invite.groupId), label: 'close invites');
  }

  Future<void> _closeOtherInvites(String groupId) async {
    final snap = await _invites
        .where('recipientUid', isEqualTo: _me)
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'status': 'accepted'});
    }
    await batch.commit();
  }

  /// Fresh copy of a group from the server (null if gone or not visible).
  Future<GroupModel?> fetchGroup(String groupId) async {
    final snap = await _group(groupId).get(const GetOptions(source: Source.server));
    final data = snap.data();
    return data == null ? null : GroupModel.fromMap(data, snap.id);
  }

  Future<JoinResult> joinByCode(String rawCode) async {
    final me = _me;
    final info = await lookupCode(rawCode);

    // Already a member? (Members can read the group; others get denied.)
    try {
      final snap = await _group(info.groupId).get();
      final g = snap.data() == null ? null : GroupModel.fromMap(snap.data()!, snap.id);
      if (g != null && g.isMember(me) && !g.isDeleted) {
        return JoinResult(info.groupId, g.name, alreadyMember: true);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }

    final batch = _db.batch();
    batch.update(_group(info.groupId), {
      'members': FieldValue.arrayUnion([me]),
      'joinCode': info.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity(batch, info.groupId, GroupActivityModel.memberJoined, '$_myName joined with the group code');
    try {
      await batch.commit().timeout(const Duration(seconds: 10));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        throw const AppException('That code is no longer valid. Ask for a new one.');
      }
      rethrow;
    }
    runInBackground(() => _closeOtherInvites(info.groupId), label: 'close invites');
    return JoinResult(info.groupId, info.groupName);
  }

  // ── Membership ────────────────────────────────────────────────────────────

  void _requireAdmin(GroupModel g) {
    if (!g.isAdmin(_me)) throw const AppException('Only group admins can do that.');
  }

  Future<void> removeMember(GroupModel group, String uid, String name) async {
    _requireAdmin(group);
    if (uid == _me) throw const AppException('Use "Leave group" to remove yourself.');
    final batch = _db.batch();
    batch.update(_group(group.groupId), {
      'members': FieldValue.arrayRemove([uid]),
      'admins': FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity(batch, group.groupId, GroupActivityModel.memberRemoved, '$_myName removed $name');
    await commitWithTimeout(batch.commit());
    runInBackground(() async {
      await _notify.send(
        recipients: [uid],
        type: NotificationModel.memberRemoved,
        message: '$_myName removed you from "${group.name}"',
        groupId: group.groupId,
        groupName: group.name,
      );
      await _notify.send(
        recipients: group.members.where((m) => m != uid),
        type: NotificationModel.memberRemoved,
        message: '$_myName removed $name from "${group.name}"',
        groupId: group.groupId,
        groupName: group.name,
      );
    }, label: 'remove notify');
  }

  // ── Guests (people not on SplitMate yet) ─────────────────────────────────

  /// Adds someone who isn't on SplitMate yet; returns their guest id.
  Future<String> addGuest(GroupModel group, String name) async {
    final me = _me;
    final clean = name.trim();
    if (clean.isEmpty) throw const AppException('Enter their name.');
    if (clean.length > 40) throw const AppException('Keep the name under 40 characters.');
    final id = newGuestId();
    final batch = _db.batch();
    batch.update(_group(group.groupId), {
      'guests.$id': {'name': clean, 'addedBy': me, 'createdAt': FieldValue.serverTimestamp()},
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity(batch, group.groupId, GroupActivityModel.memberJoined, '$_myName added $clean (not on SplitMate yet)');
    await commitWithTimeout(batch.commit());
    return id;
  }

  /// Removes a guest who isn't part of any expense.
  Future<void> removeGuest(GroupModel group, String guestId) async {
    final guest = group.guests[guestId];
    if (guest == null) return;
    final batch = _db.batch();
    batch.update(_group(group.groupId), {
      'guests.$guestId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activity(batch, group.groupId, GroupActivityModel.memberRemoved, '$_myName removed ${guest.name}');
    await commitWithTimeout(batch.commit());
  }

  Future<void> leaveGroup(GroupModel group) async {
    final me = _me;
    final others = group.members.where((m) => m != me).toList();
    final otherAdmins = group.activeAdmins.where((a) => a != me).toList();
    if (group.isAdmin(me) && others.isNotEmpty && otherAdmins.isEmpty) {
      throw const AppException('Make someone else an admin before you leave.');
    }
    final batch = _db.batch();
    _activity(batch, group.groupId, GroupActivityModel.memberLeft, '$_myName left the group');
    batch.update(_group(group.groupId), {
      'members': FieldValue.arrayRemove([me]),
      'admins': FieldValue.arrayRemove([me]),
      if (others.isEmpty) 'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (others.isEmpty && group.inviteCode != null) batch.delete(_code(group.inviteCode!));
    await commitWithTimeout(batch.commit());
    runInBackground(() => _notify.send(
          recipients: others,
          type: NotificationModel.memberLeft,
          message: '$_myName left "${group.name}"',
          groupId: group.groupId,
          groupName: group.name,
        ), label: 'leave notify');
  }

  Future<void> setAdmin(GroupModel group, String uid, {required bool admin}) async {
    _requireAdmin(group);
    if (!admin && group.activeAdmins.where((a) => a != uid).isEmpty) {
      throw const AppException('A group needs at least one admin.');
    }
    await commitWithTimeout(_group(group.groupId).update({
      'admins': admin ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> rename(GroupModel group, String name) async {
    _requireAdmin(group);
    final clean = name.trim();
    if (clean.isEmpty) throw const AppException('Give your group a name.');
    if (clean.length > 40) throw const AppException('Keep the name under 40 characters.');
    if (clean == group.name) return;
    final batch = _db.batch();
    batch.update(_group(group.groupId), {'name': clean, 'updatedAt': FieldValue.serverTimestamp()});
    if (group.inviteCode != null) {
      batch.set(_code(group.inviteCode!), {'groupId': group.groupId, 'groupName': clean});
    }
    _activity(batch, group.groupId, GroupActivityModel.groupEdited,
        '$_myName renamed the group "${group.name}" → "$clean"');
    await commitWithTimeout(batch.commit());
    runInBackground(() => _notify.send(
          recipients: group.members,
          type: NotificationModel.groupEdited,
          message: '$_myName renamed "${group.name}" to "$clean"',
          groupId: group.groupId,
          groupName: clean,
        ), label: 'rename notify');
  }

  /// Issues a new join code; the old one stops working immediately.
  Future<String> rotateCode(GroupModel group) async {
    _requireAdmin(group);
    final fresh = await _freeCode();
    final batch = _db.batch();
    if (group.inviteCode != null) batch.delete(_code(group.inviteCode!));
    batch.set(_code(fresh), {'groupId': group.groupId, 'groupName': group.name});
    batch.update(_group(group.groupId), {'inviteCode': fresh, 'updatedAt': FieldValue.serverTimestamp()});
    await commitWithTimeout(batch.commit());
    return fresh;
  }

  /// Soft-deletes the group (financial records are never hard-deleted).
  Future<void> deleteGroup(GroupModel group) async {
    _requireAdmin(group);
    final batch = _db.batch();
    batch.update(_group(group.groupId), {'isDeleted': true, 'updatedAt': FieldValue.serverTimestamp()});
    if (group.inviteCode != null) batch.delete(_code(group.inviteCode!));
    await batch.commit().timeout(const Duration(seconds: 10));
    // Only notify once the delete really happened.
    runInBackground(() async {
      final pending = await _invites
          .where('groupId', isEqualTo: group.groupId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (pending.docs.isNotEmpty) {
        final b = _db.batch();
        for (final d in pending.docs) {
          b.update(d.reference, {'status': 'declined'});
        }
        await b.commit();
      }
      await _notify.send(
        recipients: group.members,
        type: NotificationModel.groupDeleted,
        message: '$_myName deleted the group "${group.name}"',
        groupId: group.groupId,
        groupName: group.name,
      );
    }, label: 'delete group cleanup');
  }
}
