import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/firestore_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/friend_model.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final friendsStreamProvider = StreamProvider<List<FriendModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      final repository = ref.watch(friendsRepositoryProvider);
      return repository.streamFriends(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final friendDetailsProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return retryOnPermissionDenied(() => ref.watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data()));
});

final resolvedMemberNameProvider = Provider.family<String, String>((ref, uid) {
  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;

  // 1. Check custom nickname from friends stream
  final friendsList = ref.watch(friendsStreamProvider).valueOrNull ?? [];
  for (final f in friendsList) {
    if (f.uid == uid && f.nickname != null && f.nickname!.isNotEmpty) {
      return f.nickname!;
    }
  }

  // 2. If current logged-in user and no nickname override exists
  if (uid == currentUid) return 'You';

  // 3. Fall back to user's registered displayName
  final details = ref.watch(friendDetailsProvider(uid)).valueOrNull;
  return details?['displayName'] ?? 'Member';
});

class FriendsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FriendsRepository(this._firestore, this._auth);

  String? get _currentUid => _auth.currentUser?.uid;

  Stream<List<FriendModel>> streamFriends(String uid) {
    return retryOnPermissionDenied(() => _firestore
        .collection('friends')
        .doc(uid)
        .collection('friendList')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => FriendModel.fromMap(doc.data(), doc.id)).toList();
        }));
  }

  Future<void> addFriendByCode(String code) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) {
      throw Exception('App code must be exactly 6 characters');
    }

    // 1. Query for user with matching appCode
    final userQuery = await _firestore
        .collection('users')
        .where('appCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (userQuery.docs.isEmpty) {
      throw Exception('No user found with code $cleanCode');
    }

    final friendDoc = userQuery.docs.first;
    final friendUid = friendDoc.id;

    if (friendUid == myUid) {
      throw Exception('You cannot add yourself as a friend');
    }

    // 2. Check if already in my friend list
    final existingDoc = await _firestore
        .collection('friends')
        .doc(myUid)
        .collection('friendList')
        .doc(friendUid)
        .get();

    if (existingDoc.exists) {
      final status = existingDoc.data()?['status'] ?? 'pending';
      if (status == 'accepted') {
        throw Exception('User is already your friend');
      } else {
        throw Exception('A friend request is already pending');
      }
    }

    // 3. Batch write pending friend docs recursively
    final batch = _firestore.batch();
    final now = DateTime.now();

    final myFriendDocRef = _firestore
        .collection('friends')
        .doc(myUid)
        .collection('friendList')
        .doc(friendUid);

    final friendFriendDocRef = _firestore
        .collection('friends')
        .doc(friendUid)
        .collection('friendList')
        .doc(myUid);

    final requestModel = FriendModel(
      uid: friendUid,
      status: 'pending',
      balance: 0.0,
      addedAt: now,
      sentBy: myUid,
    );

    final reciprocalModel = FriendModel(
      uid: myUid,
      status: 'pending',
      balance: 0.0,
      addedAt: now,
      sentBy: myUid,
    );

    batch.set(myFriendDocRef, requestModel.toMap());
    batch.set(friendFriendDocRef, reciprocalModel.toMap());

    await batch.commit();
  }

  Future<void> acceptFriendRequest(String friendUid) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final batch = _firestore.batch();

    final myFriendDocRef = _firestore
        .collection('friends')
        .doc(myUid)
        .collection('friendList')
        .doc(friendUid);

    final friendFriendDocRef = _firestore
        .collection('friends')
        .doc(friendUid)
        .collection('friendList')
        .doc(myUid);

    batch.update(myFriendDocRef, {'status': 'accepted'});
    batch.update(friendFriendDocRef, {'status': 'accepted'});

    await batch.commit();
  }

  Future<void> declineFriendRequest(String friendUid) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final batch = _firestore.batch();

    final myFriendDocRef = _firestore
        .collection('friends')
        .doc(myUid)
        .collection('friendList')
        .doc(friendUid);

    final friendFriendDocRef = _firestore
        .collection('friends')
        .doc(friendUid)
        .collection('friendList')
        .doc(myUid);

    batch.delete(myFriendDocRef);
    batch.delete(friendFriendDocRef);

    await batch.commit();
  }

  Future<void> updateFriendNickname(String friendUid, String nickname) async {
    final myUid = _currentUid;
    if (myUid == null) throw Exception('User not authenticated');

    final cleanNickname = nickname.trim();
    final docRef = _firestore
        .collection('friends')
        .doc(myUid)
        .collection('friendList')
        .doc(friendUid);

    await docRef.update({
      'nickname': cleanNickname.isEmpty ? FieldValue.delete() : cleanNickname,
    });
  }
}
