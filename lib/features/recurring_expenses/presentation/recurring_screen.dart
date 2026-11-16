import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/domain/recurrence.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/states.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../categories/domain/category_resolver.dart';
import '../../groups/data/group_expenses_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group_expense_model.dart';
import '../../groups/domain/group_model.dart';
import '../../groups/presentation/widgets/group_expense_widgets.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../personal_expenses/domain/expense_model.dart';

/// Personal + group recurring templates with correct "next on" dates.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.popOrGo('/profile')),
          title: const Text('Recurring'),
          bottom: const TabBar(
            padding: EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xs,
            ),
            tabs: [
              Tab(text: 'Personal'),
              Tab(text: 'Groups'),
            ],
          ),
        ),
        body: const TabBarView(children: [_PersonalTab(), _GroupsTab()]),
        floatingActionButton: Builder(
          builder: (context) => PopFab(
            icon: Icons.add_rounded,
            label: 'New',
            onPressed: () {
              if (DefaultTabController.of(context).index == 0) {
                context.push('/expense/new?recurring=1');
              } else {
                _pickGroup(context, ref);
              }
            },
          ),
        ),
      ),
    );
  }

  void _pickGroup(BuildContext context, WidgetRef ref) {
    final groups =
        ref.read(groupsStreamProvider).valueOrNull ?? const <GroupModel>[];
    if (groups.isEmpty) {
      Toast.info('Create or join a group first');
      return;
    }
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetBody(
        title: 'Which group?',
        children: [
          for (final g in groups)
            ListTile(
              leading: const IconBadge(Icons.groups_rounded, size: 40),
              title: Text(g.name),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/groups/${g.groupId}/expense/new?recurring=1');
              },
            ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final CategoryModel category;
  final String title;
  final double amount;
  final RecurrenceInterval? interval;
  final DateTime start;
  final DateTime? lastGenerated;
  final bool paused;
  final String? subtitle;
  final VoidCallback onEdit;
  final VoidCallback onTogglePause;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.category,
    required this.title,
    required this.amount,
    required this.interval,
    required this.start,
    required this.lastGenerated,
    required this.paused,
    required this.onEdit,
    required this.onTogglePause,
    required this.onDelete,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final next = interval == null
        ? null
        : Recurrence.nextOccurrence(
            start: start,
            interval: interval!,
            lastGenerated: lastGenerated,
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.sm,
      ),
      child: Opacity(
        opacity: paused ? 0.6 : 1,
        child: AppCard(
          onTap: onEdit,
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.sm,
            Space.xxs,
            Space.sm,
          ),
          child: Row(
            children: [
              CategoryBubble(category),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        interval?.label ?? 'Repeats',
                        if (paused)
                          'Paused'
                        else if (next != null)
                          'next ${Dates.dayLabel(next)}',
                        if (subtitle != null) subtitle!,
                      ].join(' · '),
                      style: context.text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                Money.format(amount),
                style: context.text.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTheme.tabular,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                onSelected: (v) => switch (v) {
                  'edit' => onEdit(),
                  'pause' => onTogglePause(),
                  _ => onDelete(),
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'pause',
                    child: Text(paused ? 'Resume' : 'Pause'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: c.negative)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalTab extends ConsumerWidget {
  const _PersonalTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats =
        ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final templates = ref.watch(personalTemplatesProvider);
    final repo = ref.read(expenseRepositoryProvider);
    return templates.when(
      loading: () => const SkeletonList(),
      error: (e, _) => Center(child: ErrorState(error: e)),
      data: (list) => list.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.autorenew_rounded,
                title: 'No recurring expenses',
                message:
                    'Rent, subscriptions and bills can add themselves every week or month.',
                actionLabel: 'Set one up',
                onAction: () => context.push('/expense/new?recurring=1'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(top: Space.md, bottom: 120),
              children: [
                for (final ExpenseModel t in list)
                  _TemplateCard(
                    category: CategoryResolver.resolve(
                      id: t.categoryId,
                      name: t.categoryName,
                      categories: cats,
                    ),
                    title: t.description,
                    amount: t.amount,
                    interval: t.interval,
                    start: t.date,
                    lastGenerated: t.lastGeneratedDate,
                    paused: t.isCancelled,
                    onEdit: () => context.push('/expense/${t.id}/edit'),
                    onTogglePause: () async {
                      try {
                        await repo.setTemplatePaused(
                          t.id,
                          paused: !t.isCancelled,
                        );
                        Toast.success(t.isCancelled ? 'Resumed' : 'Paused');
                      } catch (e) {
                        Toast.error(e);
                      }
                    },
                    onDelete: () async {
                      final ok = await confirmAction(
                        context,
                        title: 'Delete "${t.description}"?',
                        message:
                            'Expenses it already added stay in your history.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                      if (!ok) return;
                      try {
                        await repo.deleteTemplate(t.id);
                        Toast.success('Recurring expense deleted');
                      } catch (e) {
                        Toast.error(e);
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsStreamProvider);
    return groups.when(
      loading: () => const SkeletonList(),
      error: (e, _) => Center(child: ErrorState(error: e)),
      data: (list) {
        final cats =
            ref.watch(userCategoriesProvider).valueOrNull ??
            CategoryModel.defaults;
        final sections = <Widget>[];
        var loading = false;
        for (final g in list) {
          final t = ref.watch(groupTemplatesStreamProvider(g.groupId));
          if (t.isLoading) loading = true;
          final templates = t.valueOrNull ?? const <GroupExpenseModel>[];
          if (templates.isEmpty) continue;
          sections.add(SectionHeader(g.name));
          for (final tm in templates) {
            sections.add(
              _TemplateCard(
                category: groupCategoryOf(tm, cats),
                title: tm.description,
                amount: tm.amount,
                interval: tm.interval,
                start: tm.date,
                lastGenerated: tm.lastGeneratedDate,
                paused: tm.isCancelled,
                subtitle: '${tm.splits.length} people',
                onEdit: () => context.push(
                  '/groups/${g.groupId}/expense/${tm.expenseId}/edit',
                ),
                onTogglePause: () async {
                  try {
                    await ref
                        .read(groupExpensesRepositoryProvider)
                        .setTemplatePaused(
                          g.groupId,
                          tm.expenseId,
                          paused: !tm.isCancelled,
                        );
                    Toast.success(tm.isCancelled ? 'Resumed' : 'Paused');
                  } catch (e) {
                    Toast.error(e);
                  }
                },
                onDelete: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Delete "${tm.description}"?',
                    message: 'Expenses it already added stay in ${g.name}.',
                    confirmLabel: 'Delete',
                    destructive: true,
                  );
                  if (!ok) return;
                  try {
                    await ref
                        .read(groupExpensesRepositoryProvider)
                        .deleteTemplate(g.groupId, tm.expenseId);
                    Toast.success('Recurring expense deleted');
                  } catch (e) {
                    Toast.error(e);
                  }
                },
              ),
            );
          }
        }
        if (sections.isEmpty) {
          return loading
              ? const SkeletonList()
              : const Center(
                  child: EmptyState(
                    icon: Icons.autorenew_rounded,
                    title: 'No group recurring expenses',
                    message:
                        'Split rent or Wi-Fi automatically every month. Tap "New" to set one up.',
                  ),
                );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: sections,
        );
      },
    );
  }
}
