import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/amount_text.dart';
import '../../../../shared_widgets/avatars.dart';
import '../../../../shared_widgets/bits.dart';
import '../../../../shared_widgets/cards.dart';
import '../../../../shared_widgets/states.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../categories/domain/category_model.dart';
import '../../../categories/domain/category_resolver.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../home/domain/home_stats.dart';
import '../../../home/presentation/widgets/charts.dart';
import '../../data/group_expenses_repository.dart';
import '../../domain/group_expense_model.dart';
import '../../domain/group_model.dart';
import '../widgets/group_expense_widgets.dart';

/// Merged "Group insights" + "Spending breakdown" (v1 had both, plus a ranking).
class StatsTab extends ConsumerWidget {
  final GroupModel group;
  const StatsTab({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final me = ref.watch(currentUidProvider) ?? '';
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final expensesAsync = ref.watch(groupExpensesStreamProvider(group.groupId));

    return Builder(
      builder: (context) => CustomScrollView(
        key: const PageStorageKey('stats'),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          ...expensesAsync.when(
            loading: () => [const SliverToBoxAdapter(child: SkeletonList(count: 3))],
            error: (e, _) => [SliverToBoxAdapter(child: ErrorState(error: e))],
            data: (all) {
              final spending = all.where((e) => !e.isPayment).toList();
              if (spending.isEmpty) {
                return [
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.insights_rounded,
                      title: 'Stats appear once you add expenses',
                    ),
                  ),
                ];
              }
              final total = spending.fold<double>(0, (a, e) => a + e.amount);
              final myShare = spending.fold<double>(0, (a, e) => a + e.shareOf(me));
              final totals = CategoryResolver.totals<GroupExpenseModel>(
                items: spending,
                categoryOf: (e) => groupCategoryOf(e, cats),
                amountOf: (e) => e.amount,
              );
              final byCat = [for (final t in totals) CategoryTotal(t.key, t.value, total <= 0 ? 0 : t.value / total)];
              final now = DateTime.now();
              final months = [
                for (var i = 5; i >= 0; i--)
                  MonthTotal(
                    DateTime(now.year, now.month - i),
                    spending
                        .where((e) => Dates.isSameMonth(e.date, DateTime(now.year, now.month - i)))
                        .fold<double>(0, (a, e) => a + e.amount),
                  ),
              ];
              final paid = <String, double>{};
              final share = <String, double>{};
              for (final e in spending) {
                paid[e.payerUid] = (paid[e.payerUid] ?? 0) + e.amount;
                e.shareByUid.forEach((u, v) => share[u] = (share[u] ?? 0) + v);
              }
              final people = {...group.members, ...paid.keys, ...share.keys}.toList()
                ..sort((a, b) => (paid[b] ?? 0).compareTo(paid[a] ?? 0));

              Widget stat(String label, double v) => Expanded(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: context.text.labelMedium),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AmountText(v, animate: true, style: context.text.titleLarge),
                          ),
                        ],
                      ),
                    ),
                  );

              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                    child: Row(children: [
                      stat('Group spent', total),
                      const SizedBox(width: Space.sm),
                      stat('Your share', myShare),
                    ]),
                  ),
                ),
                const SliverToBoxAdapter(child: SectionHeader('By category')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: AppCard(child: CategoryDonut(totals: byCat, total: total)),
                  ),
                ),
                const SliverToBoxAdapter(child: SectionHeader('Last 6 months')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: AppCard(child: TrendBars(months: months)),
                  ),
                ),
                const SliverToBoxAdapter(child: SectionHeader('Paid vs. share')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: AppCard(
                      child: Column(
                        children: [
                          for (final u in people)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  UserAvatar(uid: u, size: 36),
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(ref.watch(memberNameProvider(u)),
                                            style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        SoftProgressBar(value: total <= 0 ? 0 : (paid[u] ?? 0) / total, height: 6),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: Space.sm),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('paid ${Money.compact(paid[u] ?? 0)}',
                                          style: context.text.labelMedium?.copyWith(color: c.text, fontFeatures: AppTheme.tabular)),
                                      Text('share ${Money.compact(share[u] ?? 0)}',
                                          style: context.text.labelSmall?.copyWith(letterSpacing: 0, fontFeatures: AppTheme.tabular)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
