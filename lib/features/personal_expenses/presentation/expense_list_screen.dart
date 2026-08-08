import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/category_helper.dart';
import '../../auth/data/auth_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';
import '../../groups/data/groups_repository.dart';
import 'charts/bar_chart_widget.dart';
import 'charts/pie_chart_widget.dart';
import '../../../core/utils/settlement_algorithm.dart';
import '../../../shared_widgets/receipt_viewer_dialog.dart';

enum DateFilterType { today, thisMonth, allTime, custom }

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  DateFilterType _dateFilter = DateFilterType.today; // Default to daily fresh start
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _selectedCategoryId;
  bool _showPieChart = false;

  String get _activeRangeLabel {
    final now = DateTime.now();
    switch (_dateFilter) {
      case DateFilterType.today:
        return 'TODAY (${DateFormat('dd MMM').format(now).toUpperCase()})';
      case DateFilterType.thisMonth:
        return DateFormat('MMMM yyyy').format(now).toUpperCase();
      case DateFilterType.allTime:
        return 'ALL TIME';
      case DateFilterType.custom:
        if (_customStartDate != null && _customEndDate != null) {
          final s = DateFormat('dd MMM').format(_customStartDate!).toUpperCase();
          final e = DateFormat('dd MMM').format(_customEndDate!).toUpperCase();
          return '$s - $e';
        }
        return 'CUSTOM RANGE';
    }
  }

  List<ExpenseModel> _filterExpenses(List<ExpenseModel> expenses, List<CategoryModel> categories) {
    final now = DateTime.now();

    return expenses.where((expense) {
      if (expense.isRecurringTemplate) return false;
      final date = expense.createdAt;

      // 1. Date Range Filter
      bool matchesDate = false;
      switch (_dateFilter) {
        case DateFilterType.today:
          matchesDate = date.year == now.year && date.month == now.month && date.day == now.day;
          break;
        case DateFilterType.thisMonth:
          matchesDate = date.year == now.year && date.month == now.month;
          break;
        case DateFilterType.allTime:
          matchesDate = true;
          break;
        case DateFilterType.custom:
          final start = _customStartDate != null
              ? DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day)
              : DateTime(2000);
          final end = _customEndDate != null
              ? DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59)
              : DateTime(2100);
          matchesDate = (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
              (date.isBefore(end) || date.isAtSameMomentAs(end));
          break;
      }

      if (!matchesDate) return false;

      // 2. Category Filter
      if (_selectedCategoryId != null) {
        final selectedCat = CategoryHelper.resolveCategory(_selectedCategoryId!, categories);
        final expCat = CategoryHelper.resolveCategory(expense.category, categories);
        if (selectedCat.name.toLowerCase() != expCat.name.toLowerCase() && selectedCat.id != expCat.id) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showFilterSheet(BuildContext context) {
    DateFilterType tempFilter = _dateFilter;
    bool tempShowPie = _showPieChart;
    DateTime? tempStart = _customStartDate;
    DateTime? tempEnd = _customEndDate;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBase,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.tune, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'FILTER & CHART OPTIONS',
                        style: AppTheme.monoStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 20),

                  // Chart Type Selector
                  Text(
                    'CHART TYPE',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOptionButton(
                          icon: Icons.bar_chart,
                          label: 'Bar Chart',
                          isSelected: !tempShowPie,
                          onTap: () => setModalState(() => tempShowPie = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOptionButton(
                          icon: Icons.pie_chart_outline,
                          label: 'Pie Chart',
                          isSelected: tempShowPie,
                          onTap: () => setModalState(() => tempShowPie = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Date Range Options
                  Text(
                    'DATE RANGE',
                    style: AppTheme.monoSecondary.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildOptionButton(
                        icon: Icons.today,
                        label: 'Today',
                        isSelected: tempFilter == DateFilterType.today,
                        onTap: () => setModalState(() => tempFilter = DateFilterType.today),
                      ),
                      _buildOptionButton(
                        icon: Icons.calendar_month_outlined,
                        label: 'This Month',
                        isSelected: tempFilter == DateFilterType.thisMonth,
                        onTap: () => setModalState(() => tempFilter = DateFilterType.thisMonth),
                      ),
                      _buildOptionButton(
                        icon: Icons.all_inclusive,
                        label: 'All Time',
                        isSelected: tempFilter == DateFilterType.allTime,
                        onTap: () => setModalState(() => tempFilter = DateFilterType.allTime),
                      ),
                      _buildOptionButton(
                        icon: Icons.date_range_outlined,
                        label: 'Custom Range',
                        isSelected: tempFilter == DateFilterType.custom,
                        onTap: () => setModalState(() => tempFilter = DateFilterType.custom),
                      ),
                    ],
                  ),

                  // Custom Range Date Pickers
                  if (tempFilter == DateFilterType.custom) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => tempStart = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                tempStart != null ? DateFormat('dd MMM yyyy').format(tempStart!) : 'Start Date',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => tempEnd = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                tempEnd != null ? DateFormat('dd MMM yyyy').format(tempEnd!) : 'End Date',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Apply Button
                  InkWell(
                    onTap: () {
                      setState(() {
                        _dateFilter = tempFilter;
                        _showPieChart = tempShowPie;
                        _customStartDate = tempStart;
                        _customEndDate = tempEnd;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                      ),
                      child: Center(
                        child: Text(
                          'APPLY FILTERS',
                          style: AppTheme.monoStyle.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surfaceCard.withValues(alpha: 0.3),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : AppTheme.textSecondary, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(userCategoriesProvider);
    final expensesAsync = ref.watch(personalExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              color: AppTheme.surfaceCard,
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        title: Text(
          'SplitMate',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: AppTheme.accent),
            tooltip: 'Filter & Options',
            onPressed: () => _showFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: AppTheme.textPrimary),
            onPressed: () => context.push('/personal-insights'),
          ),
        ],
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
            data: (expenses) => _buildBody(categories, expenses),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.black,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        onPressed: () => context.push('/add-expense'),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildBody(List<CategoryModel> categories, List<ExpenseModel> expenses) {
    final categoryMap = {for (var c in categories) c.id: c};
    final activeFilteredExpenses = _filterExpenses(expenses, categories);

    // Calculate total spent in the active date range / filter
    final double totalSpent = activeFilteredExpenses.fold(0.0, (sum, item) => sum + item.amount);

    // Compute This Week and This Month totals
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final double thisWeekSpent = expenses
        .where((e) => !e.isRecurringTemplate && !e.createdAt.isBefore(startOfWeek))
        .fold(0.0, (sum, item) => sum + item.amount);

    final double thisMonthSpent = expenses
        .where((e) => !e.isRecurringTemplate && e.createdAt.year == now.year && e.createdAt.month == now.month)
        .fold(0.0, (sum, item) => sum + item.amount);

    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Net Liquidity Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NET LIQUIDITY',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _activeRangeLabel,
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currencyFormatter.format(totalSpent),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THIS WEEK',
                              style: AppTheme.monoSecondary.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(thisWeekSpent),
                              style: AppTheme.monoStyle.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppTheme.textSecondary.withValues(alpha: 0.15),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THIS MONTH',
                              style: AppTheme.monoSecondary.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(thisMonthSpent),
                              style: AppTheme.monoStyle.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Horizontal Category Filter Chips row
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // ALL Chip
                  _buildFilterChip(
                    label: 'ALL',
                    isSelected: _selectedCategoryId == null,
                    onTap: () => setState(() => _selectedCategoryId = null),
                  ),
                  const SizedBox(width: 8),
                  // Dynamic Category Chips
                  ...categories.map((category) {
                    final isSelected = _selectedCategoryId == category.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildFilterChip(
                        label: category.name.toUpperCase(),
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedCategoryId = category.id),
                      ),
                    );
                  }),
                  // Edit Categories Gear Icon
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary, size: 20),
                    onPressed: () => context.push('/categories'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Distribution Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DISTRIBUTION',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      // Filter Button & Range Label
                      InkWell(
                        onTap: () => _showFilterSheet(context),
                        child: Row(
                          children: [
                            const Icon(Icons.tune, color: AppTheme.accent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _activeRangeLabel,
                              style: AppTheme.monoStyle.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Chart Type Selector Toggle Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _showPieChart = false),
                        child: Text(
                          'BAR',
                          style: AppTheme.monoStyle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: !_showPieChart ? AppTheme.accent : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => setState(() => _showPieChart = true),
                        child: Text(
                          'PIE',
                          style: AppTheme.monoStyle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _showPieChart ? AppTheme.accent : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Dynamic Chart Display
                  _showPieChart
                      ? PieChartWidget(expenses: activeFilteredExpenses, categories: categories)
                      : BarChartWidget(expenses: activeFilteredExpenses, categories: categories),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Journal Entries Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      border: Border(
                        bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'JOURNAL ENTRIES',
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '${activeFilteredExpenses.length} ENTRIES',
                          style: AppTheme.monoStyle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Entries list
                  if (activeFilteredExpenses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No expenses found for this date range.',
                          style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: activeFilteredExpenses.length > 5 ? 330.0 : null,
                      child: Scrollbar(
                        thumbVisibility: activeFilteredExpenses.length > 5,
                        child: ListView.separated(
                          shrinkWrap: activeFilteredExpenses.length <= 5,
                          physics: activeFilteredExpenses.length > 5
                              ? const AlwaysScrollableScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          itemCount: activeFilteredExpenses.length,
                          separatorBuilder: (context, index) => Divider(
                            color: AppTheme.textSecondary.withValues(alpha: 0.15),
                            height: 1.0,
                            thickness: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final expense = activeFilteredExpenses[index];
                            final cat = CategoryHelper.resolveCategory(expense.category, categories);
                            final catColor = cat.color;
                            final catIcon = cat.icon;
                            final catName = cat.name;
                            final formattedDate = _formatExpenseDate(expense.createdAt);

                            return Dismissible(
                              key: Key(expense.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: AppTheme.semanticNegative,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.black),
                              ),
                              onDismissed: (direction) async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final repo = ref.read(expenseRepositoryProvider);
                                // Capture snapshot before deleting
                                final deletedExpense = expense;
                                try {
                                  await repo.deleteExpense(deletedExpense.id);
                                  scaffoldMessenger.hideCurrentSnackBar();
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Expense deleted',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: AppTheme.accent,
                                      duration: const Duration(seconds: 4),
                                      action: SnackBarAction(
                                        label: 'UNDO',
                                        textColor: Colors.black,
                                        onPressed: () async {
                                          try {
                                            // Restore using updateExpense(.set) to preserve original doc ID
                                            await repo.updateExpense(deletedExpense.id, deletedExpense);
                                          } catch (e) {
                                            scaffoldMessenger.showSnackBar(
                                              SnackBar(
                                                content: Text('Could not restore: $e'),
                                                backgroundColor: AppTheme.semanticNegative,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                      backgroundColor: AppTheme.semanticNegative,
                                    ),
                                  );
                                }
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceCard,
                                    border: Border.all(color: catColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Icon(catIcon, color: catColor, size: 20),
                                ),
                                title: Consumer(
                                  builder: (context, ref, child) {
                                    String displayDesc = expense.description.isNotEmpty ? expense.description : catName;
                                    if (expense.isFromGroup && !displayDesc.contains('(')) {
                                      if (expense.sourceGroupId != null && expense.sourceGroupId!.isNotEmpty) {
                                        final group = ref.watch(groupDetailsStreamProvider(expense.sourceGroupId!)).value;
                                        if (group != null && group.name.isNotEmpty) {
                                          displayDesc = '$displayDesc (${group.name})';
                                        }
                                      }
                                    }
                                    return Text(
                                      displayDesc,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    formattedDate,
                                    style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
                                      IconButton(
                                        icon: const Icon(Icons.receipt_long_outlined, color: AppTheme.accent, size: 20),
                                        tooltip: 'View Receipt',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          ReceiptViewerDialog.show(
                                            context,
                                            receiptUrl: expense.receiptUrl!,
                                            description: expense.description.isNotEmpty ? expense.description : catName,
                                            amount: expense.amount,
                                            dateStr: formattedDate,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      currencyFormatter.format(expense.amount),
                                      style: AppTheme.monoStyle.copyWith(
                                        color: AppTheme.accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.surfaceCard,
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTheme.monoStyle.copyWith(
              color: isSelected ? Colors.black : AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _formatExpenseDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'TODAY, ${DateFormat('hh:mm a').format(date)}';
    } else if (expenseDate == yesterday) {
      return 'YESTERDAY, ${DateFormat('hh:mm a').format(date)}';
    } else {
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    }
  }
}
