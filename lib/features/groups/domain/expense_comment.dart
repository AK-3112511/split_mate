import 'package:cloud_firestore/cloud_firestore.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;

/// A comment on a group expense ("includes tip"). Stored under
/// groups/{gid}/expenses/{eid}/comments; only its author can delete it.
class ExpenseComment {
  static const int maxLength = 500;

  final String id;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime createdAt;

  const ExpenseComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'authorUid': authorUid,
    'authorName': authorName,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory ExpenseComment.fromMap(Map<String, dynamic> map, String id) => ExpenseComment(
    id: id,
    authorUid: (map['authorUid'] ?? '').toString(),
    authorName: (map['authorName'] ?? '').toString(),
    text: (map['text'] ?? '').toString(),
    // Pending server timestamp reads as null for a moment: show it as now.
    createdAt: readDate(map['createdAt']) ?? DateTime.now(),
  );
}
