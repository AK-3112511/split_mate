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
import '../../../../core/l10n/strings.dart';

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
                                  Money.isZero(myNet) ? context.s.youreAllSettled : (myNet > 0 ? context.s.overallOwed : context.s.overallOwe),
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
                        Expanded(child: Text(_simplified ? context.s.fewestPayments : context.s.whoOwesWhom, style: context.text.titleMedium)),
                        IconButton(
                          tooltip: context.s.shareBalances,
                          icon: const Icon(Icons.ios_share_rounded),
                          onPressed: () => showShareBalancesSheet(
                            context,
                            group: widget.group,
                            debts: debts,
                            simplified: _simplified,
                            expenses: expenses,
                          ),
                        ),
                        Text(context.s.simplify, style: context.text.labelMedium),
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
                          ? context.s.simplifyHelp
                          : context.s.directHelp,
                      style: context.text.bodySmall,
                    ),
                  ),
                ),
                if (debts.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.celebration_rounded,
                      title: context.s.allSettledUpParty,
                      message: context.s.nobodyOwes,
                    ),
                  )
                else ...[
                  SliverList.builder(
                    itemCount: mine.length,
                    itemBuilder: (_, i) => DebtCard(group: widget.group, debt: mine[i], me: me, expenses: expenses)
                        .entrance(context, index: i),
                  ),
                  if (others.isNotEmpty)
                    SliverToBoxAdapter(child: SectionHeader(context.s.betweenOthers)),
                  SliverList.builder(
                    itemCount: others.length,
                    itemBuilder: (_, i) => DebtCard(group: widget.group, debt: others[i], me: me, expenses: expenses),
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

/// One debt with its actions: pay via UPI, show my QR, remind, record.
class DebtCard extends ConsumerWidget {
  final GroupModel group;
  final Transfer debt;
  final String me;
  final List<GroupExpenseModel> expenses;
  final EdgeInsetsGeometry padding;
  const DebtCard({
    super.key,
    required this.group,
    required this.debt,
    required this.me,
    required this.expenses,
    this.padding = const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 0),
  });

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
    final myUpi = owedToMe ? ref.watch(userProfileProvider(me)).valueOrNull?.upiId : null;

    final sentence = iOwe
        ? context.s.youOweName(to)
        : owedToMe
            ? context.s.nameOwesYou(from)
            : context.s.nameOwesName(from, to);

    return Padding(
      padding: padding,
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
                        label: FittedBox(fit: BoxFit.scaleDown, child: Text(context.s.payViaUpi, maxLines: 1)),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                  if (owedToMe) ...[
                    IconButton.outlined(
                      tooltip: context.s.showMyQr,
                      icon: const Icon(Icons.qr_code_2_rounded),
                      onPressed: () {
                        if (myUpi == null || myUpi.isEmpty) {
                          askForUpiId(context);
                          return;
                        }
                        showUpiQrSheet(
                          context,
                          vpa: myUpi,
                          name: ref.read(realNameProvider(me)),
                          amount: debt.amount,
                          note: 'SplitMate · ${group.name}',
                          onReceived: () => showRecordPaymentSheet(context, group: group, debt: debt, expenses: expenses),
                        );
                      },
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: isGuestId(debt.fromUid)
                          // Guests have no SplitMate inbox: WhatsApp only.
                          // Text only: with the QR button there's no room for icons too.
                          ? OutlinedButton(
                              onPressed: () => remindOnWhatsApp(ref, group: group, debt: debt),
                              child: const FittedBox(fit: BoxFit.scaleDown, child: Text('WhatsApp', maxLines: 1)),
                            )
                          : OutlinedButton(
                              onPressed: () => _chooseReminder(context, ref, canRemind),
                              child: FittedBox(fit: BoxFit.scaleDown, child: Text(context.s.remind, maxLines: 1)),
                            ),
                    ),
                    const SizedBox(width: Space.sm),
                  ],
                  Expanded(
                    child: (iOwe && (creditorUpi?.isNotEmpty ?? false))
                        ? OutlinedButton(
                            onPressed: () => showRecordPaymentSheet(context, group: group, debt: debt, expenses: expenses),
                            child: Text(context.s.record),
                          )
                        : FilledButton(
                            onPressed: () => showRecordPaymentSheet(context, group: group, debt: debt, expenses: expenses),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(owedToMe ? context.s.received : context.s.record, maxLines: 1),
                            ),
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
