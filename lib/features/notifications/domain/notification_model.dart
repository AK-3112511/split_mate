import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String recipientUid;
  final String senderUid;
  final String senderName;
  final String groupId;
  final String groupName;
  final double amount;
  final String type; // 'payment_request'
  final String message;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.recipientUid,
    required this.senderUid,
    required this.senderName,
    required this.groupId,
    required this.groupName,
    required this.amount,
    required this.type,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    return NotificationModel(
      id: docId,
      recipientUid: map['recipientUid'] ?? '',
      senderUid: map['senderUid'] ?? '',
      senderName: map['senderName'] ?? 'Member',
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? 'Group',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] ?? 'payment_request',
      message: map['message'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] is String
              ? (DateTime.tryParse(map['createdAt']) ?? DateTime.now())
              : DateTime.now(),
      isRead: map['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientUid': recipientUid,
      'senderUid': senderUid,
      'senderName': senderName,
      'groupId': groupId,
      'groupName': groupName,
      'amount': amount,
      'type': type,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }
}
