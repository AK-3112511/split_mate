import 'package:cloud_firestore/cloud_firestore.dart';

// ── SplitEntry ────────────────────────────────────────────────────────────────
// New schema: splits = { uid: { amountOwed: number, settled: bool } }
// Replaces the old flat { uid: number } format.
// recomputeBalances/settleUp are NEVER aware of the settled flag — they always
// read only amountOwed via GroupExpenseModel.splitsAmountOwed.

class SplitEntry {
  final double amountOwed;
  final bool settled;

  const SplitEntry({required this.amountOwed, required this.settled});

  Map<String, dynamic> toMap() => {
        'amountOwed': amountOwed,
        'settled': settled,
      };

  factory SplitEntry.fromMap(dynamic raw) {
    // New format: { amountOwed: number, settled: bool }
    if (raw is Map) {
      return SplitEntry(
        amountOwed: (raw['amountOwed'] ?? 0.0).toDouble(),
        settled: raw['settled'] ?? false,
      );
    }
    // Backward-compat: old flat number format { uid: number }
    return SplitEntry(
      amountOwed: (raw ?? 0.0).toDouble(),
      settled: false,
    );
  }
}

// ── GroupExpenseItemModel ─────────────────────────────────────────────────────

class GroupExpenseItemModel {
  final String name;
  final double amount;
  final List<String> memberUids;

  GroupExpenseItemModel({
    required this.name,
    required this.amount,
    required this.memberUids,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'memberUids': memberUids,
    };
  }

  factory GroupExpenseItemModel.fromMap(Map<String, dynamic> map) {
    final rawUids = map['memberUids'] ?? [];
    final List<String> uids = List<String>.from(rawUids.map((e) => e.toString()));
    return GroupExpenseItemModel(
      name: map['name'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      memberUids: uids,
    );
  }
}

// ── GroupExpenseModel ─────────────────────────────────────────────────────────

class GroupExpenseModel {
  final String expenseId;
  final String payerUid;
  final double amount;
  final String category;
  final String description;
  final String splitType; // 'equal' | 'custom' | 'percentage' | 'itemized'

  /// New schema: uid → SplitEntry { amountOwed, settled }
  final Map<String, SplitEntry> splits;

  final DateTime createdAt;
  final bool isDeleted;
  final String? receiptUrl;

  // Recurring fields
  final bool isRecurringTemplate;
  final String? recurrenceInterval; // 'weekly' | 'monthly'
  final DateTime? lastGeneratedDate;
  final String? generatedFromTemplateId;
  final bool isCancelled;

  // Itemized splitting fields
  final List<GroupExpenseItemModel>? items;

  GroupExpenseModel({
    required this.expenseId,
    required this.payerUid,
    required this.amount,
    required this.category,
    required this.description,
    required this.splitType,
    required this.splits,
    required this.createdAt,
    this.isDeleted = false,
    this.receiptUrl,
    this.isRecurringTemplate = false,
    this.recurrenceInterval,
    this.lastGeneratedDate,
    this.generatedFromTemplateId,
    this.isCancelled = false,
    this.items,
  });

  // ── Compatibility getter for settlement_algorithm.dart ──────────────────────
  // recomputeBalances and settleUp call this to get { uid: amountOwed } exactly
  // as before — zero change to settlement logic, settled flag is invisible.
  Map<String, double> get splitsAmountOwed {
    return splits.map((uid, entry) => MapEntry(uid, entry.amountOwed));
  }

  bool get isSettlement =>
      category == 'Settlement' ||
      description == 'Settlement Payment' ||
      category.toLowerCase() == 'settlement' ||
      description.toLowerCase().contains('settlement');

  Map<String, dynamic> toMap() {
    return {
      'payerUid': payerUid,
      'amount': amount,
      'category': category,
      'description': description,
      'splitType': splitType,
      // New format: { uid: { amountOwed, settled } }
      'splits': splits.map((uid, entry) => MapEntry(uid, entry.toMap())),
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'receiptUrl': receiptUrl,
      'isRecurringTemplate': isRecurringTemplate,
      'recurrenceInterval': recurrenceInterval,
      'lastGeneratedDate': lastGeneratedDate != null ? Timestamp.fromDate(lastGeneratedDate!) : null,
      'generatedFromTemplateId': generatedFromTemplateId,
      'isCancelled': isCancelled,
      'items': items?.map((i) => i.toMap()).toList(),
    };
  }

  factory GroupExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDate = map['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    // Parse splits — supports both old { uid: number } and new { uid: { amountOwed, settled } }
    final rawSplits = map['splits'] ?? {};
    final Map<String, SplitEntry> parsedSplits = {};
    (rawSplits as Map).forEach((key, val) {
      parsedSplits[key.toString()] = SplitEntry.fromMap(val);
    });

    final rawLastGen = map['lastGeneratedDate'];
    DateTime? lastGenDate;
    if (rawLastGen is Timestamp) {
      lastGenDate = rawLastGen.toDate();
    }

    final rawItems = map['items'];
    List<GroupExpenseItemModel>? parsedItems;
    if (rawItems is List) {
      parsedItems = rawItems
          .map((item) => GroupExpenseItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return GroupExpenseModel(
      expenseId: id,
      payerUid: map['payerUid'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      splitType: map['splitType'] ?? 'equal',
      splits: parsedSplits,
      createdAt: parsedDate,
      isDeleted: map['isDeleted'] ?? false,
      receiptUrl: map['receiptUrl'],
      isRecurringTemplate: map['isRecurringTemplate'] ?? false,
      recurrenceInterval: map['recurrenceInterval'],
      lastGeneratedDate: lastGenDate,
      generatedFromTemplateId: map['generatedFromTemplateId'],
      isCancelled: map['isCancelled'] ?? false,
      items: parsedItems,
    );
  }
}
