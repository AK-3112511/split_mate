import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/domain/settlement.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared_widgets/amount_text.dart';
import '../../../../shared_widgets/avatars.dart';
import '../../../../shared_widgets/bits.dart';
import '../../../../shared_widgets/cards.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../../shared_widgets/motion.dart';
import '../../../../shared_widgets/states.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../../notifications/data/notifications_repository.dart';
import '../../data/balances_providers.dart';
import '../../data/group_expenses_repository.dart';
import '../../domain/group_expense_model.dart';
import '../../domain/group_model.dart';
import '../../domain/guest.dart';
import '../widgets/settle_up.dart';
import '../widgets/share_balances.dart';

class BalancesTab extends ConsumerStatefulWidget {
  final GroupModel group;
  const BalancesTab({super.key, required this.group});

  @override
  ConsumerState<BalancesTab> createState() => _BalancesTabState();
}

class _BalancesTabState extends ConsumerState<BalancesTab> with AutomaticKeepAliveClientMixin {
  bool _simplified = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.aurora;
    final me = ref.watch(currentUidProvider) ?? '';
    final balancesAsync = ref.watch(groupBalancesProvider(widget.group.groupId));
    final expenses = ref.watch(groupExpensesStreamProvider(widget.group.groupId)).valueOrNull ?? const <GroupExpenseModel>[];

