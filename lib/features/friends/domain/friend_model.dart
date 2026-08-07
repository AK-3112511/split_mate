import 'package:cloud_firestore/cloud_firestore.dart';

class FriendModel {
  final String uid;
  final String status; // 'pending' | 'accepted'
  final double balance; // positive: they owe you, negative: you owe them
  final DateTime addedAt;
  final String sentBy; // Who initiated the request

  FriendModel({
    required this.uid,
    required this.status,
    required this.balance,
    required this.addedAt,
    required this.sentBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'status': status,
      'balance': balance,
      'addedAt': Timestamp.fromDate(addedAt),
      'sentBy': sentBy,
    };
  }

  factory FriendModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawDate = map['addedAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    return FriendModel(
      uid: map['uid'] ?? docId,
      status: map['status'] ?? 'pending',
      balance: (map['balance'] ?? 0.0).toDouble(),
      addedAt: parsedDate,
      sentBy: map['sentBy'] ?? '',
    );
  }
}
