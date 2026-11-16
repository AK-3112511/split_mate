import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/motion.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../domain/expense_model.dart';

/// One personal expense row.
class ExpenseTile extends ConsumerWidget {
  final ExpenseModel expense;
  final VoidCallback? onTap;
  final bool showDate;
  const ExpenseTile({super.key, required this.expense, this.onTap, this.showDate = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final cat = CategoryResolver.resolve(id: expense.categoryId, name: expense.categoryName, categories: cats);
    final meta = <String>[
      if (showDate) Dates.dayLabel(expense.date) else cat.name,
      if (expense.isMirror && expense.sourceGroupName != null) expense.sourceGroupName!,
    ];
    return Pressable(
      onTap: onTap,
      borderRadius: Radii.tile,
      semanticLabel: '${expense.description}, ${Money.format(expense.amount)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 10),
        child: Row(
          children: [
            CategoryBubble(cat),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description.isEmpty ? cat.name : expense.description,
                    style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (expense.isMirror) ...[
                        Icon(Icons.groups_rounded, size: 14, color: c.secondary),
                        const SizedBox(width: 4),
                      ],
                      if (expense.generatedFromTemplateId != null) ...[
                        Icon(Icons.autorenew_rounded, size: 14, color: c.textMuted),
                        const SizedBox(width: 4),
                      ],
                      if (expense.hasReceipt) ...[
                        Icon(Icons.receipt_long_rounded, size: 14, color: c.textMuted),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(meta.join(' · '),
                            style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            Text(
              Money.format(expense.amount),
              style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular),
            ),
          ],
        ),
      ),
    );
  }
}
