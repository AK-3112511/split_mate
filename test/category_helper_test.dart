import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/utils/category_helper.dart';
import 'package:split_mate/features/categories/domain/category_model.dart';

void main() {
  group('CategoryHelper Unit Tests', () {
    final userCategories = [
      CategoryModel(id: 'food', name: 'Food', iconCode: 'restaurant', colorHex: 'FF5722'),
      CategoryModel(id: 'rent', name: 'Rent', iconCode: 'home', colorHex: '2196F3'),
      CategoryModel(id: 'custom_123', name: 'Gaming', iconCode: 'sports_esports', colorHex: '9C27B0'),
    ];

    test('Resolves exact category ID match', () {
      final cat = CategoryHelper.resolveCategory('rent', userCategories);
      expect(cat.name, 'Rent');
      expect(cat.iconCode, 'home');
    });

    test('Resolves category name case-insensitively', () {
      final cat = CategoryHelper.resolveCategory('FOOD', userCategories);
      expect(cat.name, 'Food');
      expect(cat.iconCode, 'restaurant');
    });

    test('Resolves standard category name for member without custom ID', () {
      final cat = CategoryHelper.resolveCategory('Travel', userCategories);
      expect(cat.name, 'Travel');
      expect(cat.iconCode, 'directions_car');
    });

    test('Resolves non-UUID custom category name on the fly with smart icon guessing', () {
      final cat = CategoryHelper.resolveCategory('Dinner with team', userCategories);
      expect(cat.name, 'Dinner with team');
      expect(cat.iconCode, 'restaurant');
    });

    test('Groups expenses by resolved category name correctly', () {
      final items = [
        {'cat': 'food', 'amt': 100.0},
        {'cat': 'Food', 'amt': 200.0},
        {'cat': 'Travel', 'amt': 150.0},
      ];

      final grouped = CategoryHelper.groupExpensesByCategory(
        items: items,
        getCategoryKey: (i) => i['cat'] as String,
        getAmount: (i) => i['amt'] as double,
        userCategories: userCategories,
      );

      final foodCat = grouped.keys.firstWhere((c) => c.name.toLowerCase() == 'food');
      final travelCat = grouped.keys.firstWhere((c) => c.name.toLowerCase() == 'travel');

      expect(grouped[foodCat], 300.0);
      expect(grouped[travelCat], 150.0);
    });
  });
}
