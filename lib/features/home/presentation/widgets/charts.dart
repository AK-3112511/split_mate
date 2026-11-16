import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/bits.dart';
import '../../domain/home_stats.dart';

/// Donut with the total in the middle + a tappable legend.
class CategoryDonut extends StatefulWidget {
  final List<CategoryTotal> totals;
  final double total;
  final ValueChanged<String>? onCategoryTap;
  const CategoryDonut({super.key, required this.totals, required this.total, this.onCategoryTap});

  @override
  State<CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends State<CategoryDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final top = widget.totals.take(6).toList();
    final restAmount = widget.totals.skip(6).fold<double>(0, (a, t) => a + t.amount);
    final selected = _touched >= 0 && _touched < top.length ? top[_touched] : null;
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 62,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, resp) {
                      if (!event.isInterestedForInteractions || resp?.touchedSection == null) {
                        if (_touched != -1) setState(() => _touched = -1);
                        return;
                      }
                      setState(() => _touched = resp!.touchedSection!.touchedSectionIndex);
                    },
                  ),
                  sections: [
                    for (var i = 0; i < top.length; i++)
                      PieChartSectionData(
                        value: top[i].amount,
                        color: top[i].category.color,
                        radius: i == _touched ? 34 : 28,
                        showTitle: false,
                        borderSide: BorderSide(color: c.ink, width: 2),
                      ),
                    if (restAmount > 0)
                      PieChartSectionData(
                        value: restAmount,
                        color: c.surfaceHigh,
                        radius: 28,
                        showTitle: false,
                        borderSide: BorderSide(color: c.ink, width: 2),
                      ),
                  ],
                ),
                duration: Motion.slow,
                curve: Motion.enter,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(selected?.category.name ?? 'Total', style: context.text.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 112,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Money.compact(selected?.amount ?? widget.total),
                        style: context.text.titleLarge?.copyWith(fontFeatures: AppTheme.tabular),
                      ),
                    ),
                  ),
                  if (selected != null)
                    Text('${(selected.share * 100).toStringAsFixed(0)}%', style: context.text.labelMedium),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        CategoryLegend(totals: widget.totals, onTap: widget.onCategoryTap),
      ],
    );
  }
}

/// Rows of category → amount with a proportion bar.
class CategoryLegend extends StatelessWidget {
  final List<CategoryTotal> totals;
  final ValueChanged<String>? onTap;
  final int max;
  const CategoryLegend({super.key, required this.totals, this.onTap, this.max = 5});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Column(
      children: [
        for (final t in totals.take(max))
          InkWell(
            borderRadius: Radii.tile,
            onTap: onTap == null ? null : () => onTap!(t.category.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                children: [
                  CategoryBubble(t.category, size: 32),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(t.category.name,
                                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(Money.format(t.amount),
                                style: context.text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700, fontFeatures: AppTheme.tabular)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(child: SoftProgressBar(value: t.share, color: t.category.color, height: 6)),
                            const SizedBox(width: Space.xs),
                            SizedBox(
                              width: 38,
                              child: Text('${(t.share * 100).toStringAsFixed(0)}%',
                                  textAlign: TextAlign.right,
                                  style: context.text.labelSmall?.copyWith(color: c.textMuted, letterSpacing: 0)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 6-month spending bars; tap a bar to select that month.
class TrendBars extends StatelessWidget {
  final List<MonthTotal> months;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;
  const TrendBars({super.key, required this.months, this.selected, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final maxY = months.fold<double>(0, (a, m) => m.amount > a ? m.amount : a);
    final top = maxY <= 0 ? 100.0 : maxY * 1.25;
    return SizedBox(
      height: 170,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= months.length || months[i].amount <= 0) return const SizedBox.shrink();
                  return Text(Money.compact(months[i].amount),
                      style: context.text.labelSmall?.copyWith(letterSpacing: 0, fontSize: 11));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= months.length) return const SizedBox.shrink();
                  final isSel = selected != null && Dates.isSameMonth(months[i].month, selected!);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(Dates.monthShort(months[i].month),
                        style: context.text.labelMedium?.copyWith(
                          color: isSel ? c.primary : c.textMuted,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                        )),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: onSelect != null,
            handleBuiltInTouches: false,
            touchCallback: (event, resp) {
              if (event is FlTapUpEvent && resp?.spot != null) {
                onSelect?.call(months[resp!.spot!.touchedBarGroupIndex].month);
              }
            },
          ),
          barGroups: [
            for (var i = 0; i < months.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: months[i].amount,
                  width: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                  color: (selected == null && i == months.length - 1) ||
                          (selected != null && Dates.isSameMonth(months[i].month, selected!))
                      ? c.cta
                      : Palette.violet,
                  borderSide: BorderSide(color: c.ink, width: 2),
                  backDrawRodData: BackgroundBarChartRodData(show: false),
                ),
              ]),
          ],
        ),
        duration: Motion.slow,
        curve: Motion.enter,
      ),
    );
  }
}
