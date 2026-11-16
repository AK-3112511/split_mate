import 'package:cloud_firestore/cloud_firestore.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;

class GroupModel {
  final String groupId;
  final String name;
  final List<String> members;
  final List<String> admins;
  final DateTime createdAt;
  final String createdBy;
  final String? inviteCode;
  final bool isDeleted;

  const GroupModel({
    required this.groupId,
    required this.name,
    required this.members,
    required this.admins,
    required this.createdAt,
    required this.createdBy,
    this.inviteCode,
    this.isDeleted = false,
  });

  bool isAdmin(String uid) => admins.contains(uid);
  bool isMember(String uid) => members.contains(uid);

  /// Admins that are still members (v1 could leave stale admin uids).
  List<String> get activeAdmins => admins.where(members.contains).toList();

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'name': name,
        'members': members,
        'admins': admins,
        'createdAt': Timestamp.fromDate(createdAt),
        'createdBy': createdBy,
        'inviteCode': inviteCode,
        'isDeleted': isDeleted,
      };

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    final createdBy = (map['createdBy'] ?? '').toString();
    final members = List<String>.from((map['members'] ?? const []).map((e) => e.toString()));
    var admins = map['admins'] is List
        ? List<String>.from((map['admins'] as List).map((e) => e.toString()))
        : <String>[];
    if (admins.isEmpty && createdBy.isNotEmpty) admins = [createdBy];
    return GroupModel(
      groupId: id,
      name: (map['name'] ?? map['groupName'] ?? 'Group').toString(),
      members: members,
      admins: admins,
      createdAt: readDate(map['createdAt']) ?? DateTime.now(),
      createdBy: createdBy,
      inviteCode: (map['inviteCode'] as String?)?.toUpperCase(),
      isDeleted: map['isDeleted'] == true,
    );
  }
}
