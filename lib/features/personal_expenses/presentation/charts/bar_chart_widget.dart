import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_helper.dart';
import '../../../categories/domain/category_model.dart';
import '../../domain/expense_model.dart';

class BarChartWidget extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final List<CategoryModel> categories;

  const BarChartWidget({
    super.key,
    required this.expenses,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'No expenses recorded',
            style: AppTheme.monoSecondary.copyWith(fontSize: 14),
          ),
        ),
      );
    }

    // Group and resolve categories using CategoryHelper
    final categoryGroupMap = CategoryHelper.groupExpensesByCategory(
      items: expenses,
      getCategoryKey: (e) => e.category,
      getAmount: (e) => e.amount,
      userCategories: categories,
    );

    // Sort descending by total amount
    final sortedEntries = categoryGroupMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final barGroups = List.generate(sortedEntries.length, (index) {
      final entry = sortedEntries[index];
      final sum = entry.value;
      final cat = entry.key;
      final color = cat.color;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: sum,
            color: color,
            width: 18,
            borderRadius: BorderRadius.zero,
          ),
        ],
      );
    });

    // Format amount: always show exact integer value e.g. ₹1187
    String formatAmount(double amount) {
      return '₹${amount.toStringAsFixed(0)}';
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                // ── TOP: amount value above each bar ──────────────────────
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index >= 0 && index < sortedEntries.length) {
                        final sum = sortedEntries[index].value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            formatAmount(sum),
                            style: AppTheme.monoStyle.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                // ── BOTTOM: category icon + category name ─────────────────
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index >= 0 && index < sortedEntries.length) {
                        final cat = sortedEntries[index].key;
                        final name = cat.name;
                        final icon = cat.icon;
                        final color = cat.color;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: color, size: 16),
                              const SizedBox(height: 3),
                              Text(
                                name.length > 6
                                    ? '${name.substring(0, 5)}.'
                                    : name,
                                style: AppTheme.monoSecondary
                                    .copyWith(fontSize: 9),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }
}
