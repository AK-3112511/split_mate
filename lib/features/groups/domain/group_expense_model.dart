import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/recurrence.dart';
import '../../../core/domain/settlement.dart';
import '../../../core/domain/split_calculator.dart';
import '../../personal_expenses/domain/expense_model.dart' show readDate;

/// One member's share of a group expense.
/// Stored as `splits: { uid: { amountOwed, settled } }` (v1 also had `{ uid: number }`).
class SplitEntry {
  final double amountOwed;

  /// True once this debt is cleared (always true for the payer's own share).
  /// Only drives personal mirroring — never the balance maths.
  final bool settled;

  const SplitEntry({required this.amountOwed, required this.settled});

  Map<String, dynamic> toMap() => {'amountOwed': amountOwed, 'settled': settled};

  factory SplitEntry.fromMap(dynamic raw) {
    if (raw is Map) {
      final a = raw['amountOwed'];
      return SplitEntry(
        amountOwed: a is num && a.isFinite ? a.toDouble() : 0.0,
        settled: raw['settled'] == true,
      );
    }
    return SplitEntry(amountOwed: raw is num && raw.isFinite ? raw.toDouble() : 0.0, settled: false);
  }
}

class GroupExpenseItemModel {
  final String name;
  final double amount;
  final List<String> memberUids;

  const GroupExpenseItemModel({required this.name, required this.amount, required this.memberUids});

  SplitItem toSplitItem() => SplitItem(name: name, amount: amount, memberUids: memberUids);

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount, 'memberUids': memberUids};

  factory GroupExpenseItemModel.fromMap(Map<String, dynamic> map) {
    final a = map['amount'];
    return GroupExpenseItemModel(
      name: (map['name'] ?? '').toString(),
      amount: a is num ? a.toDouble() : 0.0,
      memberUids: List<String>.from((map['memberUids'] ?? const []).map((e) => e.toString())),
    );
  }
}

/// A shared expense or a payment between two members, inside a group.
class GroupExpenseModel implements LedgerEntry {
  static const String typeExpense = 'expense';
  static const String typePayment = 'payment';

  final String expenseId;

  /// 'expense' | 'payment'. Null on v1 docs (payments detected by category).
  final String? type;
  @override
  final String payerUid;
  @override
  final double amount;

  /// Category snapshot (name + look) so every member sees the same category.
  final String category;
  final String? categoryIcon;
  final String? categoryColor;
  final String description;
  final String? notes;
  final String splitType;
  final Map<String, SplitEntry> splits;

  /// Day the money was spent (user-picked). v1 falls back to createdAt.
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  @override
  final bool isDeleted;
  final String? receiptId;
  final String? legacyReceipt;

  final bool isRecurringTemplate;
  final String? recurrenceInterval;
  final DateTime? lastGeneratedDate;
  final String? generatedFromTemplateId;
  final bool isCancelled;

  final List<GroupExpenseItemModel>? items;

  /// Itemized only: tax, service charge etc. minus any discount (₹, may be
  /// negative). Spread over people in proportion to what they had.
  final double? itemsExtra;

  const GroupExpenseModel({
    required this.expenseId,
    required this.payerUid,
    required this.amount,
    required this.category,
    required this.description,
    required this.splitType,
    required this.splits,
    required this.date,
    required this.createdAt,
    this.type = typeExpense,
    this.categoryIcon,
    this.categoryColor,
    this.notes,
    this.updatedAt,
    this.createdBy,
    this.isDeleted = false,
    this.receiptId,
    this.legacyReceipt,
    this.isRecurringTemplate = false,
    this.recurrenceInterval,
    this.lastGeneratedDate,
    this.generatedFromTemplateId,
    this.isCancelled = false,
    this.items,
    this.itemsExtra,
  });

  /// Payment records settle debts; they're not spending.
  bool get isPayment =>
      type == typePayment ||
      (type == null && category.trim().toLowerCase() == 'settlement');

  @override
  Map<String, double> get shareByUid =>
      {for (final e in splits.entries) e.key: e.value.amountOwed};

  /// For a payment: the person who received the money.
  String? get paymentRecipient =>
      isPayment ? splits.keys.firstWhere((k) => k != payerUid, orElse: () => '') : null;

