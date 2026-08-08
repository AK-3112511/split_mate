import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/group_model.dart';
import '../domain/group_invite_model.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final groupsStreamProvider = StreamProvider<List<GroupModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(groupsRepositoryProvider);
      return repository.streamGroups(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final groupDetailsStreamProvider = StreamProvider.family<GroupModel?, String>((ref, groupId) {
  final repository = ref.watch(groupsRepositoryProvider);
  return repository.streamGroupDetails(groupId);
});

final incomingGroupInvitesProvider = StreamProvider<List<GroupInviteModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(groupsRepositoryProvider);
      return repository.streamIncomingGroupInvites(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final groupSentInvitesProvider = StreamProvider.family<List<GroupInviteModel>, String>((ref, groupId) {
  final repository = ref.watch(groupsRepositoryProvider);
  return repository.streamGroupSentInvites(groupId);
});

class GroupsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  GroupsRepository(this._firestore, this._auth);

  String? get _currentUid => _auth.currentUser?.uid;

  Stream<List<GroupModel>> streamGroups(String uid) {
    return retryOnPermissionDenied(() => _firestore
        .collection('groups')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
              .where((g) => !g.isDeleted)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }));
  }

  Stream<GroupModel?> streamGroupDetails(String groupId) {
    return retryOnPermissionDenied(() => _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          if (data == null || data['isDeleted'] == true) return null;
          final group = GroupModel.fromMap(data, snapshot.id);
          
          if (data['inviteCode'] == null) {
            _backfillInviteCode(groupId);
          }
          return group;
        }));
  }

  Stream<List<GroupInviteModel>> streamIncomingGroupInvites(String uid) {
    return retryOnPermissionDenied(() => _firestore
        .collection('group_invites')
        .where('recipientUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => GroupInviteModel.fromMap(doc.data(), doc.id)).toList();
          final Map<String, GroupInviteModel> uniqueMap = {};
          for (final invite in list) {
            if (!uniqueMap.containsKey(invite.groupId)) {
              uniqueMap[invite.groupId] = invite;
            }
          }
          final uniqueList = uniqueMap.values.toList();
          uniqueList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return uniqueList;
        }));
  }

  Stream<List<GroupInviteModel>> streamGroupSentInvites(String groupId) {
    return retryOnPermissionDenied(() => _firestore
        .collection('group_invites')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => GroupInviteModel.fromMap(doc.data(), doc.id)).toList();
        }));
  }

  Future<void> _backfillInviteCode(String groupId) async {
    try {
      final code = _generateInviteCode();
      await _firestore.collection('groups').doc(groupId).update({'inviteCode': code});
    } catch (_) {}
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<String> _getActorName(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      return userDoc.data()?['displayName'] ?? _auth.currentUser?.displayName ?? 'Someone';
    } catch (_) {
      return _auth.currentUser?.displayName ?? 'Someone';
    }
  }

  Future<void> createGroup(String name, List<String> selectedFriendUids) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final cleanName = name.trim();
    if (cleanName.isEmpty) throw Exception('Group name cannot be empty');

    final groupId = const Uuid().v4();
    final inviteCode = _generateInviteCode();
    final senderName = await _getActorName(myUid);

    final group = GroupModel(
      groupId: groupId,
      name: cleanName,
      members: [myUid], // Creator is the initial member
      admins: [myUid], // Creator is the initial Group Admin
      createdAt: DateTime.now(),
      createdBy: myUid,
      inviteCode: inviteCode,
    );

    // Save group doc
    await _firestore.collection('groups').doc(groupId).set(group.toMap());

    // Send group invites to selected existing friends (prevent duplicates)
    for (final friendUid in selectedFriendUids) {
      if (friendUid == myUid) continue;

      final existingQuery = await _firestore
          .collection('group_invites')
          .where('groupId', isEqualTo: groupId)
          .where('recipientUid', isEqualTo: friendUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingQuery.docs.isNotEmpty) continue;

      final inviteId = const Uuid().v4();
      final invite = GroupInviteModel(
        inviteId: inviteId,
        groupId: groupId,
        groupName: cleanName,
        senderUid: myUid,
        senderName: senderName,
        recipientUid: friendUid,
        status: 'pending',
        createdAt: DateTime.now(),
      );
      await _firestore.collection('group_invites').doc(inviteId).set(invite.toMap());
    }
  }

  Future<void> sendGroupInvite(String groupId, String friendUid) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    final groupData = groupDoc.data();
    final members = List<String>.from(groupData?['members'] ?? []);
    if (members.contains(friendUid)) {
      throw Exception('This friend is already a member of the group');
    }

    final existingQuery = await _firestore
        .collection('group_invites')
        .where('groupId', isEqualTo: groupId)
        .where('recipientUid', isEqualTo: friendUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw Exception('Group invitation already sent to this friend');
    }

    final groupName = groupData?['name'] ?? groupData?['groupName'] ?? 'Group';
    final senderName = await _getActorName(myUid);

    final inviteId = const Uuid().v4();
    final invite = GroupInviteModel(
      inviteId: inviteId,
      groupId: groupId,
      groupName: groupName,
      senderUid: myUid,
      senderName: senderName,
      recipientUid: friendUid,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    await _firestore.collection('group_invites').doc(inviteId).set(invite.toMap());
  }

  Future<void> acceptGroupInvite(String inviteId, String groupId) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final groupDoc = _firestore.collection('groups').doc(groupId);
    final inviteDoc = _firestore.collection('group_invites').doc(inviteId);
    final userName = await _getActorName(myUid);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(groupDoc);
      if (!snap.exists) throw Exception('Group no longer exists');
      final data = snap.data() as Map<String, dynamic>?;

      final members = List<String>.from(data?['members'] ?? []);
      if (!members.contains(myUid)) {
        members.add(myUid);
        transaction.update(groupDoc, {'members': members});
      }
      transaction.update(inviteDoc, {'status': 'accepted'});
    });

    try {
      await _firestore.collection('groups').doc(groupId).collection('activity').add({
        'type': 'member_joined',
        'actorUid': myUid,
        'message': '$userName accepted group invitation',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> declineGroupInvite(String inviteId) async {
    await _firestore.collection('group_invites').doc(inviteId).update({'status': 'declined'});
  }

  Future<void> removeMemberFromGroup(String groupId, String memberUid) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final groupDoc = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(groupDoc);
      if (!snap.exists) throw Exception('Group not found');
      final data = snap.data() as Map<String, dynamic>?;

      final createdBy = data?['createdBy'] ?? '';
      final rawAdmins = data?['admins'];
      List<String> admins = [];
      if (rawAdmins is List) {
        admins = List<String>.from(rawAdmins);
      }
      if (admins.isEmpty && createdBy.isNotEmpty) {
        admins = [createdBy];
      }

      if (!admins.contains(myUid) && createdBy != myUid) {
        throw Exception('Only group admins can remove members');
      }

      final members = List<String>.from(data?['members'] ?? []);
      members.remove(memberUid);
      admins.remove(memberUid);

      transaction.update(groupDoc, {
        'members': members,
        'admins': admins,
      });
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final groupDoc = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(groupDoc);
      if (!snap.exists) throw Exception('Group not found');
      final data = snap.data() as Map<String, dynamic>?;

      final members = List<String>.from(data?['members'] ?? []);
      final admins = List<String>.from(data?['admins'] ?? []);

      members.remove(myUid);
      admins.remove(myUid);

      final isDeleted = members.isEmpty;

      transaction.update(groupDoc, {
        'members': members,
        'admins': admins,
        if (isDeleted) 'isDeleted': true,
      });
    });
  }

  Future<void> makeMemberAdmin(String groupId, String memberUid) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final groupDoc = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(groupDoc);
      if (!snap.exists) throw Exception('Group not found');
      final data = snap.data() as Map<String, dynamic>?;

      final createdBy = data?['createdBy'] ?? '';
      final rawAdmins = data?['admins'];
      List<String> admins = [];
      if (rawAdmins is List) {
        admins = List<String>.from(rawAdmins);
      }
      if (admins.isEmpty && createdBy.isNotEmpty) {
        admins = [createdBy];
      }

      if (!admins.contains(myUid) && createdBy != myUid) {
        throw Exception('Only group admins can make admins');
      }

      if (!admins.contains(memberUid)) {
        admins.add(memberUid);
        transaction.update(groupDoc, {'admins': admins});
      }
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final groupDoc = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(groupDoc);
      if (!snap.exists) throw Exception('Group not found');
      final data = snap.data() as Map<String, dynamic>?;

      final createdBy = data?['createdBy'] ?? '';
      final rawAdmins = data?['admins'];
      List<String> admins = [];
      if (rawAdmins is List) {
        admins = List<String>.from(rawAdmins);
      }
      if (admins.isEmpty && createdBy.isNotEmpty) {
        admins = [createdBy];
      }

      if (!admins.contains(myUid) && createdBy != myUid) {
        throw Exception('Only group admins can delete the group');
      }

      transaction.update(groupDoc, {'isDeleted': true});
    });
  }

  Future<void> updateGroupName(String groupId, String newName) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final cleanName = newName.trim();
    if (cleanName.isEmpty) throw Exception('Group name cannot be empty');

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    final data = groupDoc.data();
    final createdBy = data?['createdBy'] ?? '';
    final rawAdmins = data?['admins'];
    List<String> admins = [];
    if (rawAdmins is List) {
      admins = List<String>.from(rawAdmins);
    }
    if (admins.isEmpty && createdBy.isNotEmpty) {
      admins = [createdBy];
    }

    if (!admins.contains(myUid) && createdBy != myUid) {
      throw Exception('Only group admins can edit the group name');
    }

    await _firestore.collection('groups').doc(groupId).update({'name': cleanName});
  }

  Future<void> joinGroupWithCode(String groupId, String code) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final cleanCode = code.trim().toUpperCase();

    // Query group by code if groupId not exact
    DocumentReference groupDoc;
    if (groupId.isNotEmpty && groupId != 'CODE_JOIN') {
      groupDoc = _firestore.collection('groups').doc(groupId);
    } else {
      final query = await _firestore.collection('groups').where('inviteCode', isEqualTo: cleanCode).get();
      if (query.docs.isEmpty) throw Exception('Invalid group invitation code');
      groupDoc = query.docs.first.reference;
    }

    final userName = await _getActorName(myUid);

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(groupDoc);
      if (!snap.exists) throw Exception('Group not found');
      final data = snap.data() as Map<String, dynamic>?;
      
      final inviteCode = data?['inviteCode'];
      if (inviteCode == null || inviteCode != cleanCode) {
        throw Exception('Invalid group invitation code');
      }

      final members = List<String>.from(data?['members'] ?? []);
      if (!members.contains(myUid)) {
        members.add(myUid);
        transaction.update(groupDoc, {'members': members});
      }
    });

    try {
      await groupDoc.collection('activity').add({
        'type': 'member_joined',
        'actorUid': myUid,
        'message': '$userName joined the group via group code',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
