import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/domain/split_calculator.dart';
import 'package:split_mate/features/categories/domain/category_model.dart';
import 'package:split_mate/features/categories/domain/category_resolver.dart';
import 'package:split_mate/features/export/export_service.dart';
import 'package:split_mate/features/groups/data/group_expenses_repository.dart';
import 'package:split_mate/features/groups/domain/group_expense_model.dart';
import 'package:split_mate/features/personal_expenses/domain/expense_model.dart';

void main() {
  group('backward compatibility with v1 documents', () {
    test('personal expense without date/categoryId falls back sensibly', () {
      final created = DateTime(2026, 7, 1, 10);
      final e = ExpenseModel.fromMap({
        'amount': 250,
        'category': 'Food',
        'description': 'Lunch',
        'createdAt': Timestamp.fromDate(created),
        'receiptUrl': 'data:image/jpeg;base64,AAAA',
      }, 'x');
      expect(e.date, created);
      expect(e.categoryId, '');
      expect(e.categoryName, 'Food');
      expect(e.hasReceipt, isTrue);
      expect(e.hidden, isFalse);
    });

    test('group expense: flat number splits, v1 settlement detection, no date', () {
      final g = GroupExpenseModel.fromMap({
        'payerUid': 'a',
        'amount': 100,
        'category': 'Settlement',
        'description': 'Settlement Payment',
        'splits': {'a': 0, 'b': 100},
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      }, 'p');
      expect(g.isPayment, isTrue);
      expect(g.shareByUid, {'a': 0.0, 'b': 100.0});
      expect(g.date, DateTime(2026, 1, 1));
      expect(g.splitMode, SplitMode.equal);
    });

    test('a real expense mentioning "settlement" is not a payment (v1 bug)', () {
      final g = GroupExpenseModel.fromMap({
        'type': 'expense',
        'payerUid': 'a',
        'amount': 5000,
        'category': 'Rent',
        'description': 'Flat settlement deposit',
        'splits': {'a': {'amountOwed': 2500, 'settled': true}, 'b': {'amountOwed': 2500, 'settled': false}},
      }, 'r');
      expect(g.isPayment, isFalse);
    });

    test('legacy category colours map to the new palette', () {
      final c = CategoryModel.fromMap({'id': 'food', 'name': 'Food', 'iconCode': 'restaurant', 'colorHex': 'FF5722'});
      expect(c.colorHex, 'F97316');
      expect(CategoryModel.fromMap({'id': 'x', 'name': 'X', 'colorHex': 'zzzz'}).color.toARGB32(), 0xFF64748B);
    });
  });

  group('CategoryResolver', () {
    final cats = [
      const CategoryModel(id: 'u1', name: 'Coffee', iconCode: 'local_cafe', colorHex: '8B5CF6'),
      ...CategoryModel.defaults,
    ];
    test('resolves by id, by (case-insensitive) name, defaults and Other', () {
      expect(CategoryResolver.resolve(id: 'u1', categories: cats).name, 'Coffee');
      expect(CategoryResolver.resolve(name: 'coffee', categories: cats).id, 'u1');
      expect(CategoryResolver.resolve(name: 'Rent', categories: const []).id, 'rent');
      expect(CategoryResolver.resolve(name: '', categories: cats).id, CategoryModel.othersId);
      expect(CategoryResolver.resolve(id: 'others', categories: cats).name, 'Other');
    });

    test('unknown names get a stable stand-in using the snapshot look', () {
      final r = CategoryResolver.resolve(name: 'Gym', iconCode: 'fitness_center', colorHex: '22C55E', categories: cats);
      expect(r.name, 'Gym');
      expect(r.iconCode, 'fitness_center');
      expect(r.id, 'name:gym');
      expect(CategoryResolver.guessIcon('Uber to airport'), 'directions_car');
    });
  });

  test('activity diff describes what changed', () {
    GroupExpenseModel g(double amount, Map<String, double> shares, String desc) => GroupExpenseModel(
          expenseId: 'e',
          payerUid: 'a',
          amount: amount,
          category: 'Food',
          description: desc,
          splitType: 'equal',
          splits: {for (final s in shares.entries) s.key: SplitEntry(amountOwed: s.value, settled: s.key == 'a')},
          date: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        );
    final changes = GroupExpensesRepository.describeChanges(
      g(100, {'a': 50, 'b': 50}, 'Momos'),
      g(150, {'a': 75, 'b': 75}, 'Pizza'),
    );
    expect(changes, contains('amount ₹100 → ₹150'));
    expect(changes, contains('renamed from "Momos"'));
    expect(changes, contains('split changed'));
  });

  test('personal CSV export escapes commas and quotes', () {
    final csv = ExportService.personalCsv([
      ExpenseModel(
        id: '1',
        amount: 1200.5,
        categoryId: 'food',
        categoryName: 'Food',
        description: 'Dinner, "fancy"',
        date: DateTime(2026, 11, 2),
        createdAt: DateTime(2026, 11, 2),
      ),
    ], CategoryModel.defaults);
    final lines = csv.trim().split('\n');
    expect(lines.first, startsWith('Date,Description'));
    expect(lines[1], '2 Nov 2026,"Dinner, ""fancy""",Food,1200.50,Personal,');
  });
}
