import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/initials.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/amount_text.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/inputs.dart';
import '../../../shared_widgets/motion.dart';
import '../../../shared_widgets/progress_ring.dart';
import '../../../shared_widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../groups/data/balances_providers.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../personal_expenses/domain/expense_model.dart';
import '../../personal_expenses/presentation/expense_actions.dart';
import '../../personal_expenses/presentation/expense_tile.dart';
import '../domain/home_stats.dart';
import 'widgets/charts.dart';
import 'widgets/get_started_card.dart';
import '../../../core/l10n/strings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  RangeKind _kind = RangeKind.month;
  DateTime? _from;
  DateTime? _to;
  String? _categoryId;
  bool _donut = true;

  /// Ids swiped away but not yet gone from the stream (keeps Dismissible happy).
  final Set<String> _dismissed = {};

  DateRange get _range => DateRange.of(_kind, from: _from, to: _to);

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return context.s.greetLate;
    if (h < 12) return context.s.greetMorning;
    if (h < 17) return context.s.greetAfternoon;
    return context.s.greetEvening;
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: now,
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      helpText: context.s.chooseDates,
    );
    if (picked == null) return;
    setState(() {
      _kind = RangeKind.custom;
      _from = picked.start;
      _to = picked.end;
    });
  }

  void _selectMonth(DateTime m) {
    setState(() {
      _kind = RangeKind.custom;
      _from = Dates.startOfMonth(m);
      _to = Dates.startOfNextMonth(m).subtract(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(personalExpensesProvider);
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            // Streams are live; pull-to-refresh just re-subscribes (useful after offline).
            onRefresh: () async {
              ref.invalidate(personalExpensesProvider);
              await Future<void>.delayed(const Duration(milliseconds: 400));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(child: _Header(greeting: _greeting())),
                ...expensesAsync.when(
                  loading: () => [
                    const SliverToBoxAdapter(child: _HeroSkeleton()),
                    const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
                    const SliverToBoxAdapter(child: SkeletonList()),
                  ],
                  error: (e, _) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: ErrorState(error: e, onRetry: () => ref.invalidate(personalExpensesProvider)),
                      ),
                    ),
                  ],
                  data: (all) => _content(context, all, cats),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 140)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _AddFab(onTap: () => context.push('/expense/new')),
    );
  }

  List<Widget> _content(BuildContext context, List<ExpenseModel> all, List<CategoryModel> cats) {
    final visible = all.where((e) => !_dismissed.contains(e.id)).toList();
    final range = _range;
    final inRange = HomeStats.inRange(visible, range, categoryId: _categoryId, cats: cats);
    final rangeAll = _categoryId == null ? inRange : HomeStats.inRange(visible, range, cats: cats);
    final rangeTotal = HomeStats.total(inRange);
    final byCat = HomeStats.byCategory(rangeAll, cats);
    final budgets = HomeStats.budgets(visible, cats);
    final months = HomeStats.monthly(visible);
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final showRecap = now.day <= 7 && visible.any((e) => Dates.isSameMonth(e.date, lastMonth));

    if (all.isEmpty) {
      return [
        const SliverToBoxAdapter(child: GetStartedCard()),
      SliverToBoxAdapter(child: _HeroCard(expenses: visible).entrance(context)),
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.receipt_long_rounded,
            title: context.s.startTracking,
            message: context.s.startTrackingBody,
            actionLabel: context.s.addExpense,
            actionIcon: Icons.add_rounded,
            onAction: () => context.push('/expense/new'),
          ),
        ),
      ];
    }

    return [
      const SliverToBoxAdapter(child: GetStartedCard()),
      SliverToBoxAdapter(child: _HeroCard(expenses: visible).entrance(context)),
      if (showRecap)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
            child: _RecapCard(month: lastMonth),
          ).entrance(context, index: 1),
        ),
      SliverToBoxAdapter(child: _BudgetsStrip(budgets: budgets, hasCategories: cats.isNotEmpty)),
      SliverToBoxAdapter(child: _filters(context, cats)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
          child: AppCard(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(range.label, style: context.text.labelMedium),
                          const SizedBox(height: 2),
                          AmountText(rangeTotal,
                              style: context.text.headlineMedium, animate: true),
                        ],
                      ),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: true, icon: Icon(Icons.donut_large_rounded, size: 18), tooltip: 'Donut'),
                        ButtonSegment(value: false, icon: Icon(Icons.bar_chart_rounded, size: 18), tooltip: 'List'),
                      ],
                      selected: {_donut},
                      onSelectionChanged: (s) => setState(() => _donut = s.first),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                AnimatedSwitcher(
                  duration: Motion.base,
                  child: byCat.isEmpty
                      ? Padding(
                          key: const ValueKey('empty'),
                          padding: const EdgeInsets.symmetric(vertical: Space.lg),
                          child: Center(
                            child: Text(context.s.nothingThisPeriod, style: context.text.bodyMedium?.copyWith(color: context.aurora.textMuted)),
                          ),
                        )
                      : _donut
                          ? CategoryDonut(
                              key: const ValueKey('donut'),
                              totals: byCat,
                              total: HomeStats.total(rangeAll),
                              onCategoryTap: (id) => setState(() => _categoryId = _categoryId == id ? null : id),
                            )
                          : CategoryLegend(
                              key: const ValueKey('list'),
                              totals: byCat,
                              max: 20,
                              onTap: (id) => setState(() => _categoryId = _categoryId == id ? null : id),
                            ),
                ),
              ],
            ),
          ).entrance(context, index: 2),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          context.s.trends,
          trailing: Text(context.s.last6Months, style: context.text.labelMedium),
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xs),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(Space.sm, Space.md, Space.sm, Space.sm),
            child: TrendBars(
              months: months,
              selected: _kind == RangeKind.custom && _from != null && _from!.day == 1 ? _from : null,
              onSelect: _selectMonth,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          _categoryId == null ? context.s.expenses : '${context.s.expenses} · ${cats.firstWhere((c) => c.id == _categoryId, orElse: () => CategoryModel.others).name}',
          actionLabel: inRange.isEmpty ? null : context.s.search,
          onAction: () => context.push('/search'),
        ),
      ),
      if (inRange.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            compact: true,
            icon: Icons.event_busy_rounded,
            title: switch (range.kind) {
              RangeKind.all => context.s.noExpensesYet,
              RangeKind.today => context.s.noExpensesToday,
              _ => 'No expenses in ${range.label}',
            },
            message: context.s.tryAnotherRange,
            actionLabel: context.s.addExpense,
            onAction: () => context.push('/expense/new'),
          ),
        )
      else
        ..._dayGroups(context, inRange),
    ];
  }

  Widget _filters(BuildContext context, List<CategoryModel> cats) {
    final c = context.aurora;
    final chips = <Widget>[
      ChoiceChipX(label: context.s.rangeAllTime, selected: _kind == RangeKind.all, onTap: () => setState(() => _kind = RangeKind.all)),
      ChoiceChipX(label: context.s.today, selected: _kind == RangeKind.today, onTap: () => setState(() => _kind = RangeKind.today)),
      ChoiceChipX(label: context.s.rangeWeek, selected: _kind == RangeKind.week, onTap: () => setState(() => _kind = RangeKind.week)),
      ChoiceChipX(label: context.s.rangeMonth, selected: _kind == RangeKind.month, onTap: () => setState(() => _kind = RangeKind.month)),
      ChoiceChipX(
        label: _kind == RangeKind.custom ? _range.label : context.s.rangeCustom,
        icon: Icons.date_range_rounded,
        selected: _kind == RangeKind.custom,
        onTap: _pickCustom,
      ),
    ];
    return Column(
      children: [
        const SizedBox(height: Space.lg),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.xs),
            itemBuilder: (_, i) => chips[i],
          ),
        ),
        const SizedBox(height: Space.xs),
        SizedBox(
          height: 40,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            scrollDirection: Axis.horizontal,
            children: [
              ChoiceChipX(label: context.s.allCategories, selected: _categoryId == null, onTap: () => setState(() => _categoryId = null)),
              for (final cat in cats) ...[
                const SizedBox(width: Space.xs),
                ChoiceChipX(
                  label: cat.name,
                  icon: cat.icon,
                  color: cat.color,
                  selected: _categoryId == cat.id,
                  onTap: () => setState(() => _categoryId = _categoryId == cat.id ? null : cat.id),
                ),
              ],
              const SizedBox(width: Space.xs),
              ActionChip(
                avatar: Icon(Icons.tune_rounded, size: 16, color: c.textMuted),
                label: Text(context.s.manage),
                onPressed: () => context.push('/categories'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _dayGroups(BuildContext context, List<ExpenseModel> list) {
    final c = context.aurora;
    final groups = HomeStats.byDay(list);
    final out = <Widget>[];
    for (final g in groups) {
      final dayTotal = HomeStats.total(g.value);
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xxs),
          child: Row(
            children: [
              Text(Dates.dayLabel(g.key), style: context.text.labelLarge?.copyWith(color: c.textMuted)),
              const Spacer(),
              Text(Money.format(dayTotal),
                  style: context.text.labelMedium?.copyWith(fontFeatures: AppTheme.tabular)),
            ],
          ),
        ),
      ));
      out.add(SliverList.builder(
        itemCount: g.value.length,
        itemBuilder: (context, i) {
          final e = g.value[i];
          final tile = Dismissible(
            key: ValueKey('exp-${e.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: Space.xl),
              color: c.negative.withValues(alpha: 0.15),
              child: Icon(Icons.delete_outline_rounded, color: c.negative),
            ),
            onDismissed: (_) {
              setState(() => _dismissed.add(e.id));
              deleteExpenseWithUndo(ref, e).whenComplete(() {
                if (mounted) setState(() => _dismissed.remove(e.id));
              });
            },
            child: ExpenseTile(expense: e, onTap: () => showExpenseDetail(context, e)),
          );
          return tile.entrance(context, index: i);
        },
      ));
    }
    return out;
  }
}

