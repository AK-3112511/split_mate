import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/groups/domain/group_expense_model.dart';
import '../../features/groups/data/groups_repository.dart';
import '../../features/groups/data/group_expenses_repository.dart';

class GroupSettlementState {
  final Map<String, double> netBalances;
  final List<Map<String, dynamic>> transactions; // [{ 'from': uid, 'to': uid, 'amount': double }]

  GroupSettlementState({
    required this.netBalances,
    required this.transactions,
  });
}

class _BalanceItem {
  final String uid;
  double balance;

  _BalanceItem(this.uid, this.balance);
}

Map<String, double> recomputeBalances(String groupId, List<GroupExpenseModel> expenses, List<String> members) {
  // Initialize netBalance with 0.0 for all group members
  final Map<String, double> netBalance = {
    for (var uid in members) uid: 0.0,
  };

  for (final expense in expenses) {
    if (expense.isDeleted) continue;

    // Add amount to the payer
    netBalance[expense.payerUid] = (netBalance[expense.payerUid] ?? 0.0) + expense.amount;

    // Subtract each member's split amount
    // NOTE: splitsAmountOwed extracts only { uid: amountOwed } — settled flag is invisible here.
    expense.splitsAmountOwed.forEach((uid, owed) {
      netBalance[uid] = (netBalance[uid] ?? 0.0) - owed;
    });

  }

  // Clean up floating point precision issues (round to 2 decimals)
  netBalance.forEach((uid, value) {
    netBalance[uid] = double.parse(value.toStringAsFixed(2));
  });

  return netBalance;
}

List<Map<String, dynamic>> settleUp(Map<String, double> netBalance) {
  final List<_BalanceItem> creditors = [];
  final List<_BalanceItem> debtors = [];

  netBalance.forEach((uid, bal) {
    final roundedBal = double.parse(bal.toStringAsFixed(2));
    if (roundedBal > 0.01) {
      creditors.add(_BalanceItem(uid, roundedBal));
    } else if (roundedBal < -0.01) {
      debtors.add(_BalanceItem(uid, roundedBal));
    }
  });

  final List<Map<String, dynamic>> transactions = [];

  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    // Sort creditors descending (highest positive first)
    creditors.sort((a, b) => b.balance.compareTo(a.balance));
    // Sort debtors ascending (most negative first, i.e., -50 is before -10)
    debtors.sort((a, b) => a.balance.compareTo(b.balance));

    final creditor = creditors.first;
    final debtor = debtors.first;

    final amount = double.parse(
      (creditor.balance < -debtor.balance ? creditor.balance : -debtor.balance)
          .toStringAsFixed(2),
    );

    if (amount > 0.01) {
      transactions.add({
        'from': debtor.uid,
        'to': creditor.uid,
        'amount': amount,
      });
    }

    creditor.balance = double.parse((creditor.balance - amount).toStringAsFixed(2));
    debtor.balance = double.parse((debtor.balance + amount).toStringAsFixed(2));

    if (creditor.balance <= 0.01) {
      creditors.removeAt(0);
    }
    if (debtor.balance >= -0.01) {
      debtors.removeAt(0);
    }
  }

  return transactions;
}

final groupSettlementProvider = StreamProvider.family<GroupSettlementState, String>((ref, groupId) {
  final groupDetailsAsync = ref.watch(groupDetailsStreamProvider(groupId));
  final expensesAsync = ref.watch(groupExpensesStreamProvider(groupId));

  // Combine both streams
  return expensesAsync.when(
    data: (expenses) {
      final members = groupDetailsAsync.value?.members ?? [];
      final netBalances = recomputeBalances(groupId, expenses, members);
      final transactions = settleUp(netBalances);

      return Stream.value(GroupSettlementState(
        netBalances: netBalances,
        transactions: transactions,
      ));
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final globalSettlementOverviewProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final groupsAsync = ref.watch(groupsStreamProvider);
  return groupsAsync.when(
    data: (groups) {
      if (groups.isEmpty) {
        return Stream.value({
          'totalBalance': 0.0,
          'creditorGroupsCount': 0,
          'debtorGroupsCount': 0,
          'totalOwed': 0.0,
          'totalOwe': 0.0,
        });
      }

      final settlements = <GroupSettlementState>[];
      bool isLoading = false;
      for (final group in groups) {
        final settlementAsync = ref.watch(groupSettlementProvider(group.groupId));
        if (settlementAsync.value != null) {
          settlements.add(settlementAsync.value!);
        } else {
          isLoading = true;
        }
      }

      if (isLoading) {
        return const Stream.empty();
      }

      final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
      double totalBalance = 0.0;
      int creditorGroupsCount = 0;
      int debtorGroupsCount = 0;
      double totalOwed = 0.0;
      double totalOwe = 0.0;

      for (final state in settlements) {
        final myNet = state.netBalances[myUid] ?? 0.0;
        totalBalance += myNet;
        if (myNet > 0.01) {
          creditorGroupsCount++;
          totalOwed += myNet;
        } else if (myNet < -0.01) {
          debtorGroupsCount++;
          totalOwe += myNet.abs();
        }
      }

      return Stream.value({
        'totalBalance': double.parse(totalBalance.toStringAsFixed(2)),
        'creditorGroupsCount': creditorGroupsCount,
        'debtorGroupsCount': debtorGroupsCount,
        'totalOwed': double.parse(totalOwed.toStringAsFixed(2)),
        'totalOwe': double.parse(totalOwe.toStringAsFixed(2)),
      });
    },
    loading: () => const Stream.empty(),
    error: (err, stack) => const Stream.empty(),
  );
});

final friendNetBalanceProvider = StreamProvider.family<double, String>((ref, friendUid) {
  final groupsAsync = ref.watch(groupsStreamProvider);
  return groupsAsync.when(
    data: (groups) {
      final myUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
      if (myUid.isEmpty) return Stream.value(0.0);

      final sharedGroups = groups.where((g) => g.members.contains(friendUid)).toList();

      double netPairwise = 0.0;
      for (final group in sharedGroups) {
        final settlementAsync = ref.watch(groupSettlementProvider(group.groupId));
        final state = settlementAsync.value;
        if (state != null) {
          for (final tx in state.transactions) {
            if (tx['from'] == friendUid && tx['to'] == myUid) {
              netPairwise += (tx['amount'] as double);
            } else if (tx['from'] == myUid && tx['to'] == friendUid) {
              netPairwise -= (tx['amount'] as double);
            }
          }
        }
      }
      return Stream.value(double.parse(netPairwise.toStringAsFixed(2)));
    },
    loading: () => Stream.value(0.0),
    error: (err, stack) => Stream.value(0.0),
  );
});
