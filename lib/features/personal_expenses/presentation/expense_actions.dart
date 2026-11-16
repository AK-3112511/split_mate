import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared_widgets/amount_text.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/receipt_viewer.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../../receipts/data/receipts_repository.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';

/// Optimistic delete with Undo. Receipt images are purged only after the
/// undo window closes without "Undo".
Future<void> deleteExpenseWithUndo(WidgetRef ref, ExpenseModel expense) async {
  final repo = ref.read(expenseRepositoryProvider);
  try {
    await repo.delete(expense);
  } catch (e) {
    Toast.error(e);
    return;
  }
  Haptics.light();
  final controller = Toast.show(
    expense.isMirror ? 'Removed from your ledger' : 'Expense deleted',
    actionLabel: 'Undo',
    duration: const Duration(seconds: 5),
    onAction: () async {
      try {
        await repo.restore(expense);
      } catch (e) {
        Toast.error(e);
      }
    },
  );
  final reason = await controller?.closed;
  if (reason != SnackBarClosedReason.action) {
    try {
      await repo.purgeReceipt(expense);
    } catch (_) {}
  }
}

/// Bottom sheet with everything about one personal expense.
Future<void> showExpenseDetail(BuildContext context, ExpenseModel expense) {
  return showAppSheet<void>(context, builder: (_) => _ExpenseDetail(expense: expense));
}

class _ExpenseDetail extends ConsumerWidget {
  final ExpenseModel expense;
  const _ExpenseDetail({required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final cat = CategoryResolver.resolve(id: expense.categoryId, name: expense.categoryName, categories: cats);

    Widget row(IconData icon, String label, String value, {VoidCallback? onTap}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconBadge(icon, size: 40),
          title: Text(label, style: context.text.labelMedium),
          subtitle: Text(value, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );

    return SheetBody(
      children: [
        Row(
          children: [
            CategoryBubble(cat, size: 52),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.description, style: context.text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(cat.name, style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Center(
          child: AmountText(expense.amount,
              style: context.text.displaySmall?.copyWith(fontFeatures: AppTheme.tabular), animate: true),
        ),
        const SizedBox(height: Space.lg),
        row(Icons.event_rounded, 'Date', '${Dates.dayLabel(expense.date)} · ${Dates.time(expense.date)}'),
        if (expense.isMirror)
          row(
            Icons.groups_rounded,
            'Your share from a group',
            expense.sourceGroupName ?? 'Group expense',
            onTap: expense.sourceGroupId == null
                ? null
                : () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.go('/groups/${expense.sourceGroupId}');
                  },
          ),
        if (expense.generatedFromTemplateId != null)
          row(Icons.autorenew_rounded, 'Recurring', 'Added automatically', onTap: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push('/recurring');
          }),
        if (expense.notes != null && expense.notes!.trim().isNotEmpty)
          row(Icons.notes_rounded, 'Notes', expense.notes!.trim()),
        if (expense.hasReceipt)
          row(Icons.receipt_long_rounded, 'Receipt', 'Tap to view', onTap: () {
            ReceiptViewer.show(
              context,
              receipt: ReceiptRef(receiptId: expense.receiptId, legacy: expense.legacyReceipt),
              title: expense.description,
            );
          }),
        const SizedBox(height: Space.lg),
        if (expense.isMirror)
          Text(
            'This is your share of a group expense. Edit it from the group so everyone stays in sync.',
            style: context.text.bodySmall,
            textAlign: TextAlign.center,
          )
        else
          PrimaryButton(
            label: 'Edit expense',
            icon: Icons.edit_rounded,
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push('/expense/${expense.id}/edit');
            },
          ),
        const SizedBox(height: Space.sm),
        SecondaryButton(
          label: expense.isMirror ? 'Remove from my ledger' : 'Delete',
          icon: Icons.delete_outline_rounded,
          color: c.negative,
          onPressed: () async {
            final ok = await confirmAction(
              context,
              title: expense.isMirror ? 'Remove from your ledger?' : 'Delete this expense?',
              message: expense.isMirror
                  ? 'The group expense stays; it just won\'t count in your personal spending.'
                  : 'You can undo this for a few seconds.',
              confirmLabel: expense.isMirror ? 'Remove' : 'Delete',
              destructive: true,
            );
            if (!ok || !context.mounted) return;
            Navigator.of(context).pop();
            await deleteExpenseWithUndo(ref, expense);
          },
        ),
      ],
    );
  }
}
