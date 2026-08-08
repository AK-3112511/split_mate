import 'package:flutter/material.dart';
import '../../features/categories/domain/category_model.dart';

/// CategoryHelper provides robust, cross-user category resolution.
/// It maps category IDs, names, or UUID strings to resolved CategoryModel
/// instances so that expenses created by one user display correctly with
/// matching category names and icons for all other group members.
class CategoryHelper {
  // Standard fallback categories map by normalized key
  static final List<CategoryModel> defaultCategories = [
    CategoryModel(id: 'food', name: 'Food', iconCode: 'restaurant', colorHex: 'FF5722'),
    CategoryModel(id: 'rent', name: 'Rent', iconCode: 'home', colorHex: '2196F3'),
    CategoryModel(id: 'travel', name: 'Travel', iconCode: 'directions_car', colorHex: '4CAF50'),
    CategoryModel(id: 'entertainment', name: 'Entertainment', iconCode: 'movie', colorHex: '9C27B0'),
    CategoryModel(id: 'utilities', name: 'Utilities', iconCode: 'electrical_services', colorHex: 'FFEB3B'),
  ];

  /// Resolves any category identifier (UUID, name, or key) to a CategoryModel
  /// against the provided [userCategories] list. Never returns null!
  static CategoryModel resolveCategory(
    String rawCategory,
    List<CategoryModel> userCategories,
  ) {
    if (rawCategory.trim().isEmpty) {
      return _fallbackCategory('Others');
    }

    final cleanRaw = rawCategory.trim();
    final lowerRaw = cleanRaw.toLowerCase();

    // 1. Direct ID match in user's categories
    for (final c in userCategories) {
      if (c.id == cleanRaw || c.id.toLowerCase() == lowerRaw) {
        return c;
      }
    }

    // 2. Name match (case-insensitive) in user's categories
    for (final c in userCategories) {
      if (c.name.trim().toLowerCase() == lowerRaw) {
        return c;
      }
    }

    // 3. Match standard default categories by ID or Name
    for (final d in defaultCategories) {
      if (d.id.toLowerCase() == lowerRaw || d.name.toLowerCase() == lowerRaw) {
        CategoryModel? userMatch;
        for (final c in userCategories) {
          if (c.name.trim().toLowerCase() == d.name.toLowerCase()) {
            userMatch = c;
            break;
          }
        }
        return userMatch ?? d;
      }
    }

    // 4. If rawCategory is a non-UUID category name (e.g. "Food", "Medical", "Groceries"):
    final isUuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanRaw);
    if (!isUuidPattern && cleanRaw.isNotEmpty) {
      return CategoryModel(
        id: cleanRaw,
        name: cleanRaw,
        iconCode: _guessIconCode(cleanRaw),
        colorHex: _guessColorHex(cleanRaw),
      );
    }

    // 5. Fallback for unresolvable raw UUIDs
    return _fallbackCategory('Others');
  }

  /// Groups items by resolved CategoryModel (using canonical category name)
  /// so that different representations of the same category (e.g. 'Food', 'food', 'cat_food_123')
  /// group into the same CategoryModel item.
  static Map<CategoryModel, double> groupExpensesByCategory<T>({
    required List<T> items,
    required String Function(T) getCategoryKey,
    required double Function(T) getAmount,
    required List<CategoryModel> userCategories,
  }) {
    final Map<String, CategoryModel> keyToCategoryMap = {};
    final Map<String, double> categorySums = {};

    for (final item in items) {
      final rawCat = getCategoryKey(item);
      final resolvedCat = resolveCategory(rawCat, userCategories);
      final canonicalKey = resolvedCat.name.trim().toLowerCase();

      keyToCategoryMap[canonicalKey] = resolvedCat;
      categorySums[canonicalKey] = (categorySums[canonicalKey] ?? 0.0) + getAmount(item);
    }

    final Map<CategoryModel, double> resultMap = {};
    categorySums.forEach((key, sum) {
      final cat = keyToCategoryMap[key]!;
      resultMap[cat] = sum;
    });

    return resultMap;
  }

  static CategoryModel _fallbackCategory(String name) {
    return CategoryModel(
      id: 'others',
      name: name,
      iconCode: 'miscellaneous_services',
      colorHex: '9E9E9E',
    );
  }

  static String _guessIconCode(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('food') || lower.contains('dinner') || lower.contains('eat') || lower.contains('snack')) return 'restaurant';
    if (lower.contains('home') || lower.contains('rent') || lower.contains('house') || lower.contains('room')) return 'home';
    if (lower.contains('travel') || lower.contains('cab') || lower.contains('car') || lower.contains('auto') || lower.contains('taxi')) return 'directions_car';
    if (lower.contains('movie') || lower.contains('game') || lower.contains('party') || lower.contains('fun')) return 'movie';
    if (lower.contains('bill') || lower.contains('power') || lower.contains('water') || lower.contains('wifi')) return 'electrical_services';
    if (lower.contains('shop') || lower.contains('buy') || lower.contains('cloth')) return 'shopping_bag';
    if (lower.contains('flight') || lower.contains('trip')) return 'flight';
    if (lower.contains('work') || lower.contains('office')) return 'work';
    if (lower.contains('school') || lower.contains('book')) return 'school';
    if (lower.contains('health') || lower.contains('med')) return 'health_and_safety';
    return 'miscellaneous_services';
  }

  static String _guessColorHex(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('food')) return 'FF5722';
    if (lower.contains('rent')) return '2196F3';
    if (lower.contains('travel')) return '4CAF50';
    if (lower.contains('entertainment')) return '9C27B0';
    if (lower.contains('utilities')) return 'FFEB3B';
    return 'D4AF37';
  }
}
