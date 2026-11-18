import 'package:cloud_firestore/cloud_firestore.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;

/// In-app notification. Only the recipient can read/update/delete it.
class NotificationModel {
  static const String paymentRequest = 'payment_request';
  static const String paymentRecorded = 'payment_recorded';
  static const String expenseAdded = 'expense_added';
  static const String expenseEdited = 'expense_edited';
  static const String expenseDeleted = 'expense_deleted';
  static const String expenseComment = 'expense_comment';
  static const String memberLeft = 'member_left';
  static const String memberRemoved = 'member_removed';
  static const String groupEdited = 'group_edited';
  static const String groupDeleted = 'group_deleted';
  static const String groupInvite = 'group_invite';
  static const String friendRequest = 'friend_request';
  static const String friendAccepted = 'friend_accepted';

  final String id;
  final String recipientUid;
  final String senderUid;
  final String senderName;
  final String type;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? groupId;
  final String? groupName;
  final String? expenseId;
  final double amount;

  const NotificationModel({
    required this.id,
    required this.recipientUid,
    required this.senderUid,
    required this.senderName,
    required this.type,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.groupId,
    this.groupName,
    this.expenseId,
    this.amount = 0,
  });

  bool get isGroupRelated => groupId != null && groupId!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'recipientUid': recipientUid,
        'senderUid': senderUid,
        'senderName': senderName,
        'type': type,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'groupId': groupId,
        'groupName': groupName,
        'expenseId': expenseId,
        'amount': amount,
      };

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    final a = map['amount'];
    final gid = (map['groupId'] ?? '').toString();
    return NotificationModel(
      id: id,
      recipientUid: (map['recipientUid'] ?? '').toString(),
      senderUid: (map['senderUid'] ?? '').toString(),
      senderName: (map['senderName'] ?? 'Someone').toString(),
      type: (map['type'] ?? '').toString(),
      message: (map['message'] ?? '').toString(),
      createdAt: readDate(map['createdAt']) ?? DateTime.now(),
      isRead: map['isRead'] == true,
      groupId: gid.isEmpty ? null : gid,
      groupName: map['groupName'] as String?,
      expenseId: map['expenseId'] as String?,
      amount: a is num ? a.toDouble() : 0.0,
    );
  }
}
