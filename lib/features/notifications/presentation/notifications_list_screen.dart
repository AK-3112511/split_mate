import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../data/notifications_repository.dart';
import '../domain/notification_model.dart';

class NotificationsListScreen extends ConsumerWidget {
  const NotificationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final notificationsAsync = ref.watch(userNotificationsStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'NOTIFICATIONS',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
        ),
        actions: [
          if (user != null)
            TextButton.icon(
              onPressed: () async {
                await ref.read(notificationsRepositoryProvider).markAllAsRead(user.uid);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read.'),
                      backgroundColor: AppTheme.accent,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.done_all, size: 16, color: AppTheme.accent),
              label: Text(
                'MARK ALL READ',
                style: AppTheme.monoStyle.copyWith(
                  color: AppTheme.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Divider(
            color: AppTheme.textSecondary.withValues(alpha: 0.15),
            height: 1.0,
            thickness: 1.0,
          ),
        ),
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                        ),
                        child: const Icon(
                          Icons.notifications_none_outlined,
                          size: 48,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'NO NOTIFICATIONS YET',
                        style: AppTheme.monoStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Payment clearance requests and group alerts will appear here.',
                        style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(context, ref, notification);
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accent)),
          ),
          error: (err, stack) => Center(
            child: Text(
              'Failed to load notifications: $err',
              style: const TextStyle(color: AppTheme.semanticNegative),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) {
    final timeStr = DateFormat('MMM dd, yyyy • HH:mm').format(notification.createdAt);

    return InkWell(
      onTap: () async {
        // Mark notification as read
        await ref.read(notificationsRepositoryProvider).markAsRead(notification.id);

        // Redirect to settlement screen if groupId exists
        if (notification.groupId.isNotEmpty && context.mounted) {
          context.push('/groups/${notification.groupId}/settlement');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppTheme.surfaceCard.withValues(alpha: 0.2)
              : AppTheme.accent.withValues(alpha: 0.08),
          border: Border.all(
            color: notification.isRead
                ? AppTheme.textSecondary.withValues(alpha: 0.15)
                : AppTheme.accent.withValues(alpha: 0.6),
            width: notification.isRead ? 1.0 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                border: Border.all(
                  color: notification.isRead
                      ? AppTheme.textSecondary.withValues(alpha: 0.3)
                      : AppTheme.accent,
                ),
              ),
              child: Icon(
                notification.type == 'payment_request'
                    ? Icons.payments_outlined
                    : notification.type == 'member_left' || notification.type == 'member_removed'
                        ? Icons.person_remove_outlined
                        : notification.type == 'group_edited'
                            ? Icons.edit_note_outlined
                            : notification.type == 'group_deleted'
                                ? Icons.delete_forever_outlined
                                : Icons.notifications_active_outlined,
                color: notification.isRead ? AppTheme.textSecondary : AppTheme.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.groupName.toUpperCase(),
                        style: AppTheme.monoStyle.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: AppTheme.accent,
                          child: Text(
                            'NEW',
                            style: AppTheme.monoStyle.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: notification.isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeStr,
                        style: AppTheme.monoSecondary.copyWith(fontSize: 10),
                      ),
                      Row(
                        children: [
                          Text(
                            'VIEW SETTLEMENT',
                            style: AppTheme.monoStyle.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios, size: 10, color: AppTheme.accent),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
