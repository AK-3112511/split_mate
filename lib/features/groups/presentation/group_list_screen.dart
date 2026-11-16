import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/amount_text.dart';
import '../../../shared_widgets/avatars.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/motion.dart';
import '../../../shared_widgets/states.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/domain/notification_model.dart';
import '../data/balances_providers.dart';
import '../data/groups_repository.dart';
import '../domain/group_invite_model.dart';
import '../domain/group_model.dart';
import 'widgets/group_sheets.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    final invites = ref.watch(incomingGroupInvitesProvider).valueOrNull ?? const <GroupInviteModel>[];

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.lg),
                  child: Row(
                    children: [
                      Expanded(child: Text('Groups', style: context.text.headlineLarge)),
                      TonalIconButton(
                        icon: Icons.qr_code_2_rounded,
                        tooltip: 'Join with a code',
                        onPressed: () => showJoinByCodeSheet(context),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: const _OverviewCard().entrance(context)),
              if (invites.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SectionHeader('Invitations')),
                SliverList.builder(
                  itemCount: invites.length,
                  itemBuilder: (_, i) => _InviteCard(invite: invites[i]).entrance(context, index: i),
                ),
              ],
              ...groupsAsync.when(
                loading: () => [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: Space.xl), child: SkeletonList(count: 4)))],
                error: (e, _) => [
                  SliverToBoxAdapter(child: ErrorState(error: e, onRetry: () => ref.invalidate(groupsStreamProvider))),
                ],
                data: (groups) => groups.isEmpty
                    ? [
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const EmptyState(
                                icon: Icons.groups_rounded,
                                title: 'No groups yet',
                                message: 'Create one for your flat, a trip or office lunches — or join with a code.',
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
                                child: Column(
                                  children: [
                                    PrimaryButton(
                                      label: 'Create a group',
                                      icon: Icons.add_rounded,
                                      onPressed: () => showCreateGroupSheet(context),
                                    ),
                                    const SizedBox(height: Space.sm),
                                    SecondaryButton(
                                      label: 'Join with a code',
                                      icon: Icons.qr_code_2_rounded,
                                      onPressed: () => showJoinByCodeSheet(context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                    : [
                        SliverToBoxAdapter(child: SectionHeader('Your groups', trailing: Text('${groups.length}', style: context.text.labelMedium))),
                        SliverList.builder(
                          itemCount: groups.length,
                          itemBuilder: (_, i) => _GroupCard(group: groups[i]).entrance(context, index: i),
                        ),
                      ],
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        ),
      ),
      floatingActionButton: PopFab(
        onPressed: () => showCreateGroupSheet(context),
        icon: Icons.group_add_rounded,
        label: 'New group',
      ),
    );
  }
}

class _OverviewCard extends ConsumerWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(overallBalanceProvider);
    final settled = Money.isZero(b.owedToMe) && Money.isZero(b.iOwe);
    final c = context.aurora;
    if (settled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: GradientCard(
          color: c.positiveFill,
          child: Row(
            children: [
              Icon(Icons.celebration_rounded, size: 34, color: c.onPop),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All settled up', style: context.text.titleLarge?.copyWith(color: c.onPop)),
                    Text('No one owes anyone. Nice.',
                        style: context.text.bodyMedium?.copyWith(color: c.onPop, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          Expanded(child: _stat(context, 'You\'re owed', b.owedToMe, Icons.south_west_rounded, c.positiveFill)),
          const SizedBox(width: Space.md),
          Expanded(child: _stat(context, 'You owe', b.iOwe, Icons.north_east_rounded, c.negativeFill)),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, double v, IconData icon, Color fill) {
    final c = context.aurora;
    return GradientCard(
      color: fill,
      padding: const EdgeInsets.all(Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(color: c.onPop, letterSpacing: 0.8),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: Space.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AmountText(v, animate: true, style: context.text.headlineMedium?.copyWith(color: c.onPop)),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final GroupModel group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(overallBalanceProvider.select((b) => b.byGroup[group.groupId]));
    final c = context.aurora;
    Widget pill;
    if (balance == null) {
      pill = const SizedBox(width: 60, child: Skeleton(child: SkeletonBox(height: 20)));
    } else if (Money.isZero(balance)) {
      pill = const Pill('Settled', tone: PillTone.neutral, icon: Icons.check_rounded);
    } else if (balance > 0) {
      pill = Pill('Owed ${Money.format(balance)}', tone: PillTone.positive);
    } else {
      pill = Pill('You owe ${Money.format(-balance)}', tone: PillTone.negative);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
      child: AppCard(
        onTap: () => context.go('/groups/${group.groupId}'),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.popFor(group.groupId),
                borderRadius: Radii.tile,
                border: c.thinBorder,
              ),
              child: Text(
                group.name.characters.first.toUpperCase(),
                style: context.text.titleLarge?.copyWith(color: c.onPop),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      AvatarStack(uids: group.members, size: 22),
                      const SizedBox(width: Space.xs),
                      Flexible(child: pill),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            Icon(Icons.chevron_right_rounded, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  final GroupInviteModel invite;
  const _InviteCard({required this.invite});

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _act(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final repo = ref.read(groupsRepositoryProvider);
    final router = GoRouter.of(context);
    // Read up front: this card is gone once the invite is handled.
    final notify = ref.read(notificationsRepositoryProvider);
    final inbox = ref.read(userNotificationsStreamProvider).valueOrNull ?? const [];
    try {
      if (accept) {
        await repo.acceptInvite(widget.invite);
        Toast.success('You joined ${widget.invite.groupName} 🎉');
        router.go('/groups/${widget.invite.groupId}');
      } else {
        await repo.declineInvite(widget.invite.inviteId);
        Toast.info('Invitation declined');
      }
      notify.markRequestHandled(inbox, type: NotificationModel.groupInvite, groupId: widget.invite.groupId);
    } catch (e) {
      Toast.error(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
      child: AppCard(
        color: c.primary.withValues(alpha: 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(uid: widget.invite.senderUid, size: 40),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: widget.invite.senderName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const TextSpan(text: ' invited you to '),
                      TextSpan(text: widget.invite.groupName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: 'Decline', onPressed: _busy ? null : () => _act(false))),
                const SizedBox(width: Space.sm),
                Expanded(child: PrimaryButton(label: 'Join', loading: _busy, onPressed: () => _act(true))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
