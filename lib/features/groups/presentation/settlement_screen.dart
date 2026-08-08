import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../friends/data/friends_repository.dart';
import '../data/groups_repository.dart';
import '../data/group_expenses_repository.dart';
import '../data/group_mirror_service.dart';
import '../../groups/domain/group_model.dart';
import '../../../core/utils/settlement_algorithm.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../../shared_widgets/receipt_viewer_dialog.dart';

class SettlementScreen extends ConsumerWidget {
  final String groupId;

  const SettlementScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    final groupAsync = ref.watch(groupDetailsStreamProvider(groupId));

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: groupAsync.when(
          data: (group) {
            if (group == null) return const Text('Settlements');
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SETTLEMENT STATUS',
                  style: AppTheme.monoStyle.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Flexible(
                  child: Text(
                    group.name.toUpperCase(),
                    style: AppTheme.monoSecondary.copyWith(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
          loading: () => const Text('Loading...'),
          error: (e, s) => const Text('Error'),
        ),
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found', style: TextStyle(color: Colors.red)));
          }
          return _buildContent(context, ref, group, currentUid);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, GroupModel group, String currentUid) {
    final settlementAsync = ref.watch(groupSettlementProvider(groupId));

    return settlementAsync.when(
      data: (settlement) {
        final netBalance = settlement.netBalances[currentUid] ?? 0.0;
        final transactions = settlement.transactions;

        // Filter transactions involving the current user
        final myTransactions = transactions.where((t) => t['from'] == currentUid || t['to'] == currentUid).toList();

        // Calculate card styling based on net balance status
        final balanceColor = netBalance > 0.01
            ? AppTheme.semanticPositive
            : netBalance < -0.01
                ? AppTheme.semanticNegative
                : AppTheme.textSecondary;

        final badgeText = netBalance > 0.01
            ? 'YOU ARE OWED'
            : netBalance < -0.01
                ? 'YOU OWE'
                : 'SETTLED';

        final badgeColor = netBalance > 0.01
            ? AppTheme.semanticPositive
            : netBalance < -0.01
                ? AppTheme.semanticNegative
                : AppTheme.textSecondary;

        return RefreshIndicator(
          onRefresh: () async {
            // Trigger refresh logic if any
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Net Group Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Group Balance',
                            style: AppTheme.monoSecondary.copyWith(fontSize: 10, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${netBalance.abs().toStringAsFixed(2)}',
                            style: AppTheme.monoStyle.copyWith(
                              color: balanceColor,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          badgeText,
                          style: AppTheme.monoStyle.copyWith(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Individual Balances Card
                _buildSectionCard(
                  title: 'INDIVIDUAL BALANCES',
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: group.members.length,
                    separatorBuilder: (context, index) => Divider(
                      color: AppTheme.textSecondary.withValues(alpha: 0.15),
                      height: 1.0,
                      thickness: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final memberUid = group.members[index];
                      if (memberUid == currentUid) return const SizedBox.shrink();

                      // Find if there is a transaction between current user and this member
                      final relativeTx = myTransactions.firstWhere(
                        (t) => t['from'] == memberUid || t['to'] == memberUid,
                        orElse: () => {},
                      );

                      String statusText = 'Settled no debt';
                      Color statusColor = AppTheme.textSecondary;
                      double relativeAmount = 0.0;

                      if (relativeTx.isNotEmpty) {
                        relativeAmount = relativeTx['amount'] ?? 0.0;
                        if (relativeTx['from'] == currentUid) {
                          statusText = 'you owe';
                          statusColor = AppTheme.semanticNegative;
                        } else {
                          statusText = 'owes you';
                          statusColor = AppTheme.semanticPositive;
                        }
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Consumer(
                              builder: (context, ref, child) {
                                final name = ref.watch(resolvedMemberNameProvider(memberUid));
                                final initials = name.isNotEmpty
                                    ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                    : 'U';
                                return Text(
                                  initials,
                                  style: AppTheme.monoStyle.copyWith(
                                    fontSize: 11,
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        title: Consumer(
                          builder: (context, ref, child) {
                            final name = ref.watch(resolvedMemberNameProvider(memberUid));
                            return Text(
                              name,
                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              relativeAmount > 0.01
                                  ? '₹${relativeAmount.toStringAsFixed(2)}'
                                  : 'Settled',
                              style: AppTheme.monoStyle.copyWith(
                                color: relativeAmount > 0.01 ? statusColor : AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (relativeAmount > 0.01) ...[
                              const SizedBox(height: 2),
                              Text(
                                statusText,
                                style: AppTheme.monoSecondary.copyWith(
                                  fontSize: 8,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Suggested Settlements
                _buildSectionCard(
                  title: 'SUGGESTED SETTLEMENTS',
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Optimize your debts. Clearing these will settle all accounts with the minimum number of transactions.',
                          style: AppTheme.monoSecondary.copyWith(fontSize: 10, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        if (myTransactions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'All accounts are currently balanced.',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: myTransactions.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final tx = myTransactions[index];
                              final fromUid = tx['from'] as String;
                              final toUid = tx['to'] as String;
                              final amount = tx['amount'] as double;

                              final isIpay = fromUid == currentUid;
                              final otherUid = isIpay ? toUid : fromUid;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceCard.withValues(alpha: 0.15),
                                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isIpay ? 'PAYMENT REQUEST' : 'OWED TO YOU',
                                          style: AppTheme.monoStyle.copyWith(
                                            color: isIpay ? AppTheme.semanticNegative : AppTheme.semanticPositive,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '₹${amount.toStringAsFixed(2)}',
                                          style: AppTheme.monoStyle.copyWith(
                                            color: AppTheme.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          isIpay ? 'From you to ' : 'From ',
                                          style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                                        ),
                                        Expanded(
                                          child: Consumer(
                                            builder: (context, ref, child) {
                                              final name = ref.watch(resolvedMemberNameProvider(otherUid));
                                              return Text(
                                                name,
                                                style: const TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            },
                                          ),
                                        ),
                                        Icon(
                                          isIpay ? Icons.arrow_forward : Icons.arrow_back,
                                          color: isIpay ? AppTheme.semanticNegative : AppTheme.semanticPositive,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (isIpay)
                                      InkWell(
                                        onTap: () => _recordPaymentFlow(context, ref, group.groupId, fromUid, toUid, amount),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: AppTheme.semanticNegative.withValues(alpha: 0.6)),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'RECORD PAYMENT',
                                              style: AppTheme.monoStyle.copyWith(
                                                color: AppTheme.semanticNegative,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                       Consumer(
                                          builder: (context, ref, child) {
                                            final hasRequestedAsync = ref.watch(hasRecentPaymentRequestProvider((recipientUid: otherUid, groupId: group.groupId)));
                                            final hasRequested = hasRequestedAsync.value ?? false;

                                            return InkWell(
                                              onTap: hasRequested
                                                  ? null
                                                  : () => _requestPaymentFlow(context, ref, otherUid, group.groupId, group.name, amount),
                                              child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(vertical: 10),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: hasRequested
                                                        ? AppTheme.textSecondary.withValues(alpha: 0.4)
                                                        : AppTheme.semanticPositive.withValues(alpha: 0.6),
                                                  ),
                                                  color: hasRequested ? AppTheme.surfaceCard.withValues(alpha: 0.3) : Colors.transparent,
                                                ),
                                                child: Center(
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (hasRequested) ...[
                                                        const Icon(Icons.check, size: 12, color: AppTheme.textSecondary),
                                                        const SizedBox(width: 4),
                                                      ],
                                                      Text(
                                                        hasRequested ? 'REQUESTED (SENT)' : 'REQUEST PAYMENT',
                                                        style: AppTheme.monoStyle.copyWith(
                                                          color: hasRequested ? AppTheme.textSecondary : AppTheme.semanticPositive,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Ledger entries info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard.withValues(alpha: 0.1),
                    border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: AppTheme.accent, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Ledger entries are permanent. Record payments only after verifying bank transfers.',
                          style: AppTheme.monoSecondary.copyWith(fontSize: 9, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 5. Recent Debt Changes Activity Card
                _buildActivityLog(context, ref),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text('Error loading settlements: $err', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildActivityLog(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(groupActivityStreamProvider(groupId));

    return _buildSectionCard(
      title: 'RECENT DEBT CHANGES',
      child: activityAsync.when(
        data: (activities) {
          final debtActivities = activities.where((a) => a.type == 'settled_up').toList();

          if (debtActivities.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No payment clearances or settlements recorded yet.',
                  style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: debtActivities.length > 5 ? 5 : debtActivities.length, // limit to 5 on settlement screen
            separatorBuilder: (context, index) => Divider(
              color: AppTheme.textSecondary.withValues(alpha: 0.15),
              height: 1.0,
              thickness: 1.0,
            ),
            itemBuilder: (context, index) {
              final activity = debtActivities[index];
              final dateStr = DateFormat('dd MMM').format(activity.createdAt).toUpperCase();

              const IconData icon = Icons.check_circle_outline;
              const Color iconColor = AppTheme.accent;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                title: Text(
                  activity.message,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.3),
                ),
                trailing: Consumer(
                  builder: (context, ref, child) {
                    if (activity.expenseId != null) {
                      final expenses = ref.watch(groupExpensesStreamProvider(groupId)).value ?? [];
                      final match = expenses.where((e) => e.expenseId == activity.expenseId && !e.isDeleted).firstOrNull;
                      if (match != null && match.receiptUrl != null && match.receiptUrl!.isNotEmpty) {
                        return IconButton(
                          icon: const Icon(Icons.receipt_long_outlined, color: AppTheme.accent, size: 18),
                          tooltip: 'View Receipt',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            ReceiptViewerDialog.show(
                              context,
                              receiptUrl: match.receiptUrl!,
                              description: match.description,
                              amount: match.amount,
                              dateStr: DateFormat('MMM dd, yyyy').format(match.createdAt),
                            );
                          },
                        );
                      }
                    }
                    return Text(
                      dateStr,
                      style: AppTheme.monoSecondary.copyWith(fontSize: 9),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text('Error loading activities: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }

  Future<void> _recordPaymentFlow(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String fromUid,
    String toUid,
    double amount,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: const Text('Record Payment', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Are you sure you want to record a payment of ₹${amount.toStringAsFixed(2)}? This will zero out this debt in the group ledger.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('RECORD', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Record the settlement payment in the group ledger.
        await ref.read(groupExpensesRepositoryProvider).recordPayment(groupId, fromUid, toUid, amount);

        // 2. Section 12: Mark all pairwise unsettled split entries as settled.
        //    This covers expenses paid by fromUid (toUid owes) and expenses paid by toUid (fromUid owes).
        await ref.read(groupExpensesRepositoryProvider).markSplitsSettled(groupId, fromUid, toUid);

        // 3. Section 12: Trigger mirror scan for the current user immediately,
        //    so their personal list updates without waiting for the next app launch.
        await runGroupMirrorScan(ref);

        final currentUid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
        final otherUid = fromUid == currentUid ? toUid : fromUid;
        final group = ref.read(groupDetailsStreamProvider(groupId)).value;
        final groupName = group?.name ?? 'Group';

        await ref.read(notificationsRepositoryProvider).sendPaymentRecorded(
          recipientUid: otherUid,
          groupId: groupId,
          groupName: groupName,
          amount: amount,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successfully recorded & notification sent!'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error recording payment: $e'),
              backgroundColor: AppTheme.semanticNegative,
            ),
          );
        }
      }
    }
  }

  Future<void> _requestPaymentFlow(BuildContext context, WidgetRef ref, String otherUid, String groupId, String groupName, double amount) async {
    final details = ref.read(friendDetailsProvider(otherUid));
    final name = details.value?['displayName'] ?? 'Group Member';

    try {
      await ref.read(notificationsRepositoryProvider).sendPaymentRequest(
        recipientUid: otherUid,
        groupId: groupId,
        groupName: groupName,
        amount: amount,
      );

      final requestText = 'Hey $name, just a reminder to settle ₹${amount.toStringAsFixed(2)} for our shared expenses in "$groupName" on SplitMate!';
      await Clipboard.setData(ClipboardData(text: requestText));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment clearance request sent to $name!'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
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
              color: AppTheme.surfaceCard.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.15)),
              ),
            ),
            child: Text(
              title,
              style: AppTheme.monoSecondary.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
