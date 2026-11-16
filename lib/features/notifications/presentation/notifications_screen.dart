import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/motion.dart';
import '../../../shared_widgets/states.dart';
import '../../groups/data/groups_repository.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_model.dart';

/// The single notifications inbox (v1 had a second, drifting copy in Groups).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userNotificationsStreamProvider);
    final repo = ref.read(notificationsRepositoryProvider);
    final items = async.valueOrNull ?? const <NotificationModel>[];
    final unread = items.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrGo()),
        title: const Text('Notifications'),
        actions: [
          if (items.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) async {
                try {
                  if (v == 'read') {
                    await repo.markAllRead(items);
                    Toast.success('All caught up');
                  } else {
                    final ok = await confirmAction(
                      context,
                      title: 'Clear all notifications?',
                      message: 'This removes them from your inbox.',
                      confirmLabel: 'Clear all',
                      destructive: true,
                    );
                    if (ok) await repo.clearAll(items);
                  }
                } catch (e) {
                  Toast.error(e);
                }
              },
              itemBuilder: (_) => [
                if (unread > 0) const PopupMenuItem(value: 'read', child: Text('Mark all as read')),
                const PopupMenuItem(value: 'clear', child: Text('Clear all')),
              ],
            ),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => Center(child: ErrorState(error: e, onRetry: () => ref.invalidate(userNotificationsStreamProvider))),
        data: (list) => list.isEmpty
            ? const Center(
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'You\'re all caught up',
                  message: 'Expense updates, payments and invites will show up here.',
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: Space.xxl),
                itemCount: list.length,
                itemBuilder: (context, i) => _NotificationTile(n: list[i]).entrance(context, index: i),
              ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel n;
  const _NotificationTile({required this.n});

  (IconData, Color) _look(BuildContext context) {
    final c = context.aurora;
    return switch (n.type) {
      NotificationModel.paymentRequest => (Icons.notifications_active_rounded, c.warning),
      NotificationModel.paymentRecorded => (Icons.handshake_rounded, c.positive),
      NotificationModel.expenseAdded => (Icons.receipt_long_rounded, c.primary),
      NotificationModel.expenseEdited => (Icons.edit_rounded, c.secondary),
      NotificationModel.expenseDeleted => (Icons.delete_outline_rounded, c.negative),
      NotificationModel.memberLeft || NotificationModel.memberRemoved => (Icons.person_remove_rounded, c.negative),
      NotificationModel.groupDeleted => (Icons.group_off_rounded, c.negative),
      NotificationModel.groupEdited => (Icons.drive_file_rename_outline_rounded, c.secondary),
      NotificationModel.groupInvite => (Icons.group_add_rounded, c.primary),
      NotificationModel.friendRequest || NotificationModel.friendAccepted => (Icons.person_add_alt_1_rounded, c.primary),
      _ => (Icons.notifications_rounded, c.primary),
    };
  }

  /// Routes each type to the place that makes sense; groups I no longer have
  /// access to show a short explanation instead of an error screen.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(notificationsRepositoryProvider);
    if (!n.isRead) {
      repo.markRead(n.id).catchError((_) {});
    }
    switch (n.type) {
      case NotificationModel.friendRequest:
      case NotificationModel.friendAccepted:
        context.go('/friends');
        return;
      case NotificationModel.groupInvite:
        context.go('/groups');
        return;
    }
    final gid = n.groupId;
    if (gid == null) return;
    final myGroups = ref.read(groupsStreamProvider).valueOrNull ?? const [];
    final stillMember = myGroups.any((g) => g.groupId == gid);
    if (!stillMember || n.type == NotificationModel.groupDeleted) {
      await confirmAction(
        context,
        title: n.groupName ?? 'Group',
        message: n.type == NotificationModel.groupDeleted
            ? 'This group was deleted, so there\'s nothing to open.'
            : 'You\'re no longer a member of this group.',
        confirmLabel: 'OK',
        icon: Icons.info_outline_rounded,
        showCancel: false,
      );
      return;
    }
    final tab = switch (n.type) {
      NotificationModel.paymentRequest || NotificationModel.paymentRecorded => '?tab=balances',
      NotificationModel.memberLeft || NotificationModel.memberRemoved => '?tab=members',
      _ => '',
    };
    if (context.mounted) context.go('/groups/$gid$tab');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final (icon, color) = _look(context);
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xl),
        color: c.negative.withValues(alpha: 0.14),
        child: Icon(Icons.delete_outline_rounded, color: c.negative),
      ),
      onDismissed: (_) => ref.read(notificationsRepositoryProvider).delete(n.id).catchError((e) => Toast.error(e)),
      child: InkWell(
        onTap: () => _open(context, ref),
        child: Container(
          color: n.isRead ? null : c.primary.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.message,
                        style: context.text.bodyMedium?.copyWith(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      [Dates.relative(n.createdAt), if (n.groupName != null) n.groupName!].join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!n.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 6, left: Space.xs),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
