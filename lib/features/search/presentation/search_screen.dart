import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/inputs.dart';
import '../../../shared_widgets/states.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_model.dart';
import '../../groups/data/group_expenses_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group_expense_model.dart';
import '../../groups/domain/group_model.dart';
import '../../groups/presentation/widgets/group_expense_widgets.dart';
import '../../home/domain/home_stats.dart';
import '../../personal_expenses/data/expense_repository.dart';
import '../../personal_expenses/domain/expense_model.dart';
import '../../personal_expenses/presentation/expense_actions.dart';
import '../../personal_expenses/presentation/expense_tile.dart';

enum _Scope { all, personal, groups }

enum _When { any, month, quarter }

/// One search across personal and group expenses.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  _Scope _scope = _Scope.all;
  _When _when = _When.any;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  bool _dateOk(DateTime d) {
    final now = DateTime.now();
    return switch (_when) {
      _When.any => true,
      _When.month => Dates.isSameMonth(d, now),
      _When.quarter => !d.isBefore(DateTime(now.year, now.month - 2)),
    };
  }

  bool _textOk(String q, List<String> fields) => fields.any((f) => f.toLowerCase().contains(q));

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final q = _q.text.trim().toLowerCase();
    final cats = ref.watch(userCategoriesProvider).valueOrNull ?? CategoryModel.defaults;
    final personal = ref.watch(personalExpensesProvider).valueOrNull ?? const <ExpenseModel>[];
    final groups = ref.watch(groupsStreamProvider).valueOrNull ?? const <GroupModel>[];

    final personalHits = <ExpenseModel>[];
    final groupHits = <(GroupModel, GroupExpenseModel)>[];
    if (q.isNotEmpty) {
      if (_scope != _Scope.groups) {
        for (final e in personal) {
          if (!_dateOk(e.date)) continue;
          final cat = HomeStats.categoryOf(e, cats).name;
          if (_textOk(q, [e.description, cat, e.notes ?? '', e.sourceGroupName ?? '', Money.plain(e.amount)])) {
            personalHits.add(e);
          }
        }
      }
      if (_scope != _Scope.personal) {
        for (final g in groups) {
          for (final e in ref.watch(groupExpensesStreamProvider(g.groupId)).valueOrNull ?? const <GroupExpenseModel>[]) {
            if (!_dateOk(e.date)) continue;
            if (_textOk(q, [e.description, e.category, e.notes ?? '', g.name, Money.plain(e.amount)])) {
              groupHits.add((g, e));
            }
          }
        }
        groupHits.sort((a, b) => b.$2.date.compareTo(a.$2.date));
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrGo()),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: Space.md),
          child: TextField(
            controller: _q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search expenses, groups, notes…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_q.clear),
                    ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              children: [
                for (final (s, l) in [(_Scope.all, 'Everything'), (_Scope.personal, 'Personal'), (_Scope.groups, 'Groups')]) ...[
                  ChoiceChipX(label: l, selected: _scope == s, onTap: () => setState(() => _scope = s)),
                  const SizedBox(width: Space.xs),
                ],
                const VerticalDivider(width: Space.md, indent: 10, endIndent: 10),
                for (final (w, l) in [(_When.any, 'Any time'), (_When.month, 'This month'), (_When.quarter, 'Last 3 months')]) ...[
                  ChoiceChipX(label: l, selected: _when == w, onTap: () => setState(() => _when = w)),
                  const SizedBox(width: Space.xs),
                ],
              ],
            ),
          ),
          Expanded(
            child: q.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.manage_search_rounded,
                      title: 'Find anything',
                      message: 'Try "pizza", "rent", "450" or a group name.',
                    ),
                  )
                : (personalHits.isEmpty && groupHits.isEmpty)
                    ? const Center(child: EmptyState(icon: Icons.search_off_rounded, title: 'No results'))
                    : ListView(
                        padding: const EdgeInsets.only(bottom: Space.xxl),
                        children: [
                          if (personalHits.isNotEmpty) ...[
                            _Header('Personal', personalHits.length),
                            for (final e in personalHits)
                              ExpenseTile(expense: e, showDate: true, onTap: () => showExpenseDetail(context, e)),
                          ],
                          if (groupHits.isNotEmpty) ...[
                            _Header('Groups', groupHits.length),
                            for (final (g, e) in groupHits) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: Space.gutter, top: Space.xs),
                                child: Text('${g.name} · ${Dates.dayLabel(e.date)}',
                                    style: context.text.labelSmall?.copyWith(color: c.primary, letterSpacing: 0)),
                              ),
                              GroupExpenseTile(expense: e, onTap: () => showGroupExpenseDetail(context, g, e)),
                            ],
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final int count;
  const _Header(this.title, this.count);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xxs),
        child: Text('$title · $count', style: context.text.titleSmall),
      );
}
