import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../domain/category_guesser.dart';
import '../domain/category_model.dart';
import '../domain/category_resolver.dart';
import 'categories_repository.dart';

/// Category guesser trained on your own expenses (group shares included).
final categoryGuesserProvider = Provider.autoDispose<CategoryGuesser>((ref) {
  final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
  final expenses = ref.watch(personalExpensesProvider).valueOrNull ?? const [];
  return CategoryGuesser(
    categories: cats,
    history: [
      for (final e in expenses)
        CategoryHint(
          description: e.description,
          categoryId: CategoryResolver.resolve(id: e.categoryId, name: e.categoryName, categories: cats).id,
          amount: e.amount,
          date: e.date,
          personal: !e.isFromGroup,
        ),
    ],
  );
});
