import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final double amount;
  final String category; // category ID
  final String description;
  final DateTime createdAt;
  final String? receiptUrl;

  // Recurring fields
  final bool isRecurringTemplate;
  final String? recurrenceInterval; // "weekly" | "monthly"
  final DateTime? lastGeneratedDate;
  final String? generatedFromTemplateId;
  final bool isCancelled;

  ExpenseModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.createdAt,
    this.receiptUrl,
    this.isRecurringTemplate = false,
    this.recurrenceInterval,
    this.lastGeneratedDate,
    this.generatedFromTemplateId,
    this.isCancelled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'receiptUrl': receiptUrl,
      'isRecurringTemplate': isRecurringTemplate,
      'recurrenceInterval': recurrenceInterval,
      'lastGeneratedDate': lastGeneratedDate != null ? Timestamp.fromDate(lastGeneratedDate!) : null,
      'generatedFromTemplateId': generatedFromTemplateId,
      'isCancelled': isCancelled,
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    final rawDate = map['createdAt'];
    DateTime parsedDate = DateTime.now();
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final rawLastGen = map['lastGeneratedDate'];
    DateTime? lastGenDate;
    if (rawLastGen is Timestamp) {
      lastGenDate = rawLastGen.toDate();
    }

    return ExpenseModel(
      id: id,
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      createdAt: parsedDate,
      receiptUrl: map['receiptUrl'],
      isRecurringTemplate: map['isRecurringTemplate'] ?? false,
      recurrenceInterval: map['recurrenceInterval'],
      lastGeneratedDate: lastGenDate,
      generatedFromTemplateId: map['generatedFromTemplateId'],
      isCancelled: map['isCancelled'] ?? false,
    );
  }
}
