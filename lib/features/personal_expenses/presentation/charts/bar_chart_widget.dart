import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
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

    // Map categories by ID
    final categoryMap = {for (var c in categories) c.id: c};

    // Calculate sum per category ID
    final Map<String, double> categorySums = {};
    for (var expense in expenses) {
      categorySums[expense.category] =
          (categorySums[expense.category] ?? 0.0) + expense.amount;
    }

    // Create sorted list of category IDs (highest spend first)
    final presentCategoryKeys = categorySums.keys.toList()
      ..sort((a, b) => categorySums[b]!.compareTo(categorySums[a]!));

    final barGroups = List.generate(presentCategoryKeys.length, (index) {
      final key = presentCategoryKeys[index];
      final sum = categorySums[key] ?? 0.0;
      final cat = categoryMap[key];
      final color = cat?.color ?? AppTheme.textSecondary;

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
                      if (index >= 0 && index < presentCategoryKeys.length) {
                        final key = presentCategoryKeys[index];
                        final sum = categorySums[key] ?? 0.0;
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
                // ── BOTTOM: category name only (icon rendered separately) ──
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index >= 0 && index < presentCategoryKeys.length) {
                        final key = presentCategoryKeys[index];
                        final cat = categoryMap[key];
                        final name = cat?.name ?? 'Others';
                        final icon = cat?.icon ?? Icons.category;
                        final color = cat?.color ?? AppTheme.textSecondary;
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
