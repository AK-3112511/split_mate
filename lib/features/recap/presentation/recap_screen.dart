import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../../shared_widgets/amount_text.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/states.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../domain/recap_stats.dart';

/// Story-style monthly recap; the last card can be shared as an image.
class RecapScreen extends ConsumerStatefulWidget {
  final DateTime? month;
  const RecapScreen({super.key, this.month});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  late DateTime _month = widget.month ?? DateTime(DateTime.now().year, DateTime.now().month - 1);
  final _page = PageController();
  final _shareKey = GlobalKey();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _shift(int months) {
    final next = DateTime(_month.year, _month.month + months);
    if (next.isAfter(DateTime.now())) return;
    setState(() {
      _month = next;
      _index = 0;
    });
    if (_page.hasClients) _page.jumpToPage(0);
  }

  Future<void> _share() async {
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/splitmate_recap_${Dates.monthKey(_month)}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'My ${Dates.monthYear(_month)} on SplitMate ✨');
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(personalExpensesProvider);
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final isCurrent = Dates.isSameMonth(_month, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leading: CloseButton(onPressed: () => context.popOrGo('/')),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(tooltip: 'Previous month', onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Text(Dates.monthYear(_month), style: context.text.titleMedium),
            IconButton(
              tooltip: 'Next month',
              onPressed: isCurrent ? null : () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: ErrorState(error: e)),
        data: (all) {
          final stats = RecapStats.compute(all, _month, cats);
          if (stats.isEmpty) {
            return Center(
                child: EmptyState(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Nothing to recap for ${Dates.monthName(_month)}',
                  message: 'Expenses you add will turn into a recap here.',
                ),
            );
          }
          final pages = _pages(context, stats);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Row(
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: Motion.base,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= _index ? context.aurora.ink : Colors.transparent,
                            borderRadius: Radii.round,
                            border: Border.all(color: context.aurora.ink, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: pages,
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
                  child: _index == pages.length - 1
                      ? PrimaryButton(label: 'Share my recap', icon: Icons.ios_share_rounded, onPressed: _share)
                      : PrimaryButton(
                          label: 'Next',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => _page.nextPage(duration: Motion.slow, curve: Motion.enter),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _pages(BuildContext context, RecapStats s) {
    final change = s.change;
    final top = s.topCategory;
    return [
      _Story(
        color: Palette.yellow,
        icon: Icons.payments_rounded,
        kicker: 'In ${Dates.monthName(s.month)} you spent',
        hero: AmountText(s.total, animate: true, style: context.text.displayLarge?.copyWith(color: Palette.ink)),
        caption: change == null
            ? 'across ${s.count} expenses'
            : '${(change.abs() * 100).round()}% ${change > 0 ? 'more' : 'less'} than ${Dates.monthName(DateTime(s.month.year, s.month.month - 1))} · ${s.count} expenses',
      ),
      if (top != null)
        _Story(
          color: top.category.color,
          icon: Icons.emoji_events_rounded,
          kicker: 'Your top category',
          hero: Text(top.category.name, style: context.text.displaySmall?.copyWith(color: Palette.ink)),
          caption: '${Money.format(top.amount)} · ${(top.share * 100).round()}% of your spending',
        ),
      if (s.biggest != null)
        _Story(
          color: Palette.coral,
          icon: Icons.receipt_long_rounded,
          kicker: 'Biggest single spend',
          hero: AmountText(s.biggest!.amount, animate: true, style: context.text.displayMedium?.copyWith(color: Palette.ink)),
          caption: '${s.biggest!.description} · ${Dates.dayLabel(s.biggest!.date)}',
        ),
      _Story(
        color: Palette.mint,
        icon: Icons.eco_rounded,
        kicker: 'No-spend days',
        hero: Text('${s.noSpendDays}', style: context.text.displayLarge?.copyWith(color: Palette.ink)),
        caption: s.longestNoSpendStreak > 1
            ? 'Longest streak: ${s.longestNoSpendStreak} days in a row'
            : 'Every day had at least one expense',
      ),
      _SummaryCard(stats: s, repaintKey: _shareKey),
    ];
  }
}

class _Story extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String kicker;
  final Widget hero;
  final String caption;
  const _Story({required this.color, required this.icon, required this.kicker, required this.hero, required this.caption});

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    Widget a(Widget w, int i) => reduced ? w : w.animate(delay: (120 * i).ms).fadeIn(duration: 500.ms).slideY(begin: 0.15, end: 0);
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: Radii.hero,
          border: Border.all(color: context.aurora.ink, width: Brutal.border),
          boxShadow: context.aurora.hardShadow(6),
        ),
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            a(
                Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Palette.paper,
                      borderRadius: Radii.card,
                      border: Border.all(color: Palette.ink, width: Brutal.border),
                      boxShadow: const [BoxShadow(color: Palette.ink, offset: Offset(4, 4))],
                    ),
                    child: Icon(icon, size: 38, color: Palette.ink),
                  ),
                ),
                0),
            const SizedBox(height: Space.lg),
            a(Text(kicker.toUpperCase(), style: context.text.labelLarge?.copyWith(color: Palette.ink, letterSpacing: 1.2)), 1),
            const SizedBox(height: Space.xs),
            a(FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: hero), 2),
            const SizedBox(height: Space.md),
            a(Text(caption, style: context.text.bodyLarge?.copyWith(color: Palette.ink, fontWeight: FontWeight.w600)), 3),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RecapStats stats;
  final GlobalKey repaintKey;
  const _SummaryCard({required this.stats, required this.repaintKey});

  @override
  Widget build(BuildContext context) {
    const ink = Palette.ink;
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Center(
        child: RepaintBoundary(
          key: repaintKey,
          child: Container(
            decoration: BoxDecoration(
              color: Palette.yellow,
              borderRadius: Radii.hero,
              border: Border.all(color: ink, width: Brutal.border),
              boxShadow: const [BoxShadow(color: ink, offset: Offset(6, 6))],
            ),
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('My ${Dates.monthYear(stats.month)}', style: context.text.titleLarge?.copyWith(color: ink)),
                const SizedBox(height: Space.md),
                Text(Money.format(stats.total), style: context.text.displayMedium?.copyWith(color: ink, fontFeatures: AppTheme.tabular)),
                Text('spent · ${stats.count} expenses · ${Money.format(stats.perDay)}/day',
                    style: context.text.bodyMedium?.copyWith(color: ink)),
                const SizedBox(height: Space.lg),
                for (final t in stats.byCategory.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.xs),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: Palette.paper, borderRadius: Radii.chip, border: Border.all(color: ink, width: 1.5)),
                          child: Icon(t.category.icon, color: ink, size: 18),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(child: Text(t.category.name, style: context.text.bodyLarge?.copyWith(color: ink))),
                        Text('${(t.share * 100).round()}%', style: context.text.labelLarge?.copyWith(color: ink)),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    const Icon(Icons.eco_rounded, size: 18, color: ink),
                    const SizedBox(width: 4),
                    Text('${stats.noSpendDays} no-spend days', style: context.text.bodyMedium?.copyWith(color: ink)),
                  ],
                ),
                const SizedBox(height: Space.lg),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 20, color: ink),
                    const SizedBox(width: Space.xs),
                    Text('SplitMate', style: context.text.labelLarge?.copyWith(color: ink)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
