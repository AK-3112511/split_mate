import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/avatars.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../../friends/data/friends_repository.dart';
import '../data/balances_providers.dart';
import '../data/group_expenses_repository.dart';
import '../data/groups_repository.dart';
import '../domain/group_expense_model.dart';
import '../domain/group_model.dart';
import '../domain/trip_summary.dart';
import 'tabs/balances_tab.dart';
import 'widgets/group_expense_widgets.dart';
import 'widgets/trip_widgets.dart';

/// End-of-trip story: totals, who spent what, top categories, and the fewest
/// payments that settle everything.
class TripSummaryScreen extends ConsumerStatefulWidget {
  final String groupId;
  const TripSummaryScreen({super.key, required this.groupId});

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share(GroupModel group) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/splitmate_${group.groupId}_trip.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '${group.name}, the numbers. Split on SplitMate.');
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(groupDetailsStreamProvider(widget.groupId)).valueOrNull;
    final expensesAsync = ref.watch(groupExpensesStreamProvider(widget.groupId));
    final me = ref.watch(currentUidProvider) ?? '';
    if (group == null || !expensesAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.popOrGo('/groups/${widget.groupId}'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final expenses = expensesAsync.value!;
    final summary = TripSummary.compute(group, expenses);
    final balances = ref.watch(groupBalancesProvider(group.groupId)).valueOrNull;
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final spending = expenses.where((e) => !e.isPayment).toList();
    final byCat = CategoryResolver.totals<GroupExpenseModel>(
      items: spending,
      categoryOf: (e) => groupCategoryOf(e, cats),
      amountOf: (e) => e.amount,
    );
    final people = {...summary.shareByUid.keys, ...summary.paidByUid.keys}.toList()
      ..sort((a, b) => (summary.shareByUid[b] ?? 0).compareTo(summary.shareByUid[a] ?? 0));
    final settle = balances?.simplified ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrGo('/groups/${group.groupId}')),
        title: const Text('Trip summary'),
        actions: [
          IconButton(
            tooltip: 'Share the summary',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: spending.isEmpty || _sharing ? null : () => _share(group),
          ),
          if (group.isAdmin(me))
            IconButton(
              tooltip: 'Trip dates & currency',
              icon: const Icon(Icons.edit_calendar_rounded),
              onPressed: () => showTripSettingsSheet(context, group),
            ),
        ],
      ),
      body: spending.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.luggage_rounded,
                title: 'Nothing spent yet',
                message: 'Add expenses as you go. The summary builds itself.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
              children: [
                RepaintBoundary(
                  key: _cardKey,
                  child: _HeroCard(group: group, summary: summary, topCategories: byCat.take(3).toList()),
                ),
                const SizedBox(height: Space.xl),
                Text('Settle everything', style: context.text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  settle.isEmpty
                      ? 'Nobody owes anybody. Nice.'
                      : 'The fewest payments that clear the whole trip (${settle.length} '
                            '${settle.length == 1 ? 'payment' : 'payments'}). Pay, show your QR, or record cash.',
                  style: context.text.bodySmall,
                ),
                if (settle.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.md),
                    child: Center(
                      child: Pill('All settled', tone: PillTone.positive, icon: Icons.check_rounded),
                    ),
                  )
                else
                  for (final d in settle)
                    DebtCard(
                      group: group,
                      debt: d,
                      me: me,
                      expenses: expenses,
                      padding: const EdgeInsets.only(top: Space.sm),
                    ),
                const SizedBox(height: Space.xl),
                Text('Who spent what', style: context.text.titleMedium),
                const SizedBox(height: Space.xs),
                AppCard(
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
                                    Text(
                                      u == me ? 'You' : ref.watch(memberNameProvider(u)),
                                      style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'paid ${Money.format(summary.paidByUid[u] ?? 0)} up front',
                                      style: context.text.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Money.format(summary.shareByUid[u] ?? 0),
                                style: context.text.titleSmall?.copyWith(fontFeatures: AppTheme.tabular),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text('Amounts are what each person\'s share of the trip came to.', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// The shareable card: trip name, dates, totals and highlights.
class _HeroCard extends ConsumerWidget {
  final GroupModel group;
  final TripSummary summary;
  final List<MapEntry<CategoryModel, double>> topCategories;
  const _HeroCard({required this.group, required this.summary, required this.topCategories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final pop = Palette.popFor(group.groupId);
    final ink = c.onPop;
    final biggest = summary.biggest;
    Widget stat(String label, String value, {int flex = 3}) => Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.labelMedium?.copyWith(color: ink)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.text.titleLarge?.copyWith(
                color: ink,
                fontWeight: FontWeight.w800,
                fontFeatures: AppTheme.tabular,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: pop,
        borderRadius: Radii.card,
        border: Border.all(color: Palette.ink, width: Brutal.border),
        boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(5, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.luggage_rounded, color: ink),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  group.name,
                  style: context.text.headlineSmall?.copyWith(color: ink, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (group.isTrip)
            Text(
              '${TripSummary.dateRange(group.tripStart!, group.tripEnd!)} · ${group.tripDays} ${group.tripDays == 1 ? 'day' : 'days'}',
              style: context.text.bodyMedium?.copyWith(color: ink),
            ),
          const SizedBox(height: Space.md),
          Text('Spent together', style: context.text.labelMedium?.copyWith(color: ink)),
          Text(
            Money.format(summary.total),
            style: context.text.displaySmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w800,
              fontFeatures: AppTheme.tabular,
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              stat('Per day', Money.format(summary.perDay)),
              const SizedBox(width: Space.sm),
              stat('Per person', Money.format(summary.perPerson)),
              const SizedBox(width: Space.sm),
              stat('Expenses', '${summary.expenseCount}', flex: 2),
            ],
          ),
          if (biggest != null || summary.busiestDay != null) ...[
            const SizedBox(height: Space.md),
            Divider(color: ink.withValues(alpha: 0.4), height: 1),
            const SizedBox(height: Space.sm),
          ],
          if (biggest != null)
            _line(
              context,
              Icons.emoji_events_rounded,
              'Biggest: ${biggest.description} · ${Money.format(biggest.amount)}',
              ink,
            ),
          if (summary.busiestDay != null)
            _line(
              context,
              Icons.local_fire_department_rounded,
              'Busiest day: ${Dates.full(summary.busiestDay!)} · ${Money.format(summary.busiestDayTotal)}',
              ink,
            ),
          for (final t in topCategories) _line(context, t.key.icon, '${t.key.name} · ${Money.format(t.value)}', ink),
          if (summary.currencies.isNotEmpty)
            _line(context, Icons.currency_exchange_rounded, 'Also paid in ${summary.currencies.join(', ')}', ink),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text, Color ink) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(icon, size: 18, color: ink),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(
            text,
            style: context.text.bodyMedium?.copyWith(color: ink, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