class _Header extends ConsumerWidget {
  final String greeting;
  const _Header({required this.greeting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final unread = ref.watch(unreadNotificationCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting 👋', style: context.text.labelMedium),
                const SizedBox(height: 2),
                Text(
                  firstNameOf(profile?.displayName, fallback: 'there'),
                  style: context.text.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TonalIconButton(icon: Icons.search_rounded, tooltip: context.s.search, onPressed: () => context.push('/search')),
          const SizedBox(width: Space.xs),
          TonalIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: context.s.notifications,
            badge: unread,
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends ConsumerWidget {
  final List<ExpenseModel> expenses;
  const _HeroCard({required this.expenses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final now = DateTime.now();
    final month = HomeStats.total(expenses.where((e) => Dates.isSameMonth(e.date, now)));
    final trend = HomeStats.monthTrend(expenses);
    final balance = ref.watch(overallBalanceProvider);

    Widget stat(String label, double v, IconData icon, Color fill) => Expanded(
          child: PopTile(
            color: fill,
            onTap: () => context.go('/groups'),
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.toUpperCase(),
                          style: context.text.labelSmall?.copyWith(color: c.onPop, letterSpacing: 0.8)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(Money.format(v),
                            style: context.text.titleMedium?.copyWith(color: c.onPop, fontFeatures: AppTheme.tabular)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        children: [
          GradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.s.spentIn(Dates.monthName(now).toUpperCase()),
                    style: context.text.labelSmall?.copyWith(color: c.onPop, letterSpacing: 1.4)),
                const SizedBox(height: Space.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AmountText(
                    month,
                    animate: true,
                    style: context.text.displayLarge?.copyWith(color: c.onPop),
                  ),
                ),
                if (trend != null) ...[
                  const SizedBox(height: Space.xs),
                  Pill(
                    context.s.vsLastMonth('${trend > 0 ? '+' : '-'}${(trend.abs() * 100).round()}%'),
                    tone: trend > 0 ? PillTone.negative : PillTone.positive,
                    icon: trend > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              stat(context.s.youAreOwed, balance.owedToMe, Icons.south_west_rounded, c.positiveFill),
              const SizedBox(width: Space.md),
              stat(context.s.youOwe, balance.iOwe, Icons.north_east_rounded, c.negativeFill),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Skeleton(child: SkeletonBox(height: 190, borderRadius: Radii.hero)),
      );
}

class _RecapCard extends StatelessWidget {
  final DateTime month;
  const _RecapCard({required this.month});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return AppCard(
      onTap: () => context.push('/recap?month=${Dates.monthKey(month)}-01'),
      child: Row(
        children: [
          const IconBadge(Icons.auto_awesome_rounded, size: 44),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.s.recapReady(Dates.monthName(month)), style: context.text.titleSmall),
                Text(context.s.recapBody, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}

class _BudgetsStrip extends StatelessWidget {
  final List<BudgetStatus> budgets;
  final bool hasCategories;
  const _BudgetsStrip({required this.budgets, required this.hasCategories});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    if (budgets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
        child: AppCard(
          onTap: () => context.push('/categories'),
          child: Row(
            children: [
              IconBadge(Icons.savings_rounded, size: 44, color: c.positive),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.s.setBudget, style: context.text.titleSmall),
                    Text(context.s.setBudgetBody, style: context.text.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(context.s.budgets, actionLabel: context.s.edit, onAction: () => context.push('/categories')),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            scrollDirection: Axis.horizontal,
            itemCount: budgets.length,
            separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
            itemBuilder: (context, i) {
              final b = budgets[i];
              final color = b.over ? c.negative : (b.warning ? c.warning : b.category.color);
              return SizedBox(
                width: 132,
                child: AppCard(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Column(
                    children: [
                      ProgressRing(
                        value: b.ratio,
                        color: color,
                        size: 62,
                        child: Icon(b.category.icon, color: color, size: 24),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(b.category.name, style: context.text.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        b.over ? '${Money.compact(-b.left)} over' : '${Money.compact(b.left)} left',
                        style: context.text.labelMedium?.copyWith(color: b.over ? c.negative : c.textMuted),
                      ),
                    ],
                  ),
                ).entrance(context, index: i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AddFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return BrutalSurface(
      color: c.cta,
      borderRadius: Radii.tile,
      onTap: onTap,
      semanticLabel: context.s.addExpense,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: SizedBox(
        height: 54,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: c.onPop, size: 26),
            const SizedBox(width: Space.xs),
            Text(context.s.addExpense, style: context.text.labelLarge?.copyWith(color: c.onPop, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
