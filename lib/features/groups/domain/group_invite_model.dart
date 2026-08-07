import 'package:cloud_firestore/cloud_firestore.dart';

class GroupInviteModel {
  final String inviteId;
  final String groupId;
  final String groupName;
  final String senderUid;
  final String senderName;
  final String recipientUid;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;

  GroupInviteModel({
    required this.inviteId,
    required this.groupId,
    required this.groupName,
    required this.senderUid,
    required this.senderName,
    required this.recipientUid,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'inviteId': inviteId,
      'groupId': groupId,
      'groupName': groupName,
      'senderUid': senderUid,
      'senderName': senderName,
      'recipientUid': recipientUid,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GroupInviteModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDate = map['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return GroupInviteModel(
      inviteId: id,
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      senderUid: map['senderUid'] ?? '',
      senderName: map['senderName'] ?? '',
      recipientUid: map['recipientUid'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: parsedDate,
    );
  }
}
