import 'package:cloud_firestore/cloud_firestore.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;
import 'guest.dart';

class GroupModel {
  final String groupId;
  final String name;
  final List<String> members;
  final List<String> admins;
  final DateTime createdAt;
  final String createdBy;
  final String? inviteCode;
  final bool isDeleted;

  /// People who aren't on SplitMate yet, by guest id.
  final Map<String, GuestMember> guests;

  const GroupModel({
    required this.groupId,
    required this.name,
    required this.members,
    required this.admins,
    required this.createdAt,
    required this.createdBy,
    this.inviteCode,
    this.isDeleted = false,
    this.guests = const {},
  });

  bool isAdmin(String uid) => admins.contains(uid);
  bool isMember(String uid) => members.contains(uid);

  /// Everyone who can pay or share in an expense: members, then guests.
  List<String> get participants => [...members, ...guests.keys];

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
      guests: {
        if (map['guests'] is Map)
          for (final e in (map['guests'] as Map).entries)
            if (e.value is Map) e.key.toString(): GuestMember.fromMap(e.key.toString(), Map<String, dynamic>.from(e.value as Map)),
      },
    );
  }
}
