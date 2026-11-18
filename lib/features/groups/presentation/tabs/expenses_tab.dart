import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/motion.dart';
import '../../../../shared_widgets/states.dart';
import '../../data/group_expenses_repository.dart';
import '../../domain/group_expense_model.dart';
import '../../domain/group_model.dart';
import '../widgets/group_expense_widgets.dart';
import '../widgets/trip_widgets.dart';
import '../../../../core/l10n/strings.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  final GroupModel group;
  const ExpensesTab({super.key, required this.group});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> with AutomaticKeepAliveClientMixin {
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.aurora;
    final expenses = ref.watch(groupExpensesStreamProvider(widget.group.groupId));
    return Builder(
      builder: (context) => CustomScrollView(
        key: const PageStorageKey('expenses'),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          ...expenses.when(
            loading: () => [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: Space.lg), child: SkeletonList()))],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: ErrorState(error: e, onRetry: () => ref.invalidate(groupExpensesStreamProvider(widget.group.groupId))),
              ),
            ],
            data: (all) {
              if (all.isEmpty) {
                return [
                  if (widget.group.isTrip) SliverToBoxAdapter(child: TripCard(group: widget.group)),
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: context.s.noExpensesYet,
                      message: context.s.groupEmptyBody(widget.group.name),
                    ),
                  ),
                ];
              }
              final q = _query.trim().toLowerCase();
              final list = q.isEmpty
                  ? all
                  : all.where((e) => e.description.toLowerCase().contains(q) || e.category.toLowerCase().contains(q)).toList();
              final days = <DateTime, List<GroupExpenseModel>>{};
              for (final e in list) {
                days.putIfAbsent(Dates.startOfDay(e.date), () => []).add(e);
              }
              final keys = days.keys.toList()..sort((a, b) => b.compareTo(a));
              return [
                if (widget.group.isTrip) SliverToBoxAdapter(child: TripCard(group: widget.group)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xs),
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: context.s.searchGroup,
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                if (list.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(icon: Icons.search_off_rounded, title: context.s.noMatches, compact: true),
                  ),
                for (final day in keys) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xxs),
                      child: Row(
                        children: [
                          Text(Dates.dayLabel(day), style: context.text.labelLarge?.copyWith(color: c.textMuted)),
                          const Spacer(),
                          Text(
                            Money.format(days[day]!.where((e) => !e.isPayment).fold<double>(0, (a, e) => a + e.amount)),
                            style: context.text.labelMedium?.copyWith(fontFeatures: AppTheme.tabular),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: days[day]!.length,
                    itemBuilder: (context, i) {
                      final e = days[day]![i];
                      return GroupExpenseTile(
                        expense: e,
                        onTap: () => showGroupExpenseDetail(context, widget.group, e),
                      ).entrance(context, index: i);
                    },
                  ),
                ],
              ];
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
