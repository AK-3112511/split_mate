import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared_widgets/cards.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../groups/data/groups_repository.dart';
import '../../../groups/presentation/group_detail_screen.dart';
import '../../../groups/presentation/widgets/group_sheets.dart';
import '../../../personal_expenses/data/expense_repository.dart';

/// First-run guide on Home: create a group → add an expense → invite friends.
/// Each step ticks itself off; the card goes away when all three are done or
/// when hidden. Shown to new accounts (first two weeks) and to anyone who
/// hasn't made a group or an expense yet.
class GetStartedCard extends ConsumerStatefulWidget {
  const GetStartedCard({super.key});

  @override
  ConsumerState<GetStartedCard> createState() => _GetStartedCardState();
}

class _GetStartedCardState extends ConsumerState<GetStartedCard> {
  bool? _hidden;

  String _key(String uid) => 'guide_hidden_$uid';

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final groups = ref.watch(groupsStreamProvider).valueOrNull;
    final expenses = ref.watch(personalExpensesProvider).valueOrNull;
    final friends = ref.watch(acceptedFriendsProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    if (uid == null || groups == null || expenses == null) return const SizedBox.shrink();

    _hidden ??= _read(prefs, _key(uid));
    final hasGroup = groups.isNotEmpty;
    final hasExpense = expenses.isNotEmpty;
    final invited = friends.isNotEmpty || groups.any((g) => g.participants.length > 1);
    final created = profile?.createdAt;
    final isNew = created == null || DateTime.now().difference(created).inDays < 14;
    final relevant = isNew || !hasGroup || !hasExpense;
    if (_hidden! || !relevant || (hasGroup && hasExpense && invited)) return const SizedBox.shrink();

    final s = context.s;
    final c = context.aurora;
    final firstGroup = hasGroup ? groups.first : null;
    final done = [hasGroup, hasExpense, invited].where((d) => d).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
      child: AppCard(
        color: c.cta,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.getStarted,
                      style: context.text.titleLarge?.copyWith(color: c.onPop, fontWeight: FontWeight.w800)),
                ),
                Text('$done/3', style: context.text.labelLarge?.copyWith(color: c.onPop)),
                TextButton(
                  onPressed: () {
                    setState(() => _hidden = true);
                    try {
                      prefs?.setBool(_key(uid), true);
                    } catch (_) {}
                  },
                  child: Text(s.hideGuide, style: TextStyle(color: c.onPop)),
                ),
              ],
            ),
            Text(s.getStartedBody, style: context.text.bodyMedium?.copyWith(color: c.onPop)),
            const SizedBox(height: Space.sm),
            _Step(
              n: 1,
              done: hasGroup,
              title: s.stepGroup,
              subtitle: s.stepGroupSub,
              onTap: () => showCreateGroupSheet(context),
            ),
            _Step(
              n: 2,
              done: hasExpense,
              title: s.stepExpense,
              subtitle: s.stepExpenseSub,
              onTap: () => context.push(firstGroup == null ? '/expense/new' : '/groups/${firstGroup.groupId}/expense/new'),
            ),
            _Step(
              n: 3,
              done: invited,
              title: s.stepInvite,
              subtitle: s.stepInviteSub,
              onTap: () => firstGroup == null ? context.go('/friends') : Share.share(groupShareText(firstGroup)),
            ),
          ],
        ),
      ),
    );
  }

  static bool _read(dynamic prefs, String key) {
    try {
      return prefs?.getBool(key) == true;
    } catch (_) {
      return false;
    }
  }
}

class _Step extends StatelessWidget {
  final int n;
  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _Step({required this.n, required this.done, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return InkWell(
      onTap: done ? null : onTap,
      borderRadius: Radii.tile,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? Palette.mint : c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.ink, width: Brutal.borderThin),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 20, color: Palette.ink)
                  : Text('$n', style: context.text.titleSmall?.copyWith(color: Palette.ink, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyLarge?.copyWith(
                      color: c.onPop,
                      fontWeight: FontWeight.w700,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(subtitle, style: context.text.bodySmall?.copyWith(color: c.onPop)),
                ],
              ),
            ),
            if (!done) Icon(Icons.arrow_forward_rounded, color: c.onPop),
          ],
        ),
      ),
    );
  }
}
