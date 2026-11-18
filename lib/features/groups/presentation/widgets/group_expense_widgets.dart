import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/domain/split_calculator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/write_helper.dart';
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
import '../../domain/expense_comment.dart';
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
      final fx = expense.fx;
      subtitle = fx == null
          ? '$payer paid ${Money.format(expense.amount)}'
          : '$payer paid ${Currencies.format(fx.amount, fx.currency)} · ${Money.format(expense.amount)}';
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
                      if (expense.commentCount > 0) ...[
                        Icon(Icons.chat_bubble_outline_rounded, size: 14, color: c.textMuted),
                        const SizedBox(width: 2),
                        Text('${expense.commentCount}', style: context.text.bodySmall),
                        const SizedBox(width: 6),
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
          if (expense.fx != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${Currencies.format(expense.fx!.amount, expense.fx!.currency)} at ₹${expense.fx!.rate.toStringAsFixed(expense.fx!.rate < 1 ? 6 : 4).replaceFirst(RegExp(r'\.?0+$'), '')} per ${expense.fx!.currency}',
                  style: context.text.bodySmall,
                ),
              ),
            ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ref.watch(memberNameProvider(s.key)),
                            style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (_sharesNote(expense, s.key) case final note?) Text(note, style: context.text.bodySmall),
                      ],
                    ),
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
            for (final item in expense.fx?.items ?? expense.items!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name, style: context.text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    AvatarStack(uids: item.memberUids, size: 22),
                    const SizedBox(width: Space.xs),
                    Text(Currencies.format(item.amount, expense.fx?.currency),
                        style: context.text.bodyMedium?.copyWith(fontFeatures: AppTheme.tabular)),
                  ],
                ),
              ),
            if ((expense.itemsExtra ?? 0) != 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        expense.itemsExtra! > 0
                            ? 'Tax & charges (shared by what each had)'
                            : 'Discount (shared by what each had)',
                        style: context.text.bodyMedium,
                      ),
                    ),
                    Text(Currencies.format(expense.fx?.itemsExtra ?? expense.itemsExtra!, expense.fx?.currency),
                        style: context.text.bodyMedium?.copyWith(fontFeatures: AppTheme.tabular)),
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
        if (group.isMember(me) || expense.commentCount > 0) ...[
          const SizedBox(height: Space.lg),
          _Comments(group: group, expense: expense, canWrite: group.isMember(me)),
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

/// "2 shares · +₹50" under a person in a by-shares split.
String? _sharesNote(GroupExpenseModel e, String uid) {
  final w = e.shareWeights;
  if (e.splitMode != SplitMode.shares || w == null) return null;
  final shares = w[uid] ?? 0;
  final parts = <String>[
    if (shares > 0) '${shares == shares.roundToDouble() ? shares.toInt() : shares} ${shares == 1 ? 'share' : 'shares'}',
    if ((e.fx?.adjustments ?? e.adjustments)?[uid] case final a? when a > 0)
      '+${Currencies.format(a, e.fx?.currency)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Comments on an expense ("includes tip"). Long-press your own to delete it.
class _Comments extends ConsumerStatefulWidget {
  final GroupModel group;
  final GroupExpenseModel expense;
  final bool canWrite;
  const _Comments({required this.group, required this.expense, required this.canWrite});

  @override
  ConsumerState<_Comments> createState() => _CommentsState();
}

class _CommentsState extends ConsumerState<_Comments> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final outcome = await ref
          .read(groupExpensesRepositoryProvider)
          .addComment(group: widget.group, expense: widget.expense, text: _text.text);
      _text.clear();
      if (outcome == WriteOutcome.pending) Toast.saved(outcome, 'Comment added');
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(ExpenseComment comment) async {
    final ok = await confirmAction(
      context,
      title: 'Delete your comment?',
      message: '"${comment.text.length > 60 ? '${comment.text.substring(0, 60)}…' : comment.text}"',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(groupExpensesRepositoryProvider).deleteComment(
            groupId: widget.group.groupId,
            expenseId: widget.expense.expenseId,
            commentId: comment.id,
          );
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final me = ref.watch(currentUidProvider) ?? '';
    final comments = ref.watch(expenseCommentsProvider((groupId: widget.group.groupId, expenseId: widget.expense.expenseId)));
    final list = comments.valueOrNull ?? const <ExpenseComment>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(list.isEmpty ? 'Comments' : 'Comments · ${list.length}', style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        if (comments.isLoading && list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Space.sm),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (list.isEmpty)
          Text('Add context everyone sees, like "includes tip".', style: context.text.bodySmall),
        for (final cm in list)
          GestureDetector(
            onLongPress: cm.authorUid == me ? () => _delete(cm) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(uid: cm.authorUid, size: 28),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: cm.authorUid == me ? 'You' : ref.watch(memberNameProvider(cm.authorUid)),
                              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: '  ${Dates.relative(cm.createdAt)}', style: context.text.bodySmall),
                          ]),
                        ),
                        Text(cm.text, style: context.text.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (widget.canWrite) ...[
          const SizedBox(height: Space.xs),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  maxLength: ExpenseComment.maxLength,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Add a comment',
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: Space.xs),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: _sending || _text.text.trim().isEmpty ? null : _send,
                icon: _sending
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.onPop))
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
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
