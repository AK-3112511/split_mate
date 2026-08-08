import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_helper.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../data/groups_repository.dart';
import '../data/group_expenses_repository.dart';
import '../domain/group_expense_model.dart';

class GroupInsightsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupInsightsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupInsightsScreen> createState() => _GroupInsightsScreenState();
}

class _GroupInsightsScreenState extends ConsumerState<GroupInsightsScreen> {
  late List<DateTime> _months;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Trailing 6 calendar months
    _months = List.generate(6, (i) {
      return DateTime(now.year, now.month - i, 1);
    }).reversed.toList();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(userCategoriesProvider);
    final groupAsync = ref.watch(groupDetailsStreamProvider(widget.groupId));
    final expensesAsync = ref.watch(groupExpensesStreamProvider(widget.groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: groupAsync.when(
          data: (group) => Text(
            '${group?.name.toUpperCase() ?? "GROUP"} TRENDS',
            style: AppTheme.monoStyle.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 15,
            ),
          ),
          loading: () => Text('LOADING TRENDS...', style: AppTheme.monoStyle.copyWith(fontSize: 15)),
          error: (_, __) => Text('GROUP TRENDS', style: AppTheme.monoStyle.copyWith(fontSize: 15)),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            color: AppTheme.textSecondary.withValues(alpha: 0.1),
            height: 1.0,
            thickness: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: categoriesAsync.when(
          data: (categories) => expensesAsync.when(
            data: (expenses) => _buildContent(categories, expenses),
            loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent))),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          ),
          loading: () => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent))),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildContent(List<CategoryModel> categories, List<GroupExpenseModel> expenses) {
    // 1. Group/Sum expenses by month (filter out soft deleted and templates)
    final Map<String, double> monthlyTotals = {
      for (var m in _months) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0.0,
    };

    for (final exp in expenses) {
      if (exp.isDeleted || exp.isRecurringTemplate || exp.isSettlement) continue;
      final key = '${exp.createdAt.year}-${exp.createdAt.month.toString().padLeft(2, '0')}';
      if (monthlyTotals.containsKey(key)) {
        monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + exp.amount;
      }
    }

    // 2. Filter expenses for the currently selected month
    final selectedKey = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
    final selectedMonthExpenses = expenses.where((exp) {
      if (exp.isDeleted || exp.isRecurringTemplate || exp.isSettlement) return false;
      final key = '${exp.createdAt.year}-${exp.createdAt.month.toString().padLeft(2, '0')}';
      return key == selectedKey;
    }).toList();

    final double selectedMonthTotal = selectedMonthExpenses.fold(0.0, (sum, exp) => sum + exp.amount);

    // 3. Category Breakdown for selected month (resolved via CategoryHelper)
    final categoryGroupMap = CategoryHelper.groupExpensesByCategory(
      items: selectedMonthExpenses,
      getCategoryKey: (exp) => exp.category,
      getAmount: (exp) => exp.amount,
      userCategories: categories,
    );

    final sortedCategoryEntries = categoryGroupMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bar chart card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GROUP SPENDING TREND',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildBarChart(monthlyTotals),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Selected Month Summary Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth).toUpperCase(),
                  style: AppTheme.monoStyle.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'TOTAL: ₹${selectedMonthTotal.toStringAsFixed(2)}',
                  style: AppTheme.monoStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category list breakdown
            if (selectedMonthExpenses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
                child: Center(
                  child: Text(
                    'No group expenses recorded this month.',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sortedCategoryEntries.length,
                  separatorBuilder: (context, index) => Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  itemBuilder: (context, index) {
                    final entry = sortedCategoryEntries[index];
                    final category = entry.key;
                    final sum = entry.value;
                    final catName = category.name;
                    final catColor = category.color;
                    final catIcon = category.icon;
                    final double percentage = selectedMonthTotal > 0 ? sum / selectedMonthTotal : 0.0;

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(catIcon, color: catColor, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                catName.toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '₹${sum.toStringAsFixed(2)}',
                                style: AppTheme.monoStyle.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${ (percentage * 100).toStringAsFixed(1) }%)',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Custom styled horizontal progress indicator
                          ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: LinearProgressIndicator(
                              value: percentage,
                              backgroundColor: AppTheme.textSecondary.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(catColor),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, double> monthlyTotals) {
    final maxAmount = monthlyTotals.values.fold(100.0, (max, val) => val > max ? val : max);
    final double maxY = maxAmount * 1.15;

    final barGroups = List.generate(_months.length, (index) {
      final m = _months[index];
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      final total = monthlyTotals[key] ?? 0.0;
      final isSelected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: total,
            color: isSelected ? AppTheme.accent : AppTheme.accent.withValues(alpha: 0.35),
            width: 18,
            borderRadius: BorderRadius.zero,
          ),
        ],
      );
    });

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: false),
            maxY: maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppTheme.surfaceCard,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '₹${rod.toY.toStringAsFixed(0)}',
                    const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 10),
                  );
                },
              ),
              touchCallback: (FlTouchEvent event, barTouchResponse) {
                if (barTouchResponse == null || barTouchResponse.spot == null) return;
                if (event is FlTapUpEvent) {
                  final index = barTouchResponse.spot!.touchedBarGroupIndex;
                  if (index >= 0 && index < _months.length) {
                    setState(() {
                      _selectedMonth = _months[index];
                    });
                  }
                }
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int idx = value.toInt();
                    if (idx >= 0 && idx < _months.length) {
                      final m = _months[idx];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('MMM').format(m).toUpperCase(),
                          style: AppTheme.monoSecondary.copyWith(
                            fontSize: 10,
                            fontWeight: m.month == _selectedMonth.month && m.year == _selectedMonth.year
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: m.month == _selectedMonth.month && m.year == _selectedMonth.year
                                ? AppTheme.accent
                                : AppTheme.textSecondary,
                          ),
                        ),
                      );
                    }
                    return const Text('');
                  },
                ),
              ),
            ),
            barGroups: barGroups,
          ),
        ).data,
      ),
    );
  }
}
