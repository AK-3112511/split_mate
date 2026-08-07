import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/utils/export_helper.dart';

void main() {
  group('Export Data Formatting Accuracy Tests', () {
    test('Format Category Name helper formats preset, custom map, and UUID category strings cleanly', () {
      expect(ExportHelper.formatCategoryName('food_dining'), equals('Food & Dining'));
      expect(ExportHelper.formatCategoryName('groceries'), equals('Groceries'));
      expect(ExportHelper.formatCategoryName('transportation'), equals('Transportation'));
      expect(ExportHelper.formatCategoryName('custom_party_spend'), equals('Custom Party Spend'));
      expect(ExportHelper.formatCategoryName(''), equals('General'));

      final customMap = {'0957f4ae-444a-4d45-93a8-76a750613c4f': 'Dine Out'};
      expect(ExportHelper.formatCategoryName('0957f4ae-444a-4d45-93a8-76a750613c4f', customMap), equals('Dine Out'));
      expect(ExportHelper.formatCategoryName('7da99eb7 62c9 444b A022 0d657d4e6be6'), equals('General'));
    });
  });
}
