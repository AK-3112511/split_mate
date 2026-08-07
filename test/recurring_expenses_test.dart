import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_mate/core/utils/recurring_engine.dart';
import 'package:split_mate/features/personal_expenses/domain/expense_model.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';

void main() {
  group('Recurring Expenses Engine Helper Tests', () {
    test('shouldGenerateRecurringInstance returns true when never generated before', () {
      final templateCreated = DateTime.now().subtract(const Duration(days: 10));
      final result = shouldGenerateRecurringInstance(null, 'weekly', templateCreated);
      expect(result, isTrue);
    });

    test('shouldGenerateRecurringInstance respects weekly boundaries', () {
      final now = DateTime.now();
      
      // 8 days ago: should trigger weekly generation
      final lastGen1 = now.subtract(const Duration(days: 8));
      expect(shouldGenerateRecurringInstance(lastGen1, 'weekly', now), isTrue);

      // 6 days ago: should NOT trigger weekly generation
      final lastGen2 = now.subtract(const Duration(days: 6));
      expect(shouldGenerateRecurringInstance(lastGen2, 'weekly', now), isFalse);
    });

    test('shouldGenerateRecurringInstance respects monthly boundaries', () {
      final now = DateTime.now();

      // 31 days ago: should trigger monthly generation
      final lastGen1 = now.subtract(const Duration(days: 31));
      expect(shouldGenerateRecurringInstance(lastGen1, 'monthly', now), isTrue);

      // 28 days ago: should NOT trigger monthly generation
      final lastGen2 = now.subtract(const Duration(days: 28));
      expect(shouldGenerateRecurringInstance(lastGen2, 'monthly', now), isFalse);
    });
  });

  group('Personal & Group Model Serialization Tests for Recurring Fields', () {
    test('ExpenseModel maps and parses recurring fields', () {
      final map = {
        'amount': 1500.0,
        'category': 'Rent',
        'description': 'Monthly Apartment Rent',
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
        'isRecurringTemplate': true,
        'recurrenceInterval': 'monthly',
        'lastGeneratedDate': Timestamp.fromDate(DateTime(2026, 7, 1)),
        'generatedFromTemplateId': null,
        'isCancelled': false,
      };

      final expense = ExpenseModel.fromMap(map, 'test-id');

      expect(expense.isRecurringTemplate, isTrue);
      expect(expense.recurrenceInterval, 'monthly');
      expect(expense.lastGeneratedDate, isNotNull);
      expect(expense.isCancelled, isFalse);

      final mapOut = expense.toMap();
      expect(mapOut['isRecurringTemplate'], isTrue);
      expect(mapOut['recurrenceInterval'], 'monthly');
      expect(mapOut['isCancelled'], isFalse);
    });

    test('GroupExpenseModel maps and parses recurring fields', () {
      final map = {
        'payerUid': 'user-1',
        'amount': 700.0,
        'category': 'Entertainment',
        'description': 'Netflix Subscription',
        'splitType': 'equal',
        'splits': {'user-1': 350.0, 'user-2': 350.0},
        'createdAt': Timestamp.fromDate(DateTime(2026, 7, 16)),
        'isDeleted': false,
        'isRecurringTemplate': true,
        'recurrenceInterval': 'weekly',
        'lastGeneratedDate': null,
        'generatedFromTemplateId': null,
        'isCancelled': true,
      };

      final expense = GroupExpenseModel.fromMap(map, 'group-exp-id');

      expect(expense.isRecurringTemplate, isTrue);
      expect(expense.recurrenceInterval, 'weekly');
      expect(expense.lastGeneratedDate, isNull);
      expect(expense.isCancelled, isTrue);

      final mapOut = GroupExpenseModel.fromMap(map, 'group-exp-id').toMap();
      expect(mapOut['isRecurringTemplate'], isTrue);
      expect(mapOut['recurrenceInterval'], 'weekly');
      expect(mapOut['isCancelled'], isTrue);
    });
  });

  group('Recurring Expense Cancellation & Generation Flow simulation', () {
    test('lifecycle simulation', () {
      // 1. Create a test recurring template
      final template = GroupExpenseModel(
        expenseId: 'template-1',
        payerUid: 'user-1',
        amount: 5000.0,
        category: 'Rent',
        description: 'Monthly Flat Rent',
        splitType: 'equal',
        splits: {'user-1': 2500.0, 'user-2': 2500.0},
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
        isRecurringTemplate: true,
        recurrenceInterval: 'monthly',
        lastGeneratedDate: null,
        isCancelled: false,
      );

      // 2. Generation check on template (never generated before, so should trigger)
      expect(shouldGenerateRecurringInstance(template.lastGeneratedDate, template.recurrenceInterval, template.createdAt), isTrue);

      // 3. Generate instance
      final instance = GroupExpenseModel(
        expenseId: 'instance-1',
        payerUid: template.payerUid,
        amount: template.amount,
        category: template.category,
        description: template.description,
        splitType: template.splitType,
        splits: template.splits,
        createdAt: DateTime.now(),
        isRecurringTemplate: false,
        generatedFromTemplateId: template.expenseId,
        isCancelled: false,
      );

      // Update template lastGeneratedDate
      final updatedTemplate = GroupExpenseModel(
        expenseId: template.expenseId,
        payerUid: template.payerUid,
        amount: template.amount,
        category: template.category,
        description: template.description,
        splitType: template.splitType,
        splits: template.splits,
        createdAt: template.createdAt,
        isRecurringTemplate: true,
        recurrenceInterval: template.recurrenceInterval,
        lastGeneratedDate: DateTime.now(),
        isCancelled: false,
      );

      // 4. Cancel the template via setting isCancelled: true
      final cancelledTemplate = GroupExpenseModel(
        expenseId: updatedTemplate.expenseId,
        payerUid: updatedTemplate.payerUid,
        amount: updatedTemplate.amount,
        category: updatedTemplate.category,
        description: updatedTemplate.description,
        splitType: updatedTemplate.splitType,
        splits: updatedTemplate.splits,
        createdAt: updatedTemplate.createdAt,
        isRecurringTemplate: true,
        recurrenceInterval: updatedTemplate.recurrenceInterval,
        lastGeneratedDate: updatedTemplate.lastGeneratedDate,
        isCancelled: true,
      );

      // Confirm (1): isCancelled field is set to true in Firestore mapping
      expect(cancelledTemplate.isCancelled, isTrue);
      expect(cancelledTemplate.toMap()['isCancelled'], isTrue);

      // Confirm (2): already-generated instance remains uncancelled and intact
      expect(instance.isCancelled, isFalse);
      expect(instance.generatedFromTemplateId, 'template-1');
      expect(instance.amount, 5000.0);
      expect(instance.splits['user-1'], 2500.0);

      // Confirm (3): simulate launch-time query filter - cancelled templates (isCancelled: true)
      // will be filtered out by where('isCancelled', isEqualTo: false) in processRecurringTemplates
      final activeTemplatesQueryResults = [cancelledTemplate].where((t) => t.isRecurringTemplate && !t.isCancelled).toList();
      expect(activeTemplatesQueryResults, isEmpty);
    });
  });
}
