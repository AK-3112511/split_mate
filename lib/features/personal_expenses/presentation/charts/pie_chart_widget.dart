import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_helper.dart';
import '../../../categories/domain/category_model.dart';
import '../../domain/expense_model.dart';

class PieChartWidget extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final List<CategoryModel> categories;

  const PieChartWidget({
    super.key,
    required this.expenses,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return SizedBox(
        height: 200,
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

    double totalSum = 0;
    categoryGroupMap.forEach((_, sum) => totalSum += sum);
    if (totalSum == 0) totalSum = 1.0; // avoid division by zero

    // Sort categories descending by sum
    final sortedEntries = categoryGroupMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Get largest category info
    String largestCategoryName = 'NONE';
    double largestCategoryPercentage = 0.0;
    
    if (sortedEntries.isNotEmpty) {
      final largestEntry = sortedEntries.first;
      largestCategoryName = largestEntry.key.name.toUpperCase();
      largestCategoryPercentage = (largestEntry.value / totalSum) * 100;
    }

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Build fl_chart sections
    final sections = sortedEntries.map((entry) {
      final cat = entry.key;
      final color = cat.color;
      final value = entry.value;

      return PieChartSectionData(
        color: color,
        value: value,
        title: '', // no title on slices to keep it clean
        radius: 18,
        showTitle: false,
      );
    }).toList();

    return Column(
      children: [
        // Doughnut Chart
        SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 50,
                  sections: sections,
                  startDegreeOffset: -90,
                ),
              ),
              // Centered Text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${largestCategoryPercentage.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    largestCategoryName,
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Custom Legend matching Ledger mockup
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedEntries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = sortedEntries[index];
            final cat = entry.key;
            final name = cat.name;
            final color = cat.color;
            final amount = entry.value;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bullet + Label
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.rectangle, // square bullet matching mockup
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Amount in Monospace
                Text(
                  currencyFormatter.format(amount),
                  style: AppTheme.monoStyle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
