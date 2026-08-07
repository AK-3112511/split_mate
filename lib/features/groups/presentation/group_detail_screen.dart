import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../friends/data/friends_repository.dart';
import '../../categories/data/categories_repository.dart';
import '../data/groups_repository.dart';
import '../data/group_expenses_repository.dart';
import '../domain/group_model.dart';
import '../domain/group_expense_model.dart';
import '../../../core/utils/settlement_algorithm.dart';
import '../../../core/utils/export_helper.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../../shared_widgets/receipt_viewer_dialog.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailsStreamProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'SplitMate',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
        ),
        centerTitle: true,
        actions: [
          groupAsync.when(
            data: (group) {
              if (group == null) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined, color: AppTheme.textPrimary),
                    onPressed: () => context.push('/groups/${group.groupId}/insights'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.accent),
                    tooltip: 'Export PDF Report',
                    onPressed: () => _triggerExportPDF(context, ref, group),
                  ),
                  PopupMenuButton<String>(
                    color: AppTheme.surfaceBase,
                    icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditGroupNameDialog(context, ref, group);
                      } else if (value == 'delete') {
                        _confirmDeleteGroup(context, ref, group);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16, color: AppTheme.accent),
                            SizedBox(width: 8),
                            Text('EDIT GROUP', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (group.admins.contains(ref.watch(firebaseAuthProvider).currentUser?.uid ?? '') || group.createdBy == (ref.watch(firebaseAuthProvider).currentUser?.uid ?? ''))
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: AppTheme.semanticNegative),
                              SizedBox(width: 8),
                              Text('DELETE GROUP', style: TextStyle(color: AppTheme.semanticNegative, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
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
        child: groupAsync.when(
          data: (group) {
            if (group == null) {
              return const Center(child: Text('Group not found'));
            }
            return _buildContent(context, ref, group);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, GroupModel group) {
    final memberCount = group.members.length;
    final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    final isCurrentAdmin = group.admins.contains(currentUid) || group.createdBy == currentUid;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Title & Group Code Parallel Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Column: Group Name & Member Count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$memberCount members',
                        style: AppTheme.monoSecondary.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right Column: Group Code Badge & Quick Actions (Parallel to Group Name)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard.withValues(alpha: 0.3),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GROUP CODE',
                            style: AppTheme.monoSecondary.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            group.inviteCode ?? 'CODE',
                            style: AppTheme.monoStyle.copyWith(
                              color: AppTheme.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: group.inviteCode ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Group code copied to clipboard!'),
                              backgroundColor: AppTheme.accent,
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.copy, size: 18, color: AppTheme.accent),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          ExportHelper.shareGroupInviteCode(
                            groupName: group.name,
                            inviteCode: group.inviteCode ?? '',
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.share, size: 18, color: AppTheme.accent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Add Expense Gold Button
            InkWell(
              onTap: () {
                context.push('/groups/${group.groupId}/add-expense');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'ADD EXPENSE',
                      style: AppTheme.monoStyle.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
 
            // Group Members List Card
            _buildSectionCard(
              title: 'GROUP MEMBERS',
              trailing: InkWell(
                onTap: () => _showAddMemberDialog(context, ref, group),
                child: Text(
                  '+ ADD MEMBER',
                  style: AppTheme.monoStyle.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                  ),
                ),
              ),
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
                  final detailsAsync = ref.watch(friendDetailsProvider(memberUid));
                  final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
                  final isAdmin = group.admins.contains(memberUid) || group.createdBy == memberUid;
                  final isCurrentAdmin = group.admins.contains(currentUid) || group.createdBy == currentUid;

                  // Check if this member is a friend of current user
                  final friendsList = ref.watch(friendsStreamProvider).value ?? [];
                  final isFriend = memberUid == currentUid || friendsList.any((f) => f.uid == memberUid);

                  return detailsAsync.when(
                    data: (details) {
                      final name = details?['displayName'] ?? 'Group Member';
                      final email = details?['email'] ?? 'Active on SplitMate';
                      final avatarInitials = name.isNotEmpty
                          ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                          : 'M';
                      final photoUrl = details?['photoUrl'];
                      final appCode = details?['appCode'];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                          ),
                          child: photoUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.zero,
                                  child: CachedNetworkImage(
                                    imageUrl: photoUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        avatarInitials,
                                        style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    avatarInitials,
                                    style: AppTheme.monoStyle.copyWith(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                memberUid == currentUid ? '$name (You)' : name,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.2),
                                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'ADMIN',
                                  style: AppTheme.monoStyle.copyWith(
                                    color: AppTheme.accent,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            email,
                            style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isFriend && memberUid != currentUid && appCode != null)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.accent),
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                onPressed: () async {
                                  try {
                                    await ref.read(friendsRepositoryProvider).addFriendByCode(appCode);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Friend request sent to $name!'), backgroundColor: AppTheme.accent),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Request error: $e'), backgroundColor: AppTheme.semanticNegative),
                                    );
                                  }
                                },
                                child: Text('+ CONNECT', style: AppTheme.monoStyle.copyWith(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                              ),
                            if (isCurrentAdmin && memberUid != currentUid)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 18),
                                color: AppTheme.surfaceCard,
                                onSelected: (action) async {
                                  try {
                                    if (action == 'make_admin') {
                                      await ref.read(groupsRepositoryProvider).makeMemberAdmin(group.groupId, memberUid);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$name is now a Group Admin'), backgroundColor: AppTheme.accent),
                                        );
                                      }
                                    } else if (action == 'remove') {
                                      await ref.read(groupsRepositoryProvider).removeMemberFromGroup(group.groupId, memberUid);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Removed $name from group'), backgroundColor: AppTheme.semanticNegative),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.semanticNegative),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (!isAdmin)
                                    const PopupMenuItem(
                                      value: 'make_admin',
                                      child: Text('Make Group Admin', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                                    ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Remove from Group', style: TextStyle(color: AppTheme.semanticNegative, fontSize: 12)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                    loading: () => const ListTile(title: Text('Loading member details...')),
                    error: (e, s) => ListTile(title: Text('Error loading member: $e')),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
 
            // Debts To Settle Section
            Consumer(
              builder: (context, ref, child) {
                final settlementAsync = ref.watch(groupSettlementProvider(group.groupId));
                final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

                return settlementAsync.when(
                  data: (settlement) {
                    final myTransactions = settlement.transactions
                        .where((t) => t['from'] == currentUid || t['to'] == currentUid)
                        .toList();

                    return _buildSectionCard(
                      title: 'DEBTS TO SETTLE',
                      trailing: InkWell(
                        onTap: () => context.push('/groups/${group.groupId}/settlement'),
                        child: Text(
                          'VIEW SETTLEMENTS',
                          style: AppTheme.monoStyle.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                      child: myTransactions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Center(
                                child: Text(
                                  'All accounts are currently balanced.',
                                  style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: myTransactions.length > 3 ? 3 : myTransactions.length,
                              separatorBuilder: (context, index) => Divider(
                                color: AppTheme.textSecondary.withValues(alpha: 0.15),
                                height: 1.0,
                                thickness: 1.0,
                              ),
                              itemBuilder: (context, index) {
                                final tx = myTransactions[index];
                                final fromUid = tx['from'] as String;
                                final toUid = tx['to'] as String;
                                final amount = tx['amount'] as double;

                                final isIpay = fromUid == currentUid;
                                final otherUid = isIpay ? toUid : fromUid;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: const Icon(
                                    Icons.swap_horizontal_circle_outlined,
                                    color: AppTheme.accent,
                                    size: 24,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        isIpay ? 'You owe ' : 'Owes you ',
                                        style: TextStyle(
                                          color: isIpay ? AppTheme.semanticNegative : AppTheme.semanticPositive,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final details = ref.watch(friendDetailsProvider(otherUid));
                                            return Text(
                                              details.value?['displayName'] ?? 'Member',
                                              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₹${amount.toStringAsFixed(2)}',
                                        style: AppTheme.monoStyle.copyWith(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (!isIpay) ...[
                                        const SizedBox(width: 8),
                                        Consumer(
                                          builder: (context, ref, child) {
                                            final hasRequestedAsync = ref.watch(hasRecentPaymentRequestProvider((recipientUid: otherUid, groupId: group.groupId)));
                                            final hasRequested = hasRequestedAsync.value ?? false;

                                            return InkWell(
                                              onTap: hasRequested
                                                  ? null
                                                  : () async {
                                                      try {
                                                        await ref.read(notificationsRepositoryProvider).sendPaymentRequest(
                                                          recipientUid: otherUid,
                                                          groupId: group.groupId,
                                                          groupName: group.name,
                                                          amount: amount,
                                                        );
                                                        if (context.mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Payment clearance request sent!'),
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
                                                    },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: hasRequested
                                                        ? AppTheme.textSecondary.withValues(alpha: 0.4)
                                                        : AppTheme.semanticPositive,
                                                  ),
                                                  color: hasRequested
                                                      ? AppTheme.surfaceCard.withValues(alpha: 0.5)
                                                      : AppTheme.semanticPositive.withValues(alpha: 0.1),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (hasRequested) ...[
                                                      const Icon(Icons.check, size: 10, color: AppTheme.textSecondary),
                                                      const SizedBox(width: 3),
                                                    ],
                                                    Text(
                                                      hasRequested ? 'REQUESTED' : 'REQUEST',
                                                      style: AppTheme.monoStyle.copyWith(
                                                        color: hasRequested ? AppTheme.textSecondary : AppTheme.semanticPositive,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, s) => ListTile(title: Text('Error loading debts: $e')),
                );
              },
            ),
            // Spending Breakdown Card
            _buildSpendingBreakdownCard(context, ref, group),
            const SizedBox(height: 24),

            // Activity Section
            _buildActivityCard(context, ref, group.groupId),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
 
  Widget _buildActivityCard(BuildContext context, WidgetRef ref, String groupId) {
    final activityAsync = ref.watch(groupActivityStreamProvider(groupId));
 
    return _buildSectionCard(
      title: 'ACTIVITY',
      child: activityAsync.when(
        data: (activities) {
          if (activities.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No transactions recorded. Create a group expense to begin splits calculation.',
                  style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
 
          return Column(
            children: [
              SizedBox(
                height: 185,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => Divider(
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                    height: 1.0,
                    thickness: 1.0,
                  ),
                  itemBuilder: (context, index) {
                    final activity = activities[index];
                    final dateStr = DateFormat('dd MMM').format(activity.createdAt).toUpperCase();

                    IconData icon = Icons.receipt_long_outlined;
                    Color iconColor = AppTheme.accent;

                    if (activity.type == 'expense_deleted') {
                      icon = Icons.delete_outline;
                      iconColor = AppTheme.semanticNegative;
                    } else if (activity.type == 'expense_edited') {
                      icon = Icons.edit_outlined;
                      iconColor = Colors.blue;
                    } else if (activity.type == 'settled_up') {
                      icon = Icons.check_circle_outline;
                      iconColor = AppTheme.accent;
                    }

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
                      onTap: () {
                        if (activity.expenseId != null) {
                          final expensesAsync = ref.read(groupExpensesStreamProvider(groupId));
                          try {
                            final expense = expensesAsync.value?.firstWhere(
                              (e) => e.expenseId == activity.expenseId && !e.isDeleted,
                            );
                            if (expense != null) {
                              _showExpenseOptions(context, ref, expense);
                            }
                          } catch (_) {}
                        }
                      },
                    );
                  },
                ),
              ),
              Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1.0),
              InkWell(
                onTap: () => _showFullActivityDialog(context, ref, groupId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.open_in_full, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'EXPAND FULL ACTIVITY HISTORY',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text('Error loading activity: $err', style: const TextStyle(color: Colors.red)),
          ),
        ),
      ),
    );
  }

  void _showFullActivityDialog(BuildContext context, WidgetRef ref, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceBase,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (modalContext) {
        return Container(
          height: MediaQuery.of(modalContext).size.height * 0.85,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_outlined, color: AppTheme.accent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'FULL GROUP ACTIVITY',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final activityAsync = ref.watch(groupActivityStreamProvider(groupId));
                    return activityAsync.when(
                      data: (activities) {
                        if (activities.isEmpty) {
                          return Center(
                            child: Text(
                              'No activity records.',
                              style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: activities.length,
                          separatorBuilder: (context, index) => Divider(
                            color: AppTheme.textSecondary.withValues(alpha: 0.15),
                            height: 1.0,
                          ),
                          itemBuilder: (context, index) {
                            final activity = activities[index];
                            final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(activity.createdAt).toUpperCase();
                            IconData icon = Icons.receipt_long_outlined;
                            Color iconColor = AppTheme.accent;
                            if (activity.type == 'expense_deleted') {
                              icon = Icons.delete_outline;
                              iconColor = AppTheme.semanticNegative;
                            } else if (activity.type == 'expense_edited') {
                              icon = Icons.edit_outlined;
                              iconColor = Colors.blue;
                            } else if (activity.type == 'settled_up') {
                              icon = Icons.check_circle_outline;
                              iconColor = AppTheme.accent;
                            }

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                                ),
                                child: Icon(icon, color: iconColor, size: 20),
                              ),
                              title: Text(
                                activity.message,
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.3),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  dateStr,
                                  style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                                ),
                              ),
                              onTap: () {
                                if (activity.expenseId != null) {
                                  final expensesAsync = ref.read(groupExpensesStreamProvider(groupId));
                                  try {
                                    final expense = expensesAsync.value?.firstWhere(
                                      (e) => e.expenseId == activity.expenseId && !e.isDeleted,
                                    );
                                    if (expense != null) {
                                      Navigator.pop(modalContext);
                                      _showExpenseOptions(context, ref, expense);
                                    }
                                  } catch (_) {}
                                }
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExpenseOptions(BuildContext context, WidgetRef ref, GroupExpenseModel expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: AppTheme.accent),
                  title: const Text('View Receipt / Bill Photo', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    context.pop();
                    ReceiptViewerDialog.show(
                      context,
                      receiptUrl: expense.receiptUrl!,
                      description: expense.description,
                      amount: expense.amount,
                      dateStr: DateFormat('MMM dd, yyyy').format(expense.createdAt),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppTheme.textPrimary),
                title: const Text('Edit Expense', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  context.pop();
                  context.push('/groups/$groupId/add-expense?expenseId=${expense.expenseId}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.semanticNegative),
                title: const Text('Delete Expense', style: TextStyle(color: AppTheme.semanticNegative)),
                onTap: () async {
                  context.pop();
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.surfaceCard,
                      title: const Text('Delete Expense', style: TextStyle(color: AppTheme.textPrimary)),
                      content: const Text('Are you sure you want to delete this expense? This cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('DELETE', style: TextStyle(color: AppTheme.semanticNegative)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(groupExpensesRepositoryProvider).softDeleteGroupExpense(groupId, expense.expenseId);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
 
  void _showAddMemberDialog(BuildContext context, WidgetRef ref, GroupModel group) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: Consumer(
            builder: (context, ref, child) {
              final friendsAsync = ref.watch(friendsStreamProvider);
              return friendsAsync.when(
                data: (friends) {
                  final eligibleFriends = friends
                      .where((f) => f.status == 'accepted' && !group.members.contains(f.uid))
                      .toList();

                  return Container(
                    padding: const EdgeInsets.all(24),
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADD MEMBER',
                          style: AppTheme.monoStyle.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select an accepted friend to add to this group.',
                          style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                        ),
                        const SizedBox(height: 16),
                        
                        // Add New Friend By Code Action Button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            _showAddNewFriendDialog(context, ref);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                '+ CONNECT NEW FRIEND',
                                style: AppTheme.monoStyle.copyWith(
                                  color: AppTheme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (eligibleFriends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Text(
                                'No other accepted friends.',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: Consumer(
                              builder: (context, ref, child) {
                                final sentInvitesAsync = ref.watch(groupSentInvitesProvider(group.groupId));
                                final sentInvites = sentInvitesAsync.value ?? [];

                                return ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: eligibleFriends.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                                    height: 1,
                                  ),
                                  itemBuilder: (context, index) {
                                    final friend = eligibleFriends[index];
                                    final detailsAsync = ref.watch(friendDetailsProvider(friend.uid));
                                    final isInvitePending = sentInvites.any((inv) => inv.recipientUid == friend.uid);

                                    return detailsAsync.when(
                                      data: (details) {
                                        final name = details?['displayName'] ?? 'User';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            name,
                                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          trailing: isInvitePending
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.accent.withValues(alpha: 0.15),
                                                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.6)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.check_circle, color: AppTheme.accent, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'SENT',
                                                        style: AppTheme.monoStyle.copyWith(
                                                          color: AppTheme.accent,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : IconButton(
                                                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 20),
                                                  onPressed: () async {
                                                    try {
                                                      await ref.read(groupsRepositoryProvider).sendGroupInvite(group.groupId, friend.uid);
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Group invitation sent to $name!'),
                                                            backgroundColor: AppTheme.accent,
                                                          ),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        final msg = e.toString().replaceFirst('Exception: ', '');
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text(msg),
                                                            backgroundColor: AppTheme.semanticNegative,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                        );
                                      },
                                      loading: () => const ListTile(title: Text('Loading...')),
                                      error: (e, s) => const ListTile(title: Text('Error')),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CLOSE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Error loading friends: $err', style: const TextStyle(color: Colors.red)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showEditGroupNameDialog(BuildContext context, WidgetRef ref, GroupModel group) {
    final controller = TextEditingController(text: group.name);
    String? errorMessage;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceBase,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(
                'EDIT GROUP NAME',
                style: AppTheme.monoStyle.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Group Name',
                      hintText: 'Enter new group name',
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.accent),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          try {
                            await ref.read(groupsRepositoryProvider).updateGroupName(group.groupId, controller.text);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Group name updated!'),
                                  backgroundColor: AppTheme.accent,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('SAVE', style: AppTheme.monoStyle.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteGroup(BuildContext context, WidgetRef ref, GroupModel group) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceBase,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            'DELETE GROUP LEDGER',
            style: AppTheme.monoStyle.copyWith(
              color: AppTheme.semanticNegative,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${group.name}"? All shared expenses and ledger history for this group will be deleted. This action cannot be undone.',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.semanticNegative),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref.read(groupsRepositoryProvider).deleteGroup(group.groupId);
                  if (context.mounted) {
                    context.go('/groups');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Group "${group.name}" deleted'),
                        backgroundColor: AppTheme.semanticNegative,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    final msg = e.toString().replaceFirst('Exception: ', '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        backgroundColor: AppTheme.semanticNegative,
                      ),
                    );
                  }
                }
              },
              child: Text('DELETE', style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showAddNewFriendDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String? dialogError;
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              title: Text(
                'CONNECT NEW FRIEND',
                style: AppTheme.monoStyle.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Text(
                      dialogError!,
                      style: AppTheme.monoStyle.copyWith(color: AppTheme.semanticNegative, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Enter their 6-character app code:',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                     controller: controller,
                     autofocus: true,
                     style: AppTheme.monoStyle.copyWith(color: AppTheme.textPrimary, fontSize: 13),
                     decoration: const InputDecoration(
                       hintText: 'A1B2C3',
                       focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                       enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary)),
                     ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ),
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                           final code = controller.text.trim();
                           if (code.isEmpty) return;

                           setState(() {
                             isAdding = true;
                             dialogError = null;
                           });

                           try {
                             await ref.read(friendsRepositoryProvider).addFriendByCode(code);
                             if (context.mounted) {
                               Navigator.pop(context);
                               ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(
                                   content: Text('Friend request sent!'),
                                   backgroundColor: AppTheme.accent,
                                 ),
                               );
                             }
                           } catch (e) {
                             setState(() {
                               dialogError = e.toString().replaceFirst('Exception: ', '');
                               isAdding = false;
                             });
                           }
                         },
                  child: isAdding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
                        )
                      : const Text('CONNECT', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>> _resolveMemberNames(WidgetRef ref, List<String> uids) async {
    final Map<String, String> names = {};
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    final firestore = ref.read(firestoreProvider);

    for (final uid in uids) {
      if (currentUser != null && currentUser.uid == uid) {
        names[uid] = currentUser.displayName ?? 'You';
      } else {
        try {
          final doc = await firestore.collection('users').doc(uid).get();
          if (doc.exists) {
            names[uid] = doc.data()?['displayName'] ?? 'User';
          } else {
            names[uid] = 'User';
          }
        } catch (_) {
          names[uid] = 'User';
        }
      }
    }
    return names;
  }

  Future<void> _triggerExportPDF(BuildContext context, WidgetRef ref, GroupModel group) async {
    bool isDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
      ),
    );

    try {
      final names = await _resolveMemberNames(ref, group.members);
      final expenses = ref.read(groupExpensesStreamProvider(group.groupId)).value ?? [];

      final categoriesList = ref.read(userCategoriesProvider).value ?? [];
      final categoryNamesMap = <String, String>{};
      for (final cat in categoriesList) {
        categoryNamesMap[cat.id] = cat.name;
        categoryNamesMap[cat.name.toLowerCase()] = cat.name;
      }

      final filePath = await ExportHelper.generateGroupExpensesPDFFile(
        groupName: group.name,
        expenses: expenses,
        memberNames: names,
        categoryNames: categoryNamesMap,
      );

      if (context.mounted && isDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShown = false;
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '${group.name} Shared Ledger PDF Export',
        text: 'Here is the exported PDF ledger report for SplitMate group "${group.name}".',
      );
    } catch (e) {
      if (context.mounted && isDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShown = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export failed: $e'), backgroundColor: AppTheme.semanticNegative),
        );
      }
    }
  }

  Widget _buildSpendingBreakdownCard(BuildContext context, WidgetRef ref, GroupModel group) {
    final expensesAsync = ref.watch(groupExpensesStreamProvider(group.groupId));
    final categoriesAsync = ref.watch(userCategoriesProvider);

    return _buildSectionCard(
      title: 'SPENDING BREAKDOWN',
      child: expensesAsync.when(
        data: (expenses) => categoriesAsync.when(
          data: (categories) {
            final activeExpenses = expenses.where((e) => !e.isDeleted && !e.isRecurringTemplate && !e.isSettlement).toList();

            if (activeExpenses.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'No group expenses recorded yet.',
                    style: AppTheme.monoSecondary.copyWith(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // 1. Total Group Spend
            final double totalSpent = activeExpenses.fold(0.0, (sum, e) => sum + e.amount);

            // 2. Category totals
            final Map<String, double> categorySums = {};
            for (final e in activeExpenses) {
              categorySums[e.category] = (categorySums[e.category] ?? 0.0) + e.amount;
            }

            final categoryMap = {for (var c in categories) c.id: c};
            final sortedCategoryKeys = categorySums.keys.toList()
              ..sort((a, b) => categorySums[b]!.compareTo(categorySums[a]!));

            // 3. Member payer ranking ("who paid the most")
            final Map<String, double> payerSums = {
              for (var uid in group.members) uid: 0.0,
            };
            for (final e in activeExpenses) {
              payerSums[e.payerUid] = (payerSums[e.payerUid] ?? 0.0) + e.amount;
            }

            final sortedPayerUids = group.members.toList()
              ..sort((a, b) => (payerSums[b] ?? 0.0).compareTo(payerSums[a] ?? 0.0));

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Spent Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL GROUP SPEND',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        '₹${totalSpent.toStringAsFixed(2)}',
                        style: AppTheme.monoStyle.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 16),

                  // Category Breakdown Header
                  Text(
                    'BY CATEGORY',
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Categories List
                  ...sortedCategoryKeys.map((catId) {
                    final sum = categorySums[catId] ?? 0.0;
                    final category = categoryMap[catId];
                    final catName = category?.name ?? 'Others';
                    final catColor = category?.color ?? AppTheme.textSecondary;
                    final catIcon = category?.icon ?? Icons.help_outline;
                    final double percentage = totalSpent > 0 ? sum / totalSpent : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(catIcon, color: catColor, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  catName.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                                '(${(percentage * 100).toStringAsFixed(1)}%)',
                                style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
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
                  }),

                  const SizedBox(height: 16),
                  Divider(color: AppTheme.textSecondary.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 16),

                  // Who Paid The Most Ranking Header
                  Text(
                    'WHO PAID THE MOST (RANKING)',
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Member Ranking List
                  ...List.generate(sortedPayerUids.length, (index) {
                    final uid = sortedPayerUids[index];
                    final paidAmount = payerSums[uid] ?? 0.0;
                    final double paidPercentage = totalSpent > 0 ? paidAmount / totalSpent : 0.0;
                    final isTopPayer = index == 0 && paidAmount > 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isTopPayer
                              ? AppTheme.accent.withValues(alpha: 0.08)
                              : AppTheme.surfaceCard.withValues(alpha: 0.15),
                          border: Border.all(
                            color: isTopPayer
                                ? AppTheme.accent.withValues(alpha: 0.4)
                                : AppTheme.textSecondary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Rank Number badge
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isTopPayer ? AppTheme.accent : AppTheme.surfaceCard,
                                border: Border.all(color: isTopPayer ? AppTheme.accent : AppTheme.textSecondary.withValues(alpha: 0.3)),
                              ),
                              child: Center(
                                child: Text(
                                  '#${index + 1}',
                                  style: TextStyle(
                                    color: isTopPayer ? Colors.black : AppTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Member Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Consumer(
                                          builder: (context, ref, child) {
                                            final currentUid = ref.watch(firebaseAuthProvider).currentUser?.uid;
                                            if (uid == currentUid) {
                                              return const Text(
                                                'You',
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            }
                                            final details = ref.watch(friendDetailsProvider(uid)).value;
                                            final name = details?['displayName'] ?? 'Member';
                                            return Text(
                                              name,
                                              style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                      ),
                                      if (isTopPayer) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.accent,
                                            borderRadius: BorderRadius.zero,
                                          ),
                                          child: Text(
                                            'TOP PAYER',
                                            style: AppTheme.monoStyle.copyWith(
                                              color: Colors.black,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Paid ₹${paidAmount.toStringAsFixed(2)} (${(paidPercentage * 100).toStringAsFixed(1)}% of group total)',
                                    style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          error: (e, s) => ListTile(title: Text('Error loading categories: $e')),
        ),
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        error: (e, s) => ListTile(title: Text('Error loading expenses: $e')),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Widget? trailing,
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
              color: AppTheme.surfaceCard,
              border: Border(
                bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTheme.monoStyle.copyWith(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
