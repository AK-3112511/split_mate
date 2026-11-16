import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/motion.dart';
import '../../home/domain/home_stats.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../data/categories_repository.dart';
import '../domain/category_model.dart';
import 'category_editor_sheet.dart';

/// Categories + monthly budgets in one place.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final expenses = ref.watch(personalExpensesProvider).valueOrNull ?? const [];
    final month = DateRange.of(RangeKind.month);
    final monthList = expenses.where((e) => month.contains(e.date)).toList();
    double spentIn(CategoryModel cat) =>
        HomeStats.total(monthList.where((e) => HomeStats.categoryOf(e, cats).id == cat.id));
    final budgeted = cats.where((c) => c.hasBudget).toList();
    final totalBudget = budgeted.fold<double>(0, (a, c) => a + c.monthlyBudget!);
    final totalSpent = budgeted.fold<double>(0, (a, c) => a + spentIn(c));

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrGo('/profile')), title: const Text('Categories & budgets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 120),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(budgeted.isEmpty ? 'No budgets yet' : 'This month\'s budgets', style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  budgeted.isEmpty
                      ? 'Tap a category and add a monthly budget. We\'ll nudge you at 80% and if you go over.'
                      : '${Money.format(totalSpent)} of ${Money.format(totalBudget)} used',
                  style: context.text.bodySmall,
                ),
                if (budgeted.isNotEmpty) ...[
                  const SizedBox(height: Space.sm),
                  SoftProgressBar(
                    value: totalBudget <= 0 ? 0 : totalSpent / totalBudget,
                    color: totalSpent > totalBudget
                        ? c.negative
                        : (totalSpent >= totalBudget * 0.8 ? c.warning : c.positive),
                  ),
                ],
              ],
            ),
          ).entrance(context),
          const SizedBox(height: Space.lg),
          for (var i = 0; i < cats.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: _CategoryRow(category: cats[i], spent: spentIn(cats[i])).entrance(context, index: i),
            ),
        ],
      ),
      floatingActionButton: PopFab(
        onPressed: () => showCategoryEditor(context),
        icon: Icons.add_rounded,
        label: 'New category',
      ),
    );
  }
}

class _CategoryRow extends ConsumerWidget {
  final CategoryModel category;
  final double spent;
  const _CategoryRow({required this.category, required this.spent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final ratio = category.hasBudget ? spent / category.monthlyBudget! : 0.0;
    final color = ratio >= 1 ? c.negative : (ratio >= 0.8 ? c.warning : category.color);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xxs, Space.sm),
      onTap: () => showCategoryEditor(context, existing: category),
      child: Row(
        children: [
          CategoryBubble(category),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  category.hasBudget
                      ? '${Money.format(spent)} of ${Money.format(category.monthlyBudget!)}'
                      : spent > 0
                          ? '${Money.format(spent)} this month · no budget'
                          : 'No budget',
                  style: context.text.bodySmall?.copyWith(color: ratio >= 1 ? c.negative : null),
                ),
                if (category.hasBudget) ...[
                  const SizedBox(height: 6),
                  SoftProgressBar(value: ratio, color: color, height: 6),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Options',
            onSelected: (v) async {
              if (v == 'edit') {
                await showCategoryEditor(context, existing: category);
              } else if (v == 'delete') {
                final ok = await confirmAction(
                  context,
                  title: 'Delete ${category.name}?',
                  message: 'Expenses in this category will move to "Other". This can\'t be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (!ok) return;
                try {
                  await ref.read(categoriesRepositoryProvider).delete(category);
                  Toast.success('${category.name} deleted');
                } catch (e) {
                  Toast.error(e);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit / budget')),
              PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: c.negative))),
            ],
          ),
        ],
      ),
    );
  }
}
