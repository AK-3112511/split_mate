import '../domain/friend_model.dart';

class FriendRepository {
  Future<void> sendFriendRequest(String targetUid) async {
    // TODO: Implement Firestore write for friend request
  }

  Future<void> acceptFriendRequest(String targetUid) async {
    // TODO: Implement Firestore write for accepting request
  }

  Stream<List<FriendModel>> streamFriends() {
    // TODO: Stream friends list from Firestore
    return const Stream.empty();
  }
}
