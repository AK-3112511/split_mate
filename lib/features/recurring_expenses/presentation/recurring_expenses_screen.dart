import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/data/group_expenses_repository.dart';
import '../../groups/domain/group_model.dart';
import '../../groups/domain/group_expense_model.dart';
import '../../categories/data/categories_repository.dart';

class RecurringExpensesScreen extends ConsumerWidget {
  final String? groupId;

  const RecurringExpensesScreen({super.key, this.groupId});

  String _formatNextDate(DateTime? lastGen, String? interval, DateTime created) {
    final DateTime base = lastGen ?? created;
    DateTime next;
    if (interval == 'weekly') {
      next = base.add(const Duration(days: 7));
    } else {
      next = base.add(const Duration(days: 30));
    }
    return DateFormat('MMM dd, yyyy').format(next);
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    String id,
    String description,
    String? targetGroupId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceBase,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'CANCEL RECURRING',
            style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to stop future generation for "$description"? Already generated expense records will not be deleted.',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('NO', style: AppTheme.monoSecondary.copyWith(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'CANCEL RECURRING',
                style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (targetGroupId != null) {
        await ref.read(groupExpensesRepositoryProvider).cancelGroupRecurringExpense(targetGroupId, id);
      } else {
        await ref.read(expenseRepositoryProvider).cancelRecurringExpense(id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recurring expense template cancelled.'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialIndex = groupId != null ? 1 : 0;

    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceBase,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceBase,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'RECURRING EXPENSES',
            style: AppTheme.monoStyle.copyWith(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 15,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: AppTheme.monoStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: AppTheme.monoSecondary.copyWith(fontSize: 12),
            tabs: const [
              Tab(
                icon: Icon(Icons.person_outline, size: 18),
                text: 'PERSONAL',
              ),
              Tab(
                icon: Icon(Icons.groups_outlined, size: 18),
                text: 'GROUPS',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildPersonalTab(context, ref),
              _buildGroupTab(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalTab(BuildContext context, WidgetRef ref) {
    final personalTemplatesAsync = ref.watch(personalTemplatesProvider);
    final categoriesAsync = ref.watch(userCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        final catMap = {for (var c in categories) c.id: c};
        return personalTemplatesAsync.when(
          data: (templates) {
            if (templates.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No active personal recurring schedules.',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: templates.length,
              separatorBuilder: (context, index) => Divider(
                color: AppTheme.textSecondary.withValues(alpha: 0.1),
                height: 1.0,
                thickness: 1.0,
              ),
              itemBuilder: (context, index) {
                final template = templates[index];
                final id = template.id;
                final amount = template.amount;
                final description = template.description;
                final catId = template.category;
                final interval = template.recurrenceInterval;
                final lastGen = template.lastGeneratedDate;
                final created = template.createdAt;

                final category = catMap[catId];
                final catColor = category?.color ?? AppTheme.textSecondary;
                final catIcon = category?.icon ?? Icons.help_outline;

                final nextDate = _formatNextDate(lastGen, interval, created);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: catColor.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Icon(catIcon, color: catColor, size: 20),
                    ),
                  ),
                  title: Text(
                    description.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    key: ValueKey(id),
                    child: Text(
                      '${interval?.toUpperCase() ?? "WEEKLY"} • NEXT RUN: $nextDate',
                      style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                        color: AppTheme.surfaceBase,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        onSelected: (value) {
                          if (value == 'edit') {
                            context.push('/add-expense?expenseId=$id');
                          } else if (value == 'cancel') {
                            _confirmCancel(context, ref, id, description, null);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(
                              'EDIT',
                              style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppTheme.textPrimary),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text(
                              'CANCEL RECURRING',
                              style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppTheme.semanticNegative),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
    );
  }

  Widget _buildGroupTab(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    final categoriesAsync = ref.watch(userCategoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        final catMap = {for (var c in categories) c.id: c};
        return groupsAsync.when(
          data: (groups) {
            if (groups.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'You belong to no active groups.',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Filter by specific groupId if passed in constructor
            final targetGroups = groupId != null
                ? groups.where((g) => g.groupId == groupId).toList()
                : groups;

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: targetGroups.length,
              itemBuilder: (context, index) {
                final group = targetGroups[index];
                return _GroupRecurringSection(
                  group: group,
                  categories: catMap,
                  onConfirmCancel: (id, desc) => _confirmCancel(context, ref, id, desc, group.groupId),
                  formatNextDate: _formatNextDate,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
    );
  }
}

class _GroupRecurringSection extends ConsumerWidget {
  final GroupModel group;
  final Map<String, dynamic> categories;
  final Future<void> Function(String id, String description) onConfirmCancel;
  final String Function(DateTime? lastGen, String? interval, DateTime created) formatNextDate;

  const _GroupRecurringSection({
    required this.group,
    required this.categories,
    required this.onConfirmCancel,
    required this.formatNextDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(groupTemplatesStreamProvider(group.groupId));

    return templatesAsync.when(
      data: (templates) {
        if (templates.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Header Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard.withValues(alpha: 0.3),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.groups, color: AppTheme.accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      group.name.toUpperCase(),
                      style: AppTheme.monoStyle.copyWith(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),

              // Recurring Items for this Group
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: templates.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppTheme.textSecondary.withValues(alpha: 0.1),
                  height: 1.0,
                  thickness: 1.0,
                ),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final id = template.expenseId;
                  final amount = template.amount;
                  final description = template.description;
                  final catId = template.category;
                  final interval = template.recurrenceInterval;
                  final lastGen = template.lastGeneratedDate;
                  final created = template.createdAt;

                  final category = categories[catId];
                  final catColor = category?.color ?? AppTheme.textSecondary;
                  final catIcon = category?.icon ?? Icons.help_outline;

                  final nextDate = formatNextDate(lastGen, interval, created);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: catColor.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Icon(catIcon, color: catColor, size: 20),
                      ),
                    ),
                    title: Text(
                      description.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      key: ValueKey(id),
                      child: Text(
                        'ITEM: ${description.toUpperCase()} • ${interval?.toUpperCase() ?? "WEEKLY"} • NEXT RUN: $nextDate',
                        style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                          color: AppTheme.surfaceBase,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          onSelected: (value) {
                            if (value == 'edit') {
                              context.push('/groups/${group.groupId}/add-expense?expenseId=$id');
                            } else if (value == 'cancel') {
                              onConfirmCancel(id, description);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(
                                'EDIT',
                                style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppTheme.textPrimary),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'cancel',
                              child: Text(
                                'CANCEL RECURRING',
                                style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppTheme.semanticNegative),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
