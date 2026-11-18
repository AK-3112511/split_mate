import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/legal.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/write_helper.dart';
import '../../../shared_widgets/avatars.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../../shared_widgets/states.dart';
import '../../auth/data/auth_repository.dart';
import '../../export/export_service.dart';
import '../../friends/data/friends_repository.dart';
import '../data/balances_providers.dart';
import '../data/group_expenses_repository.dart';
import '../data/groups_repository.dart';
import '../domain/group_activity_model.dart';
import '../domain/group_model.dart';
import '../domain/guest.dart';
import 'tabs/balances_tab.dart';
import 'tabs/expenses_tab.dart';
import 'tabs/members_tab.dart';
import 'tabs/stats_tab.dart';
import 'widgets/group_expense_widgets.dart';
import 'widgets/trip_widgets.dart';

String groupShareText(GroupModel g) =>
    'Join "${g.name}" on SplitMate 💸\n\n${groupInviteLink(g.inviteCode ?? '')}\n\n'
    'Or open SplitMate → Groups → Join with a code → ${g.inviteCode}';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? initialTab;
  const GroupDetailScreen({super.key, required this.groupId, this.initialTab});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  static const _tabs = ['expenses', 'balances', 'stats', 'members'];
  late final TabController _tab = TabController(
    length: 4,
    vsync: this,
    initialIndex: _tabs.indexOf(widget.initialTab ?? '').clamp(0, 3),
  );
  bool _codeChecked = false;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailsStreamProvider(widget.groupId));
    return groupAsync.when(
      loading: () => Scaffold(appBar: AppBar(), body: const SkeletonList()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: ErrorState(error: e, onRetry: () => ref.invalidate(groupDetailsStreamProvider(widget.groupId)))),
      ),
      data: (group) {
        if (group == null) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => context.popOrGo('/groups'))),
            body: Center(
              child: EmptyState(
                icon: Icons.group_off_rounded,
                title: 'This group isn\'t available',
                message: 'It was deleted, or you\'re no longer a member.',
                actionLabel: 'Back to groups',
                onAction: () => context.go('/groups'),
              ),
            ),
          );
        }
        if (!_codeChecked) {
          _codeChecked = true;
          final repo = ref.read(groupsRepositoryProvider);
          runInBackground(() => repo.ensureCodeRegistered(group), label: 'code registry');
        }
        return _scaffold(context, group);
      },
    );
  }

  Widget _scaffold(BuildContext context, GroupModel group) {
    final c = context.aurora;
    final me = ref.watch(currentUidProvider) ?? '';
    final balances = ref.watch(groupBalancesProvider(group.groupId)).valueOrNull;
    final myNet = balances?.myNet(me) ?? 0;
    final pop = Palette.popFor(group.groupId);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverAppBar(
              pinned: true,
              expandedHeight: group.isTrip ? 250 : 228,
              foregroundColor: c.onPop,
              backgroundColor: pop,
              iconTheme: IconThemeData(color: c.onPop),
              actionsIconTheme: IconThemeData(color: c.onPop),
              systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
              leading: BackButton(onPressed: () => context.popOrGo('/groups')),
              title: inner ? Text(group.name, style: context.text.titleMedium?.copyWith(color: c.onPop)) : null,
              actions: [
                IconButton(
                  tooltip: 'Activity',
                  icon: const Icon(Icons.history_rounded),
                  onPressed: () => _showActivity(context, group),
                ),
                _menu(context, group, me, balances),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  color: pop,
                  padding: EdgeInsets.fromLTRB(Space.gutter, MediaQuery.paddingOf(context).top + 56, Space.gutter, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(group.name,
                          style: context.text.headlineLarge?.copyWith(color: c.onPop),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (group.isTrip)
                        Row(
                          children: [
                            Icon(Icons.luggage_rounded, size: 16, color: c.onPop),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(tripStatus(group, DateTime.now()),
                                  style: context.text.labelLarge?.copyWith(color: c.onPop),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      const SizedBox(height: Space.xs),
                      Row(
                        children: [
                          AvatarStack(uids: group.participants, size: 26),
                          const SizedBox(width: Space.sm),
                          Expanded(
                            child: Text(
                              balances == null
                                  ? '${group.participants.length} members'
                                  : Money.isZero(myNet)
                                      ? 'You\'re all settled'
                                      : myNet > 0
                                          ? 'You\'re owed ${Money.format(myNet)}'
                                          : 'You owe ${Money.format(-myNet)}',
                              style: context.text.bodyMedium?.copyWith(color: c.onPop, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                    border: Border(top: BorderSide(color: c.ink, width: Brutal.border)),
                  ),
                  child: TabBar(
                    controller: _tab,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.xs),
                    tabs: const [
                      Tab(text: 'Expenses'),
                      Tab(text: 'Balances'),
                      Tab(text: 'Stats'),
                      Tab(text: 'Members'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            ExpensesTab(group: group),
            BalancesTab(group: group),
            StatsTab(group: group),
            MembersTab(group: group),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 3
          ? null
          : PopFab(
              onPressed: () => context.push('/groups/${group.groupId}/expense/new'),
              icon: Icons.add_rounded,
              label: 'Add expense',
            ),
    );
  }

  Widget _menu(BuildContext context, GroupModel group, String me, GroupBalances? balances) {
    final isAdmin = group.isAdmin(me);
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) async {
        switch (v) {
          case 'share':
            await Share.share(groupShareText(group));
          case 'pdf':
            await _exportPdf(group);
          case 'recurring':
            context.push('/recurring');
          case 'trip-summary':
            context.push('/groups/${group.groupId}/trip');
          case 'trip':
            await showTripSettingsSheet(context, group);
          case 'rename':
            await _rename(context, group);
          case 'leave':
            await _leave(context, group, me, balances);
          case 'delete':
            await _delete(context, group, balances);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share_rounded), title: Text('Share invite'))),
        const PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf_rounded), title: Text('Export PDF'))),
        const PopupMenuItem(value: 'recurring', child: ListTile(leading: Icon(Icons.autorenew_rounded), title: Text('Recurring expenses'))),
        if (group.isTrip)
          const PopupMenuItem(value: 'trip-summary', child: ListTile(leading: Icon(Icons.summarize_rounded), title: Text('Trip summary'))),
        if (isAdmin)
          PopupMenuItem(
            value: 'trip',
            child: ListTile(
              leading: const Icon(Icons.luggage_rounded),
              title: Text(group.isTrip ? 'Trip dates & currency' : 'Make it a trip'),
            ),
          ),
        if (isAdmin)
          const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Rename group'))),
        const PopupMenuItem(value: 'leave', child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Leave group'))),
        if (isAdmin)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: context.aurora.negative),
              title: Text('Delete group', style: TextStyle(color: context.aurora.negative)),
            ),
          ),
      ],
    );
  }

  Future<void> _exportPdf(GroupModel group) async {
    final expenses = ref.read(groupExpensesStreamProvider(group.groupId)).valueOrNull;
    if (expenses == null || expenses.isEmpty) {
      Toast.info('Add an expense first — there\'s nothing to export yet.');
      return;
    }
    Toast.info('Preparing PDF…');
    try {
      // Fetch every name explicitly so nobody prints as "Member" while loading.
      final uids = {...group.participants, ...expenses.expand((e) => e.splits.keys), ...expenses.map((e) => e.payerUid)};
      final friends = ref.read(friendsStreamProvider).valueOrNull ?? const [];
      final authRepo = ref.read(authRepositoryProvider);
      final me = ref.read(currentUidProvider);
      final names = <String, String>{};
      for (final u in uids) {
        if (isGuestId(u)) {
          names[u] = group.guests[u]?.name ?? 'Guest';
          continue;
        }
        final nick = friends.where((f) => f.uid == u).firstOrNull?.nickname;
        final profile = await authRepo.streamProfile(u).first.timeout(const Duration(seconds: 5), onTimeout: () => null);
        names[u] = nick ?? profile?.displayName ?? (u == me ? 'Me' : 'Former member');
      }
      await ExportService.shareGroupPdf(
        groupName: group.name,
        expenses: expenses,
        members: group.participants,
        nameOf: (u) => names[u] ?? 'Former member',
      );
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _rename(BuildContext context, GroupModel group) async {
    final controller = TextEditingController(text: group.name);
    var saving = false;
    await showAppSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SheetBody(
          title: 'Rename group',
          children: [
            AppTextField(controller: controller, label: 'Group name', maxLength: 40, autofocus: true),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              label: 'Save',
              loading: saving,
              onPressed: () async {
                set(() => saving = true);
                try {
                  await ref.read(groupsRepositoryProvider).rename(group, controller.text);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  Toast.success('Group renamed');
                } catch (e) {
                  set(() => saving = false);
                  Toast.error(e);
                }
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _leave(BuildContext context, GroupModel group, String me, GroupBalances? balances) async {
    // Say it up front instead of offering "Leave" and then refusing.
    final othersLeft = group.members.any((m) => m != me);
    final otherAdmins = group.activeAdmins.any((a) => a != me);
    if (group.isAdmin(me) && othersLeft && !otherAdmins) {
      await confirmAction(
        context,
        title: 'Make someone else an admin first',
        message: 'You\'re the only admin of ${group.name}. Open Members, make another member an admin, then leave.',
        confirmLabel: 'OK',
        icon: Icons.admin_panel_settings_rounded,
        showCancel: false,
      );
      return;
    }
    final net = balances?.myNet(me) ?? 0;
    final warning = Money.isZero(net)
        ? 'You can rejoin later with the group code.'
        : net > 0
            ? 'You\'re still owed ${Money.format(net)} here. Leaving won\'t erase it, but it\'s harder to settle.'
            : 'You still owe ${Money.format(-net)} here. Please settle up before leaving.';
    final ok = await confirmAction(
      context,
      title: 'Leave ${group.name}?',
      message: warning,
      confirmLabel: 'Leave group',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    try {
      await ref.read(groupsRepositoryProvider).leaveGroup(group);
      router.go('/groups');
      Toast.success('You left ${group.name}');
    } catch (e) {
      Toast.error(e);
    }
  }

  Future<void> _delete(BuildContext context, GroupModel group, GroupBalances? balances) async {
    final open = balances?.pairwise.length ?? 0;
    final ok = await confirmAction(
      context,
      title: 'Delete ${group.name}?',
      message: open > 0
          ? '$open balance${open == 1 ? ' is' : 's are'} still unsettled. Deleting hides the group and its history for everyone.'
          : 'The group and its history will be hidden for everyone. Personal copies of shares stay in each member\'s ledger.',
      confirmLabel: 'Delete group',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    try {
      await ref.read(groupsRepositoryProvider).deleteGroup(group);
      router.go('/groups');
      Toast.success('Group deleted');
    } catch (e) {
      Toast.error(e);
    }
  }

  void _showActivity(BuildContext context, GroupModel group) {
    showAppSheet<void>(
      context,
      scrollable: false,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.75,
        child: _ActivityTimeline(group: group),
      ),
    );
  }
}

class _ActivityTimeline extends ConsumerWidget {
  final GroupModel group;
  const _ActivityTimeline({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final activity = ref.watch(groupActivityStreamProvider(group.groupId));
    final expenses = ref.watch(groupExpensesStreamProvider(group.groupId)).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
          child: Text('Activity', style: context.text.titleLarge),
        ),
        Expanded(
          child: activity.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(error: e),
            data: (items) => items.isEmpty
                ? const EmptyState(icon: Icons.history_rounded, title: 'Nothing yet', compact: true)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final a = items[i];
                      final linked = a.expenseId == null
                          ? null
                          : expenses.where((e) => e.expenseId == a.expenseId).firstOrNull;
                      final color = switch (a.type) {
                        GroupActivityModel.expenseDeleted || GroupActivityModel.memberRemoved => c.negative,
                        GroupActivityModel.settledUp => c.positive,
                        _ => c.primary,
                      };
                      return InkWell(
                        borderRadius: Radii.tile,
                        onTap: linked == null ? null : () => showGroupExpenseDetail(context, group, linked),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                                child: Icon(activityIcon(a.type), color: color, size: 18),
                              ),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.message, style: context.text.bodyMedium),
                                    const SizedBox(height: 2),
                                    Text('${Dates.relative(a.createdAt)} · ${Dates.time(a.createdAt)}', style: context.text.bodySmall),
                                  ],
                                ),
                              ),
                              if (linked != null) Icon(Icons.chevron_right_rounded, color: c.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
