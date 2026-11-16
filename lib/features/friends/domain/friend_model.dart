import 'package:cloud_firestore/cloud_firestore.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;

/// Edge in friends/{me}/friendList/{them}. Both directions are written together.
class FriendModel {
  static const String pending = 'pending';
  static const String accepted = 'accepted';

  final String uid;
  final String status;
  final DateTime addedAt;

  /// Who sent the request.
  final String sentBy;

  /// My private nickname for this friend (stored on *my* edge only).
  final String? nickname;

  const FriendModel({
    required this.uid,
    required this.status,
    required this.addedAt,
    required this.sentBy,
    this.nickname,
  });

  bool get isAccepted => status == accepted;
  bool get isPending => status == pending;
  bool isIncomingFor(String me) => isPending && sentBy != me;
  bool isOutgoingFor(String me) => isPending && sentBy == me;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'status': status,
        'addedAt': Timestamp.fromDate(addedAt),
        'sentBy': sentBy,
      };

  factory FriendModel.fromMap(Map<String, dynamic> map, String docId) {
    final nick = (map['nickname'] as String?)?.trim();
    return FriendModel(
      uid: (map['uid'] ?? docId).toString(),
      status: (map['status'] ?? pending).toString(),
      addedAt: readDate(map['addedAt']) ?? DateTime.now(),
      sentBy: (map['sentBy'] ?? '').toString(),
      nickname: (nick == null || nick.isEmpty) ? null : nick,
    );
  }
}
