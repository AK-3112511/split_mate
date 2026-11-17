import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/domain/settlement.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../data/group_expenses_repository.dart';
import '../data/groups_repository.dart';

final _codePreviewProvider = FutureProvider.autoDispose.family<GroupCodeInfo, String>((ref, code) {
  return ref.watch(groupsRepositoryProvider).lookupCode(code);
});

/// Opened from an invite link (https://…/join?code=… or splitmate://join?code=…).
/// A link made for a guest (`&guest=guest_…`) also offers to take over that
/// guest's spot once joined.
class JoinGroupScreen extends ConsumerStatefulWidget {
  final String code;
  final String? guestId;
  const JoinGroupScreen({super.key, required this.code, this.guestId});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final res = await ref.read(groupsRepositoryProvider).joinByCode(widget.code);
      Haptics.success();
      if (!mounted) return;
      final tookOver = await _offerTakeover(res.groupId);
      if (!mounted) return;
      context.go('/groups/${res.groupId}');
      if (!tookOver) {
        Toast.success(res.alreadyMember ? 'You\'re already in ${res.groupName}' : 'Welcome to ${res.groupName}! 🎉');
      }
    } catch (e) {
      if (mounted) setState(() => _joining = false);
      Toast.error(e);
    }
  }

  /// "Are you Rahul?" for links made for a guest. Returns true if taken over.
  Future<bool> _offerTakeover(String groupId) async {
    final guestId = widget.guestId;
    if (guestId == null || guestId.isEmpty) return false;
    try {
      final group = await ref.read(groupsRepositoryProvider).fetchGroup(groupId);
      final guest = group?.guests[guestId];
      if (group == null || guest == null || !mounted) return false;

      final expenses = await ref.read(groupExpensesRepositoryProvider).fetchExpenses(groupId);
      var paise = 0;
      Settlement.pairwiseFor(guestId, expenses).forEach((_, v) => paise += Money.toPaise(v));
      final net = Money.fromPaise(paise);
      final summary = Money.isZero(net)
          ? '${guest.name} is settled up'
          : net > 0
              ? '${guest.name} is owed ${Money.format(net)}'
              : '${guest.name} owes ${Money.format(-net)}';
      if (!mounted) return false;

      final yes = await confirmAction(
        context,
        title: 'Are you ${guest.name}?',
        message: '${guest.name} was added to ${group.name} before joining ($summary). '
            'If that\'s you, everything ${guest.name} paid or owes becomes yours.',
        confirmLabel: 'Yes, I\'m ${guest.name}',
        icon: Icons.how_to_reg_rounded,
      );
      if (!yes) return false;
      await ref.read(groupExpensesRepositoryProvider).takeOverGuest(
            group,
            guestId,
            toUid: ref.read(currentUidProvider) ?? '',
            toName: ref.read(notificationsRepositoryProvider).senderName,
          );
      Toast.success('Welcome, ${guest.name}! Your expenses in ${group.name} are now yours.');
      return true;
    } catch (e) {
      Toast.error(e);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final preview = ref.watch(_codePreviewProvider(widget.code));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group invite'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.popOrGo('/groups'),
        ),
      ),
      body: AuroraBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: preview.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => EmptyState(
                icon: Icons.link_off_rounded,
                title: 'This invite doesn\'t work',
                message: friendlyError(e),
                actionLabel: 'Go to groups',
                onAction: () => context.go('/groups'),
              ),
              data: (info) => AppCard(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Palette.popFor(info.groupId),
                        borderRadius: Radii.card,
                        border: c.inkBorder,
                        boxShadow: c.hardShadow(),
                      ),
                      child: Text(info.groupName.characters.first.toUpperCase(),
                          style: context.text.headlineLarge?.copyWith(color: c.onPop)),
                    ),
                    const SizedBox(height: Space.md),
                    Text('You\'re invited to', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(info.groupName, textAlign: TextAlign.center, style: context.text.headlineSmall),
                    const SizedBox(height: Space.xs),
                    Text('Code ${info.code}', style: context.text.labelMedium),
                    const SizedBox(height: Space.xl),
                    PrimaryButton(label: 'Join group', icon: Icons.login_rounded, loading: _joining, onPressed: _join),
                    const SizedBox(height: Space.sm),
                    SecondaryButton(label: 'Not now', onPressed: () => context.popOrGo('/groups')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
