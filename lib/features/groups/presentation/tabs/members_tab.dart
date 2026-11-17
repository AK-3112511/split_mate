import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/avatars.dart';
import '../../../../shared_widgets/bits.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/cards.dart';
import '../../../../shared_widgets/code_chip.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../data/balances_providers.dart';
import '../../data/group_expenses_repository.dart';
import '../../data/groups_repository.dart';
import '../../domain/group_model.dart';
import '../../domain/guest.dart';
import '../group_detail_screen.dart' show groupShareText;
import '../widgets/group_sheets.dart';
import '../widgets/guest_sheets.dart';

class MembersTab extends ConsumerWidget {
  final GroupModel group;
  const MembersTab({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUidProvider) ?? '';
    final isAdmin = group.isAdmin(me);
    final pending = ref.watch(groupPendingInvitesProvider(group.groupId)).valueOrNull ?? const [];
    final members = [...group.members]..sort((a, b) {
        if (a == me) return -1;
        if (b == me) return 1;
        final aa = group.isAdmin(a) ? 0 : 1;
        final bb = group.isAdmin(b) ? 0 : 1;
        return aa.compareTo(bb);
      });
    final guests = group.guests.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Builder(
      builder: (context) => CustomScrollView(
        key: const PageStorageKey('members'),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Invite people', style: context.text.titleSmall),
                    const SizedBox(height: 4),
                    Text('Anyone with this code can join instantly.', style: context.text.bodySmall),
                    const SizedBox(height: Space.md),
                    CodeChip(code: group.inviteCode, label: 'Group code', shareText: groupShareText(group)),
                    const SizedBox(height: Space.sm),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Invite friends',
                            icon: Icons.person_add_alt_rounded,
                            onPressed: () => showInviteFriendsSheet(context, group),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: Space.sm),
                          TonalIconButton(
                            tooltip: 'New code (old one stops working)',
                            icon: Icons.refresh_rounded,
                            onPressed: () async {
                              final ok = await confirmAction(
                                context,
                                title: 'Generate a new code?',
                                message: 'The current code will stop working. Members already in the group stay.',
                                confirmLabel: 'New code',
                              );
                              if (!ok) return;
                              try {
                                await ref.read(groupsRepositoryProvider).rotateCode(group);
                                Toast.success('New group code ready');
                              } catch (e) {
                                Toast.error(e);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader('Members', trailing: Text('${members.length}', style: context.text.labelMedium)),
          ),
          SliverList.builder(
            itemCount: members.length,
            itemBuilder: (_, i) => _MemberRow(group: group, uid: members[i], me: me),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              'Not on SplitMate yet',
              trailing: guests.isEmpty ? null : Text('${guests.length}', style: context.text.labelMedium),
            ),
          ),
          SliverList.builder(
            itemCount: guests.length,
            itemBuilder: (_, i) => _GuestRow(group: group, guest: guests[i], me: me),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
              child: SecondaryButton(
                label: 'Add someone without the app',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: () => showAddGuestSheet(context, group),
              ),
            ),
          ),
          if (pending.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Invited')),
            SliverList.builder(
              itemCount: pending.length,
              itemBuilder: (context, i) {
                final inv = pending[i];
                final canCancel = isAdmin || inv.senderUid == me;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  leading: UserAvatar(uid: inv.recipientUid, size: 40),
                  title: Text(ref.watch(realNameProvider(inv.recipientUid))),
                  subtitle: Text('Invited by ${inv.senderName}'),
                  trailing: canCancel
                      ? TextButton(
                          onPressed: () async {
                            try {
                              await ref.read(groupsRepositoryProvider).cancelInvite(inv.inviteId);
                              Toast.info('Invite cancelled');
                            } catch (e) {
                              Toast.error(e);
                            }
                          },
                          child: const Text('Cancel'),
                        )
                      : const Pill('Pending'),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  final GroupModel group;
  final String uid;
  final String me;
  const _MemberRow({required this.group, required this.uid, required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final name = ref.watch(memberNameProvider(uid));
    final realName = ref.watch(realNameProvider(uid));
    final profile = ref.watch(userProfileProvider(uid)).valueOrNull;
    final friends = ref.watch(friendsStreamProvider).valueOrNull ?? const [];
    final edge = friends.where((f) => f.uid == uid).firstOrNull;
    final isAdmin = group.isAdmin(me);
    final balance = ref.watch(groupBalancesProvider(group.groupId)).valueOrNull?.mine[uid] ?? 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 2),
      leading: UserAvatar(uid: uid, size: 44),
      title: Row(
        children: [
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (group.isAdmin(uid)) ...[
            const SizedBox(width: Space.xs),
            const Pill('Admin', tone: PillTone.primary),
          ],
        ],
      ),
      subtitle: Text(
        uid == me
            ? 'That\'s you'
            : Money.isZero(balance)
                ? 'Settled with you'
                : balance > 0
                    ? 'Owes you ${Money.format(balance)}'
                    : 'You owe ${Money.format(-balance)}',
        style: context.text.bodySmall?.copyWith(
          color: uid == me ? c.textMuted : c.amountColor(balance),
        ),
      ),
      trailing: uid == me
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (edge == null && profile?.appCode != null)
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref.read(friendsRepositoryProvider).sendRequest(profile!.appCode!);
                        Toast.success('Friend request sent to $realName');
                      } catch (e) {
                        Toast.error(e);
                      }
                    },
                    child: const Text('Add friend'),
                  ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    tooltip: 'Member options',
                    onSelected: (v) => _onAction(context, ref, v, realName, balance),
                    itemBuilder: (_) => [
                      if (!group.isAdmin(uid))
                        const PopupMenuItem(value: 'admin', child: Text('Make admin'))
                      else
                        const PopupMenuItem(value: 'unadmin', child: Text('Remove admin role')),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove from group', style: TextStyle(color: c.negative)),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action, String name, double balance) async {
    final repo = ref.read(groupsRepositoryProvider);
    try {
      switch (action) {
        case 'admin':
          await repo.setAdmin(group, uid, admin: true);
          Toast.success('$name is now an admin');
        case 'unadmin':
          await repo.setAdmin(group, uid, admin: false);
          Toast.success('$name is no longer an admin');
        case 'remove':
          final net = ref.read(groupBalancesProvider(group.groupId)).valueOrNull?.net[uid] ?? 0;
          final ok = await confirmAction(
            context,
            title: 'Remove $name?',
            message: Money.isZero(net)
                ? '$name will lose access to this group.'
                : '$name still has an unsettled balance of ${Money.format(net.abs())} in this group. '
                    'It stays in the history, but will be harder to settle.',
            confirmLabel: 'Remove',
            destructive: true,
          );
          if (!ok) return;
          await repo.removeMember(group, uid, name);
          Toast.success('$name removed');
      }
    } catch (e) {
      Toast.error(e);
    }
  }
}

/// Someone added to the group who isn't on SplitMate yet.
class _GuestRow extends ConsumerWidget {
  final GroupModel group;
  final GuestMember guest;
  final String me;
  const _GuestRow({required this.group, required this.guest, required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final balance = ref.watch(groupBalancesProvider(group.groupId)).valueOrNull?.mine[guest.id] ?? 0;
    final canManage = guest.addedBy == me || group.isAdmin(me);
    final addedBy = guest.addedBy == me ? 'you' : ref.watch(realNameProvider(guest.addedBy));

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 2),
      leading: UserAvatar(uid: guest.id, size: 44),
      title: Row(
        children: [
          Flexible(child: Text(guest.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: Space.xs),
          const Pill('Guest'),
        ],
      ),
      subtitle: Text(
        Money.isZero(balance)
            ? 'Added by $addedBy'
            : balance > 0
                ? 'Owes you ${Money.format(balance)}'
                : 'You owe ${Money.format(-balance)}',
        style: context.text.bodySmall?.copyWith(color: Money.isZero(balance) ? c.textMuted : c.amountColor(balance)),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Options for ${guest.name}',
        onSelected: (v) => _onAction(context, ref, v),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'share', child: Text('Send ${guest.name} their link')),
          if (canManage) const PopupMenuItem(value: 'link', child: Text('They already joined…')),
          if (canManage) PopupMenuItem(value: 'remove', child: Text('Remove', style: TextStyle(color: c.negative))),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'share':
        await shareGuestClaimLink(group, guest);
      case 'link':
        await showLinkGuestSheet(context, ref, group, guest);
      case 'remove':
        final expenses = ref.read(groupExpensesStreamProvider(group.groupId)).valueOrNull ?? const [];
        final templates = ref.read(groupTemplatesStreamProvider(group.groupId)).valueOrNull ?? const [];
        if ([...expenses, ...templates].any((e) => e.involves(guest.id))) {
          Toast.info('${guest.name} is part of some expenses. If they joined, use "They already joined" instead.');
          return;
        }
        final ok = await confirmAction(
          context,
          title: 'Remove ${guest.name}?',
          message: '${guest.name} isn\'t part of any expense yet.',
          confirmLabel: 'Remove',
          destructive: true,
        );
        if (!ok) return;
        try {
          await ref.read(groupsRepositoryProvider).removeGuest(group, guest.id);
          Toast.success('${guest.name} removed');
        } catch (e) {
          Toast.error(e);
        }
    }
  }
}
