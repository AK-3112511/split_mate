import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String name;
  final List<String> members; // UIDs of group members
  final List<String> admins; // UIDs of group admins
  final DateTime createdAt;
  final String createdBy; // UID of creator
  final String? inviteCode; // Unique 6-character group code
  final bool isDeleted;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.members,
    required this.admins,
    required this.createdAt,
    required this.createdBy,
    this.inviteCode,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'members': members,
      'admins': admins,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'inviteCode': inviteCode,
      'isDeleted': isDeleted,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDate = map['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final createdBy = map['createdBy'] ?? '';
    final rawAdmins = map['admins'];
    List<String> parsedAdmins = [];
    if (rawAdmins is List) {
      parsedAdmins = List<String>.from(rawAdmins);
    }
    if (parsedAdmins.isEmpty && createdBy.isNotEmpty) {
      parsedAdmins = [createdBy];
    }

    return GroupModel(
      groupId: id,
      name: map['name'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      admins: parsedAdmins,
      createdAt: parsedDate,
      createdBy: createdBy,
      inviteCode: map['inviteCode'],
      isDeleted: map['isDeleted'] == true,
    );
  }
}