    return Builder(
      builder: (context) => CustomScrollView(
        key: const PageStorageKey('balances'),
        slivers: [
          SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
          ...balancesAsync.when(
            loading: () => [const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: Space.lg), child: SkeletonList(count: 3)))],
            error: (e, _) => [SliverToBoxAdapter(child: ErrorState(error: e))],
            data: (b) {
              final debts = _simplified ? b.simplified : b.pairwise;
              final mine = debts.where((d) => d.fromUid == me || d.toUid == me).toList();
              final others = debts.where((d) => d.fromUid != me && d.toUid != me).toList();
              final myNet = b.myNet(me);
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                    child: AppCard(
                      child: Row(
                        children: [
                          IconBadge(
                            Money.isZero(myNet)
                                ? Icons.check_circle_rounded
                                : myNet > 0
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                            size: 48,
                            color: c.amountColor(myNet),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Money.isZero(myNet) ? 'You\'re all settled' : (myNet > 0 ? 'Overall, you\'re owed' : 'Overall, you owe'),
                                  style: context.text.labelMedium,
                                ),
                                if (!Money.isZero(myNet))
                                  AmountText(myNet, absolute: true, colored: true, animate: true, style: context.text.headlineSmall),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).entrance(context),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, Space.xs),
                    child: Row(
                      children: [
                        Expanded(child: Text(_simplified ? 'Fewest payments' : 'Who owes whom', style: context.text.titleMedium)),
                        IconButton(
                          tooltip: 'Share balances',
                          icon: const Icon(Icons.ios_share_rounded),
                          onPressed: () => showShareBalancesSheet(
                            context,
                            group: widget.group,
                            debts: debts,
                            simplified: _simplified,
                            expenses: expenses,
                          ),
                        ),
                        Text('Simplify', style: context.text.labelMedium),
                        Switch(value: _simplified, onChanged: (v) => setState(() => _simplified = v)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: Text(
                      _simplified
                          ? 'Suggests the fewest transfers to clear the whole group. People may pay someone they didn\'t share with directly.'
                          : 'Direct balances from expenses you actually shared. Settling these keeps everyone\'s personal ledger accurate.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ),
                if (debts.isEmpty)
                  const SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.celebration_rounded,
                      title: 'All settled up 🎉',
                      message: 'Nobody owes anybody in this group.',
                    ),
                  )
                else ...[
                  SliverList.builder(
                    itemCount: mine.length,
                    itemBuilder: (_, i) => _DebtCard(group: widget.group, debt: mine[i], me: me, expenses: expenses)
                        .entrance(context, index: i),
                  ),
                  if (others.isNotEmpty)
                    const SliverToBoxAdapter(child: SectionHeader('Between others')),
                  SliverList.builder(
                    itemCount: others.length,
                    itemBuilder: (_, i) => _DebtCard(group: widget.group, debt: others[i], me: me, expenses: expenses),
                  ),
                ],
              ];
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  final GroupModel group;
  final Transfer debt;
  final String me;
  final List<GroupExpenseModel> expenses;
  const _DebtCard({required this.group, required this.debt, required this.me, required this.expenses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final from = ref.watch(memberNameProvider(debt.fromUid));
    final to = ref.watch(memberNameProvider(debt.toUid));
    final iOwe = debt.fromUid == me;
    final owedToMe = debt.toUid == me;
    // Guests (not on SplitMate yet) have no UPI ID and can't get reminders.
    final creditorUpi = iOwe && !isGuestId(debt.toUid) ? ref.watch(userProfileProvider(debt.toUid)).valueOrNull?.upiId : null;
    final lastReminder = owedToMe
        ? ref.watch(lastReminderProvider((groupId: group.groupId, recipientUid: debt.fromUid))).valueOrNull
        : null;
    final canRemind = NotificationsRepository.canRemind(lastReminder);

    final sentence = iOwe
        ? 'You owe $to'
        : owedToMe
            ? '$from owes you'
            : '$from owes $to';

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
      child: AppCard(
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 64,
                  height: 40,
                  child: Stack(children: [
                    UserAvatar(uid: debt.fromUid, size: 40),
                    Positioned(left: 26, child: UserAvatar(uid: debt.toUid, size: 40, ring: true)),
                  ]),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(sentence,
                      style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                AmountText(
                  debt.amount,
                  style: context.text.titleMedium?.copyWith(
                    color: iOwe ? c.negative : (owedToMe ? c.positive : c.text),
                  ),
                ),
              ],
            ),
            if (iOwe || owedToMe) ...[
              const SizedBox(height: Space.md),
              Row(
                children: [
                  if (iOwe && creditorUpi != null && creditorUpi.isNotEmpty) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => payViaUpi(context, ref,
                            group: group, debt: debt, expenses: expenses, vpa: creditorUpi),
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Pay via UPI', maxLines: 1)),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                  if (owedToMe) ...[
                    Expanded(
                      child: isGuestId(debt.fromUid)
                          // Guests have no SplitMate inbox: WhatsApp only.
                          ? OutlinedButton.icon(
                              onPressed: () => remindOnWhatsApp(ref, group: group, debt: debt),
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: const Text('WhatsApp'),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _chooseReminder(context, ref, canRemind),
                              icon: const Icon(Icons.notifications_active_outlined, size: 18),
                              label: const Text('Remind'),
                            ),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                  Expanded(
                    child: (iOwe && (creditorUpi?.isNotEmpty ?? false))
                        ? OutlinedButton(
                            onPressed: () => showRecordPaymentSheet(context, group: group, debt: debt, expenses: expenses),
                            child: const Text('Record'),
                          )
                        : FilledButton(
                            onPressed: () => showRecordPaymentSheet(context, group: group, debt: debt, expenses: expenses),
                            child: Text(owedToMe ? 'Received' : 'Record', maxLines: 1),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Members can be reminded in SplitMate (once a day) or on WhatsApp.
  Future<void> _chooseReminder(BuildContext context, WidgetRef ref, bool canRemind) async {
    final name = ref.read(realNameProvider(debt.fromUid));
    final choice = await showAppSheet<String>(
      context,
      builder: (ctx) => SheetBody(
        title: 'Remind $name',
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('In SplitMate'),
            subtitle: Text(canRemind ? 'Sends them a notification in the app' : 'Already reminded today'),
            enabled: canRemind,
            onTap: () => Navigator.of(ctx).pop('app'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chat_rounded),
            title: const Text('On WhatsApp'),
            subtitle: const Text('Opens WhatsApp with a message and a pay link'),
            onTap: () => Navigator.of(ctx).pop('whatsapp'),
          ),
        ],
      ),
    );
    if (choice == 'app') await sendReminder(ref, group: group, debt: debt);
    if (choice == 'whatsapp') await remindOnWhatsApp(ref, group: group, debt: debt);
  }
}