  SplitMode get splitMode => SplitMode.fromStorage(splitType);
  RecurrenceInterval? get interval => RecurrenceInterval.fromKey(recurrenceInterval);
  bool get hasReceipt => receiptId != null || (legacyReceipt?.isNotEmpty ?? false);
  double shareOf(String uid) => splits[uid]?.amountOwed ?? 0.0;
  bool involves(String uid) => payerUid == uid || (splits[uid]?.amountOwed ?? 0) > 0;

  Map<String, dynamic> toMap() => {
        'type': type ?? typeExpense,
        'payerUid': payerUid,
        'amount': amount,
        'category': category,
        'categoryIcon': categoryIcon,
        'categoryColor': categoryColor,
        'description': description,
        'notes': notes,
        'splitType': splitType,
        'splits': splits.map((uid, e) => MapEntry(uid, e.toMap())),
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'isDeleted': isDeleted,
        'receiptId': receiptId,
        'isRecurringTemplate': isRecurringTemplate,
        'recurrenceInterval': recurrenceInterval,
        'lastGeneratedDate': lastGeneratedDate != null ? Timestamp.fromDate(lastGeneratedDate!) : null,
        'generatedFromTemplateId': generatedFromTemplateId,
        'isCancelled': isCancelled,
        'items': items?.map((i) => i.toMap()).toList(),
        if (itemsExtra != null && itemsExtra != 0) 'itemsExtra': itemsExtra,
      };

  factory GroupExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    final created = readDate(map['createdAt']) ?? DateTime.now();
    final rawSplits = map['splits'];
    final splits = <String, SplitEntry>{};
    if (rawSplits is Map) {
      rawSplits.forEach((k, v) => splits[k.toString()] = SplitEntry.fromMap(v));
    }
    final rawItems = map['items'];
    final a = map['amount'];
    return GroupExpenseModel(
      expenseId: id,
      type: map['type'] as String?,
      payerUid: (map['payerUid'] ?? '').toString(),
      amount: a is num && a.isFinite ? a.toDouble() : 0.0,
      category: (map['category'] ?? '').toString(),
      categoryIcon: map['categoryIcon'] as String?,
      categoryColor: map['categoryColor'] as String?,
      description: (map['description'] ?? '').toString(),
      notes: map['notes'] as String?,
      splitType: (map['splitType'] ?? 'equal').toString(),
      splits: splits,
      date: readDate(map['date']) ?? created,
      createdAt: created,
      updatedAt: readDate(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      isDeleted: map['isDeleted'] == true,
      receiptId: map['receiptId'] as String?,
      legacyReceipt: map['receiptUrl'] as String?,
      isRecurringTemplate: map['isRecurringTemplate'] == true,
      recurrenceInterval: map['recurrenceInterval'] as String?,
      lastGeneratedDate: readDate(map['lastGeneratedDate']),
      generatedFromTemplateId: map['generatedFromTemplateId'] as String?,
      isCancelled: map['isCancelled'] == true,
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((i) => GroupExpenseItemModel.fromMap(Map<String, dynamic>.from(i)))
              .toList()
          : null,
      itemsExtra: map['itemsExtra'] is num && (map['itemsExtra'] as num).isFinite
          ? (map['itemsExtra'] as num).toDouble()
          : null,
    );
  }

  /// Builds the new splits for an edit: shares come from [newShares]; a
  /// debtor's `settled` flag is kept only if their share and the payer are
  /// unchanged (so editing never silently un-settles or over-settles people).
  static Map<String, SplitEntry> mergeSettledFlags({
    required Map<String, double> newShares,
    required String newPayer,
    GroupExpenseModel? previous,
  }) {
    final out = <String, SplitEntry>{};
    newShares.forEach((uid, share) {
      var settled = uid == newPayer;
      if (!settled && previous != null && previous.payerUid == newPayer) {
        final old = previous.splits[uid];
        if (old != null && old.settled && (old.amountOwed * 100).round() == (share * 100).round()) {
          settled = true;
        }
      }
      out[uid] = SplitEntry(amountOwed: share, settled: settled);
    });
    return out;
  }
}
