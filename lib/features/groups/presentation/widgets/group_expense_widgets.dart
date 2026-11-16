import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/amount_text.dart';
import '../../../../shared_widgets/avatars.dart';
import '../../../../shared_widgets/bits.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../../shared_widgets/motion.dart';
import '../../../../shared_widgets/receipt_viewer.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../categories/domain/category_model.dart';
import '../../../categories/domain/category_resolver.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../receipts/data/receipts_repository.dart';
import '../../data/group_expenses_repository.dart';
import '../../domain/group_activity_model.dart';
import '../../domain/group_expense_model.dart';
import '../../domain/group_model.dart';

/// The category to show for a group expense (my matching category if I have
/// one, otherwise the creator's snapshot).
CategoryModel groupCategoryOf(GroupExpenseModel e, List<CategoryModel> mine) {
  if (e.isPayment) {
    return const CategoryModel(id: 'payment', name: 'Payment', iconCode: 'savings', colorHex: '22C55E');
  }
  return CategoryResolver.resolve(
    name: e.category,
    iconCode: e.categoryIcon,
    colorHex: e.categoryColor,
    categories: mine,
  );
}

/// One row in a group's expense list, with "you lent / you borrowed".
class GroupExpenseTile extends ConsumerWidget {
  final GroupExpenseModel expense;
  final VoidCallback? onTap;
  const GroupExpenseTile({super.key, required this.expense, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final me = ref.watch(currentUidProvider) ?? '';
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final cat = groupCategoryOf(expense, cats);
    final payer = ref.watch(memberNameProvider(expense.payerUid));

    String title;
    String subtitle;
    Widget trailing;
    if (expense.isPayment) {
      final to = ref.watch(memberNameProvider(expense.paymentRecipient ?? ''));
      title = '$payer paid $to';
      subtitle = 'Payment · ${Dates.short(expense.date)}';
      trailing = Text(Money.format(expense.amount),
          style: context.text.bodyLarge?.copyWith(color: c.positive, fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular));
    } else {
      title = expense.description.isEmpty ? cat.name : expense.description;
      subtitle = '$payer paid ${Money.format(expense.amount)}';
      final myShare = expense.shareOf(me);
      final lent = expense.payerUid == me ? expense.amount - myShare : 0.0;
      final borrowed = expense.payerUid == me ? 0.0 : myShare;
      final (label, value, color) = lent > 0.004
          ? ('you lent', lent, c.positive)
          : borrowed > 0.004
              ? ('you borrowed', borrowed, c.negative)
              : myShare > 0.004
                  ? ('your share', myShare, c.textMuted)
                  : ('not involved', 0.0, c.textMuted);
      trailing = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label, style: context.text.labelSmall?.copyWith(color: color, letterSpacing: 0)),
          if (value > 0)
            Text(Money.format(value),
                style: context.text.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular)),
        ],
      );
    }

    return Pressable(
      onTap: onTap,
      borderRadius: Radii.tile,
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
                  Text(title,
                      style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (expense.generatedFromTemplateId != null) ...[
                        Icon(Icons.autorenew_rounded, size: 14, color: c.textMuted),
                        const SizedBox(width: 4),
                      ],
                      if (expense.hasReceipt) ...[
                        Icon(Icons.receipt_long_rounded, size: 14, color: c.textMuted),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(subtitle, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Everything about one group expense or payment, with edit / delete.
Future<void> showGroupExpenseDetail(BuildContext context, GroupModel group, GroupExpenseModel expense) {
  return showAppSheet<void>(context, builder: (_) => _GroupExpenseDetail(group: group, expense: expense));
}

class _GroupExpenseDetail extends ConsumerWidget {
  final GroupModel group;
  final GroupExpenseModel expense;
  const _GroupExpenseDetail({required this.group, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final me = ref.watch(currentUidProvider) ?? '';
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final cat = groupCategoryOf(expense, cats);
    final payer = ref.watch(memberNameProvider(expense.payerUid));
    final activity = (ref.watch(groupActivityStreamProvider(group.groupId)).valueOrNull ?? const <GroupActivityModel>[])
        .where((a) => a.expenseId == expense.expenseId)
        .toList();
    final shares = expense.splits.entries.where((e) => e.value.amountOwed > 0).toList()
      ..sort((a, b) => b.value.amountOwed.compareTo(a.value.amountOwed));

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
                  Text(
                    expense.isPayment
                        ? '$payer paid ${ref.watch(memberNameProvider(expense.paymentRecipient ?? ''))}'
                        : expense.description,
                    style: context.text.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('${cat.name} · ${Dates.dayLabel(expense.date)}', style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Center(child: AmountText(expense.amount, style: context.text.displaySmall, animate: true)),
        if (!expense.isPayment) ...[
          const SizedBox(height: Space.xxs),
          Center(child: Text('Paid by $payer · ${expense.splitMode.label.toLowerCase()}', style: context.text.bodySmall)),
          const SizedBox(height: Space.lg),
          Text('Split', style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          for (final s in shares)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  UserAvatar(uid: s.key, size: 32),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(ref.watch(memberNameProvider(s.key)),
                        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (s.key != expense.payerUid)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.xs),
                      child: s.value.settled
                          ? const Pill('Settled', tone: PillTone.positive, icon: Icons.check_rounded)
                          : const Pill('Owes', tone: PillTone.warning),
                    ),
                  Text(Money.format(s.value.amountOwed),
                      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular)),
                ],
              ),
            ),
          if (expense.items != null && expense.items!.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text('Items', style: context.text.titleSmall),
            for (final item in expense.items!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name, style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    AvatarStack(uids: item.memberUids, size: 22),
                    const SizedBox(width: Space.xs),
                    Text(Money.format(item.amount), style: context.text.bodyMedium?.copyWith(fontFeatures: AppTheme.tabular)),
                  ],
                ),
              ),
          ],
        ],
        if (expense.notes != null && expense.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: Space.md),
          Text('Notes', style: context.text.titleSmall),
          const SizedBox(height: 4),
          Text(expense.notes!, style: context.text.bodyMedium),
        ],
        if (expense.hasReceipt) ...[
          const SizedBox(height: Space.md),
          SecondaryButton(
            label: 'View receipt',
            icon: Icons.receipt_long_rounded,
            onPressed: () => ReceiptViewer.show(
              context,
              receipt: ReceiptRef(groupId: group.groupId, receiptId: expense.receiptId, legacy: expense.legacyReceipt),
              title: expense.description,
            ),
          ),
        ],
        if (activity.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('History', style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          for (final a in activity.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(activityIcon(a.type), size: 16, color: c.textMuted),
                  const SizedBox(width: Space.xs),
                  Expanded(child: Text(a.message, style: context.text.bodySmall?.copyWith(color: c.text))),
                  Text(Dates.relative(a.createdAt), style: context.text.bodySmall),
                ],
              ),
            ),
        ],
        const SizedBox(height: Space.xl),
        if (!expense.isPayment && group.isMember(me))
          PrimaryButton(
            label: 'Edit expense',
            icon: Icons.edit_rounded,
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push('/groups/${group.groupId}/expense/${expense.expenseId}/edit');
            },
          ),
        const SizedBox(height: Space.sm),
        if (group.isMember(me))
          SecondaryButton(
            label: expense.isPayment ? 'Delete payment' : 'Delete expense',
            icon: Icons.delete_outline_rounded,
            color: c.negative,
            onPressed: () async {
              final ok = await confirmAction(
                context,
                title: expense.isPayment ? 'Delete this payment?' : 'Delete this expense?',
                message: expense.isPayment
                    ? 'The debt it cleared will come back for both of you.'
                    : 'Balances update for everyone in ${group.name}. Members will be notified.',
                confirmLabel: 'Delete',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              Navigator.of(context).pop();
              try {
                final outcome = await ref
                    .read(groupExpensesRepositoryProvider)
                    .deleteExpense(group: group, expense: expense);
                Toast.saved(outcome, expense.isPayment ? 'Payment deleted' : 'Expense deleted');
              } catch (e) {
                Toast.error(e);
              }
            },
          ),
      ],
    );
  }
}

IconData activityIcon(String type) => switch (type) {
      GroupActivityModel.expenseAdded => Icons.add_circle_outline_rounded,
      GroupActivityModel.expenseEdited => Icons.edit_outlined,
      GroupActivityModel.expenseDeleted => Icons.delete_outline_rounded,
      GroupActivityModel.settledUp => Icons.handshake_outlined,
      GroupActivityModel.memberJoined => Icons.person_add_alt_rounded,
      GroupActivityModel.memberLeft => Icons.logout_rounded,
      GroupActivityModel.memberRemoved => Icons.person_remove_outlined,
      GroupActivityModel.groupEdited => Icons.drive_file_rename_outline_rounded,
      _ => Icons.history_rounded,
    };
