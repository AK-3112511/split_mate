import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/recurrence.dart';

DateTime? readDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// A personal expense (or a recurring template, or a mirror of a group share).
class ExpenseModel {
  final String id;
  final double amount;

  /// v2: id into the user's categories. Empty for v1 docs (see [categoryName]).
  final String categoryId;

  /// v1 stored the category *name* in `category`; v2 keeps it as a readable copy.
  final String categoryName;
  final String description;
  final String? notes;

  /// The day the money was spent (user-picked). v1 docs fall back to createdAt.
  final DateTime date;
  final DateTime createdAt;

  /// Receipt image lives in users/{uid}/receipts/{receiptId}.
  final String? receiptId;

  /// v1 inline base64 / url receipt (read-only compatibility).
  final String? legacyReceipt;

  // Recurring template fields
  final bool isRecurringTemplate;
  final String? recurrenceInterval;
  final DateTime? lastGeneratedDate;
  final String? generatedFromTemplateId;
  final bool isCancelled;

  // Group mirror fields (spec §12)
  final bool isFromGroup;
  final String? sourceGroupId;
  final String? sourceExpenseId;
  final String? sourceGroupName;

  /// Tombstone: user deleted this mirror, or its group expense was deleted.
  final bool hidden;

  const ExpenseModel({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.date,
    required this.createdAt,
    this.notes,
    this.receiptId,
    this.legacyReceipt,
    this.isRecurringTemplate = false,
    this.recurrenceInterval,
    this.lastGeneratedDate,
    this.generatedFromTemplateId,
    this.isCancelled = false,
    this.isFromGroup = false,
    this.sourceGroupId,
    this.sourceExpenseId,
    this.sourceGroupName,
    this.hidden = false,
  });

  bool get hasReceipt => receiptId != null || (legacyReceipt?.isNotEmpty ?? false);
  RecurrenceInterval? get interval => RecurrenceInterval.fromKey(recurrenceInterval);
  bool get isMirror => isFromGroup && sourceExpenseId != null;

  /// Fields written on create. Updates use explicit field maps instead so they
  /// never clobber mirror/recurring metadata.
  Map<String, dynamic> toMap() => {
        'amount': amount,
        'categoryId': categoryId,
        'category': categoryName,
        'description': description,
        'notes': notes,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'receiptId': receiptId,
        'isRecurringTemplate': isRecurringTemplate,
        'recurrenceInterval': recurrenceInterval,
        'lastGeneratedDate': lastGeneratedDate != null ? Timestamp.fromDate(lastGeneratedDate!) : null,
        'generatedFromTemplateId': generatedFromTemplateId,
        'isCancelled': isCancelled,
        'isFromGroup': isFromGroup,
        'sourceGroupId': sourceGroupId,
        'sourceExpenseId': sourceExpenseId,
        'sourceGroupName': sourceGroupName,
        'hidden': hidden,
      };

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    final created = readDate(map['createdAt']) ?? DateTime.now();
    final amount = map['amount'];
    return ExpenseModel(
      id: id,
      amount: amount is num && amount.isFinite ? amount.toDouble() : 0.0,
      categoryId: (map['categoryId'] ?? '').toString(),
      categoryName: (map['category'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      notes: map['notes'] as String?,
      date: readDate(map['date']) ?? created,
      createdAt: created,
      receiptId: map['receiptId'] as String?,
      legacyReceipt: map['receiptUrl'] as String?,
      isRecurringTemplate: map['isRecurringTemplate'] == true,
      recurrenceInterval: map['recurrenceInterval'] as String?,
      lastGeneratedDate: readDate(map['lastGeneratedDate']),
      generatedFromTemplateId: map['generatedFromTemplateId'] as String?,
      isCancelled: map['isCancelled'] == true,
      isFromGroup: map['isFromGroup'] == true,
      sourceGroupId: map['sourceGroupId'] as String?,
      sourceExpenseId: map['sourceExpenseId'] as String?,
      sourceGroupName: map['sourceGroupName'] as String?,
      hidden: map['hidden'] == true,
    );
  }

  ExpenseModel copyWith({
    double? amount,
    String? categoryId,
    String? categoryName,
    String? description,
    String? notes,
    DateTime? date,
    String? receiptId,
    bool clearReceipt = false,
    bool? isRecurringTemplate,
    String? recurrenceInterval,
    bool? hidden,
  }) {
    return ExpenseModel(
      id: id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      createdAt: createdAt,
      receiptId: clearReceipt ? null : (receiptId ?? this.receiptId),
      legacyReceipt: clearReceipt ? null : legacyReceipt,
      isRecurringTemplate: isRecurringTemplate ?? this.isRecurringTemplate,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      lastGeneratedDate: lastGeneratedDate,
      generatedFromTemplateId: generatedFromTemplateId,
      isCancelled: isCancelled,
      isFromGroup: isFromGroup,
      sourceGroupId: sourceGroupId,
      sourceExpenseId: sourceExpenseId,
      sourceGroupName: sourceGroupName,
      hidden: hidden ?? this.hidden,
    );
  }
}
