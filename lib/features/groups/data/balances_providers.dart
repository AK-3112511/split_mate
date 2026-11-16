import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/settlement.dart';
import '../../../core/utils/money.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/group_expense_model.dart';
import 'group_expenses_repository.dart';
import 'groups_repository.dart';

/// Everything the Balances tab needs for one group.
class GroupBalances {
  /// Net per member (+ owed to them, − they owe). Sums to zero.
  final Map<String, double> net;

  /// Direct person-to-person debts from shared expenses (default view).
  final List<Transfer> pairwise;

  /// Fewest-transfers suggestion ("Simplify debts").
  final List<Transfer> simplified;

  /// My direct balance with each other person (+ they owe me).
  final Map<String, double> mine;

  const GroupBalances({
    required this.net,
    required this.pairwise,
    required this.simplified,
    required this.mine,
  });

  double myNet(String uid) => net[uid] ?? 0;
  bool get allSettled => pairwise.isEmpty;

  static GroupBalances compute(String me, List<GroupExpenseModel> expenses, List<String> members) {
    final net = Settlement.netBalances(expenses, members: members);
    return GroupBalances(
      net: net,
      pairwise: Settlement.pairwiseDebts(expenses),
      simplified: Settlement.simplify(net),
      mine: Settlement.pairwiseFor(me, expenses)..removeWhere((_, v) => Money.isZero(v)),
    );
  }
}

final groupBalancesProvider = Provider.autoDispose.family<AsyncValue<GroupBalances>, String>((ref, groupId) {
  final me = ref.watch(currentUidProvider) ?? '';
  final group = ref.watch(groupDetailsStreamProvider(groupId));
  final expenses = ref.watch(groupExpensesStreamProvider(groupId));
  return expenses.whenData((list) {
    final members = group.valueOrNull?.members ?? const <String>[];
    return GroupBalances.compute(me, list, members);
  });
});

/// My position across every group, built from direct (pairwise) balances.
class OverallBalance {
  final double owedToMe;
  final double iOwe;

  /// Per other person, summed over all shared groups (+ they owe me).
  final Map<String, double> byPerson;

  /// Per group: my net in that group.
  final Map<String, double> byGroup;
  final bool loading;

  const OverallBalance({
    required this.owedToMe,
    required this.iOwe,
    required this.byPerson,
    required this.byGroup,
    this.loading = false,
  });

  double get net => owedToMe - iOwe;
  static const empty = OverallBalance(owedToMe: 0, iOwe: 0, byPerson: {}, byGroup: {});
}

final overallBalanceProvider = Provider.autoDispose<OverallBalance>((ref) {
  final me = ref.watch(currentUidProvider);
  final groups = ref.watch(groupsStreamProvider).valueOrNull ?? const [];
  if (me == null || groups.isEmpty) return OverallBalance.empty;

  final byPersonPaise = <String, int>{};
  final byGroup = <String, double>{};
  var loading = false;
  for (final g in groups) {
    final expenses = ref.watch(groupExpensesStreamProvider(g.groupId));
    final list = expenses.valueOrNull;
    if (list == null) {
      loading = true;
      continue;
    }
    final mine = Settlement.pairwiseFor(me, list);
    var groupPaise = 0;
    mine.forEach((uid, v) {
      final p = Money.toPaise(v);
      byPersonPaise[uid] = (byPersonPaise[uid] ?? 0) + p;
      groupPaise += p;
    });
    byGroup[g.groupId] = Money.fromPaise(groupPaise);
  }
  var owed = 0;
  var owe = 0;
  for (final p in byPersonPaise.values) {
    if (p > 0) owed += p;
    if (p < 0) owe += -p;
  }
  return OverallBalance(
    owedToMe: Money.fromPaise(owed),
    iOwe: Money.fromPaise(owe),
    byPerson: {
      for (final e in byPersonPaise.entries)
        if (e.value != 0) e.key: Money.fromPaise(e.value),
    },
    byGroup: byGroup,
    loading: loading,
  );
});

/// Net with one friend across all shared groups (+ they owe me).
final friendBalanceProvider = Provider.autoDispose.family<double, String>((ref, friendUid) {
  return ref.watch(overallBalanceProvider).byPerson[friendUid] ?? 0;
});
