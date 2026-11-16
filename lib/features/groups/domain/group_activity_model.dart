import '../../personal_expenses/domain/expense_model.dart' show readDate;

/// One line in a group's activity timeline.
class GroupActivityModel {
  static const String expenseAdded = 'expense_added';
  static const String expenseEdited = 'expense_edited';
  static const String expenseDeleted = 'expense_deleted';
  static const String settledUp = 'settled_up';
  static const String memberJoined = 'member_joined';
  static const String memberLeft = 'member_left';
  static const String memberRemoved = 'member_removed';
  static const String groupEdited = 'group_edited';

  final String activityId;
  final String type;
  final String actorUid;
  final String? expenseId;
  final String message;
  final DateTime createdAt;

  const GroupActivityModel({
    required this.activityId,
    required this.type,
    required this.actorUid,
    required this.message,
    required this.createdAt,
    this.expenseId,
  });

  factory GroupActivityModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupActivityModel(
      activityId: id,
      type: (map['type'] ?? '').toString(),
      actorUid: (map['actorUid'] ?? '').toString(),
      expenseId: map['expenseId'] as String?,
      message: (map['message'] ?? '').toString(),
      // Pending server timestamps read as null locally → treat as "now".
      createdAt: readDate(map['createdAt']) ?? DateTime.now(),
    );
  }
}
