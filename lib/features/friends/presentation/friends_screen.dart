import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/amount_text.dart';
import '../../../shared_widgets/avatars.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/code_chip.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../../shared_widgets/motion.dart';
import '../../../shared_widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../groups/data/balances_providers.dart';
import '../../groups/data/groups_repository.dart';
import '../data/friends_repository.dart';
import '../domain/friend_model.dart';

String friendShareText(String name, String code) =>
    'Add me on SplitMate 💸\nMy friend code: $code\n\nOpen SplitMate → Friends → Add friend → enter $code';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider) ?? '';
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final edgesAsync = ref.watch(friendsStreamProvider);

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
                      Expanded(child: Text('Friends', style: context.text.headlineLarge)),
                      TonalIconButton(
                        icon: Icons.person_add_alt_1_rounded,
                        tooltip: 'Add friend',
                        onPressed: () => showAddFriendSheet(context),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: GradientCard(
                    color: Palette.violet,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR FRIEND CODE', style: context.text.labelSmall?.copyWith(color: context.aurora.onPop, letterSpacing: 1.4)),
                        const SizedBox(height: 2),
                        Text('Share it so friends can add you',
                            style: context.text.bodyMedium?.copyWith(color: context.aurora.onPop, fontWeight: FontWeight.w600)),
                        const SizedBox(height: Space.md),
                        CodeChip(
                          code: profile?.appCode,
                          label: 'Friend code',
                          onGradient: true,
                          shareText: friendShareText(profile?.displayName ?? '', profile?.appCode ?? ''),
                        ),
                      ],
                    ),
                  ).entrance(context),
                ),
              ),
              ...edgesAsync.when(
                loading: () => [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: Space.xl), child: SkeletonList(count: 4)))],
                error: (e, _) => [SliverToBoxAdapter(child: ErrorState(error: e, onRetry: () => ref.invalidate(friendsStreamProvider)))],
                data: (edges) {
                  final incoming = edges.where((f) => f.isIncomingFor(me)).toList();
                  final outgoing = edges.where((f) => f.isOutgoingFor(me)).toList();
                  var friends = edges.where((f) => f.isAccepted).toList();
                  if (_query.isNotEmpty) {
                    final q = _query.toLowerCase();
                    friends = friends.where((f) => ref.read(realNameProvider(f.uid)).toLowerCase().contains(q)).toList();
                  }
                  return [
                    if (incoming.isNotEmpty) ...[
                      SliverToBoxAdapter(child: SectionHeader('Requests', trailing: Pill('${incoming.length} new', tone: PillTone.primary))),
                      SliverList.builder(
                        itemCount: incoming.length,
                        itemBuilder: (_, i) => _RequestCard(edge: incoming[i]).entrance(context, index: i),
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: SectionHeader(
                        'Your friends',
                        trailing: Text('${edges.where((f) => f.isAccepted).length}', style: context.text.labelMedium),
                      ),
                    ),
                    if (edges.where((f) => f.isAccepted).length > 6)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xs),
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v.trim()),
                            decoration: const InputDecoration(
                              hintText: 'Search friends',
                              prefixIcon: Icon(Icons.search_rounded),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    if (friends.isEmpty)
                      SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.people_alt_rounded,
                          title: _query.isEmpty ? 'No friends yet' : 'No matches',
                          message: _query.isEmpty ? 'Add friends with their code to split expenses together.' : null,
                          actionLabel: _query.isEmpty ? 'Add a friend' : null,
                          actionIcon: Icons.person_add_alt_1_rounded,
                          onAction: _query.isEmpty ? () => showAddFriendSheet(context) : null,
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: friends.length,
                        itemBuilder: (_, i) => _FriendRow(edge: friends[i]).entrance(context, index: i),
                      ),
                    if (outgoing.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SectionHeader('Sent requests')),
                      SliverList.builder(
                        itemCount: outgoing.length,
                        itemBuilder: (_, i) => _OutgoingRow(edge: outgoing[i]),
                      ),
                    ],
                  ];
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendRow extends ConsumerWidget {
  final FriendModel edge;
  const _FriendRow({required this.edge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final name = ref.watch(realNameProvider(edge.uid));
    final profile = ref.watch(userProfileProvider(edge.uid)).valueOrNull;
    final balance = ref.watch(friendBalanceProvider(edge.uid));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xs),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        onTap: () => showFriendDetail(context, edge),
        child: Row(
          children: [
            UserAvatar(uid: edge.uid, size: 46),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (edge.nickname != null && profile != null && profile.displayName != edge.nickname)
                    Text(profile.displayName, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (Money.isZero(balance))
              Text('settled', style: context.text.labelMedium)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(balance > 0 ? 'owes you' : 'you owe',
                      style: context.text.labelSmall?.copyWith(color: c.amountColor(balance), letterSpacing: 0)),
                  AmountText(balance, absolute: true, colored: true, style: context.text.titleSmall),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  final FriendModel edge;
  const _RequestCard({required this.edge});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _busy = false;

  Future<void> _act(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final name = ref.read(realNameProvider(widget.edge.uid));
    try {
      if (accept) {
        await ref.read(friendsRepositoryProvider).accept(widget.edge.uid);
        Haptics.success();
        Toast.success('You and $name are now friends 🎉');
      } else {
        await ref.read(friendsRepositoryProvider).remove(widget.edge.uid);
        Toast.info('Request declined');
      }
    } catch (e) {
      Toast.error(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final name = ref.watch(realNameProvider(widget.edge.uid));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
      child: AppCard(
        color: c.primary.withValues(alpha: 0.08),
        child: Row(
          children: [
            UserAvatar(uid: widget.edge.uid, size: 44),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('wants to be friends', style: context.text.bodySmall),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              IconButton.outlined(tooltip: 'Decline', onPressed: () => _act(false), icon: const Icon(Icons.close_rounded)),
              const SizedBox(width: Space.xs),
              IconButton.filled(tooltip: 'Accept', onPressed: () => _act(true), icon: const Icon(Icons.check_rounded)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OutgoingRow extends ConsumerWidget {
  final FriendModel edge;
  const _OutgoingRow({required this.edge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      leading: UserAvatar(uid: edge.uid, size: 40),
      title: Text(ref.watch(realNameProvider(edge.uid))),
      subtitle: const Text('Waiting for them to accept'),
      trailing: TextButton(
        onPressed: () async {
          try {
            await ref.read(friendsRepositoryProvider).remove(edge.uid);
            Toast.info('Request cancelled');
          } catch (e) {
            Toast.error(e);
          }
        },
        child: const Text('Cancel'),
      ),
    );
  }
}

/// Add a friend by their 6-character code (single shared flow).
Future<void> showAddFriendSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _AddFriend());
}

class _AddFriend extends ConsumerStatefulWidget {
  const _AddFriend();

  @override
  ConsumerState<_AddFriend> createState() => _AddFriendState();
}

class _AddFriendState extends ConsumerState<_AddFriend> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final code = FriendsRepository.normalizeCode(_code.text);
    if (code.length != 6) {
      setState(() => _error = 'Friend codes are 6 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(friendsRepositoryProvider).sendRequest(code);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
      Toast.success(res == FriendRequestResult.accepted ? 'You\'re now friends 🎉' : 'Friend request sent');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return SheetBody(
      title: 'Add a friend',
      subtitle: 'Ask for their friend code — it\'s on their Friends tab.',
      children: [
        TextField(
          controller: _code,
          autofocus: true,
          textAlign: TextAlign.center,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
          ],
          style: context.text.headlineMedium?.copyWith(letterSpacing: 8),
          onSubmitted: (_) => _send(),
          decoration: InputDecoration(
            hintText: 'K7Q2MX',
            hintStyle: context.text.headlineMedium?.copyWith(letterSpacing: 8, color: c.textMuted.withValues(alpha: 0.4)),
            counterText: '',
            errorText: _error,
          ),
        ),
        const SizedBox(height: Space.lg),
        PrimaryButton(label: 'Send request', icon: Icons.send_rounded, loading: _busy, onPressed: _send),
      ],
    );
  }
}

/// Friend profile: shared groups, balance, nickname, unfriend.
Future<void> showFriendDetail(BuildContext context, FriendModel edge) {
  return showAppSheet<void>(context, builder: (_) => _FriendDetail(edge: edge));
}

class _FriendDetail extends ConsumerWidget {
  final FriendModel edge;
  const _FriendDetail({required this.edge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final profile = ref.watch(userProfileProvider(edge.uid)).valueOrNull;
    final name = ref.watch(realNameProvider(edge.uid));
    final balance = ref.watch(friendBalanceProvider(edge.uid));
    final groups = (ref.watch(groupsStreamProvider).valueOrNull ?? const []).where((g) => g.members.contains(edge.uid)).toList();

    return SheetBody(
      children: [
        Center(child: UserAvatar(uid: edge.uid, size: 84)),
        const SizedBox(height: Space.sm),
        Center(child: Text(name, style: context.text.titleLarge)),
        if (edge.nickname != null && profile != null)
          Center(child: Text(profile.displayName, style: context.text.bodySmall)),
        const SizedBox(height: Space.lg),
        AppCard(
          color: c.amountColor(balance).withValues(alpha: 0.08),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  Money.isZero(balance) ? 'You\'re all settled' : (balance > 0 ? '$name owes you' : 'You owe $name'),
                  style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (!Money.isZero(balance)) AmountText(balance, absolute: true, colored: true, style: context.text.titleLarge),
            ],
          ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text('Shared groups', style: context.text.titleSmall),
          const SizedBox(height: Space.xs),
          for (final g in groups)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(Icons.groups_rounded, size: 40),
              title: Text(g.name),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.go('/groups/${g.groupId}?tab=balances');
              },
            ),
        ],
        const SizedBox(height: Space.lg),
        SecondaryButton(
          label: edge.nickname == null ? 'Set a nickname' : 'Change nickname',
          icon: Icons.badge_outlined,
          onPressed: () => _nickname(context, ref),
        ),
        const SizedBox(height: Space.sm),
        SecondaryButton(
          label: 'Remove friend',
          icon: Icons.person_remove_outlined,
          color: c.negative,
          onPressed: () async {
            final ok = await confirmAction(
              context,
              title: 'Remove $name?',
              message: Money.isZero(balance)
                  ? 'You can add each other again any time.'
                  : 'You still have an open balance. Shared groups and their balances are not affected.',
              confirmLabel: 'Remove',
              destructive: true,
            );
            if (!ok || !context.mounted) return;
            try {
              await ref.read(friendsRepositoryProvider).remove(edge.uid);
              if (context.mounted) Navigator.of(context).pop();
              Toast.info('$name removed from friends');
            } catch (e) {
              Toast.error(e);
            }
          },
        ),
      ],
    );
  }

  Future<void> _nickname(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: edge.nickname ?? '');
    await showAppSheet<void>(
      context,
      builder: (ctx) => SheetBody(
        title: 'Nickname',
        subtitle: 'Only you see this. Leave empty to use their name.',
        children: [
          AppTextField(controller: controller, label: 'Nickname', maxLength: 24, autofocus: true, textCapitalization: TextCapitalization.words),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'Save',
            onPressed: () async {
              try {
                await ref.read(friendsRepositoryProvider).setNickname(edge.uid, controller.text);
                if (ctx.mounted) Navigator.of(ctx).pop();
                Toast.success('Nickname saved');
              } catch (e) {
                Toast.error(e);
              }
            },
          ),
        ],
      ),
    );
    controller.dispose();
  }
}
