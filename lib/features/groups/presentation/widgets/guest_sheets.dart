import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/legal.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared_widgets/avatars.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../../shared_widgets/inputs.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../friends/data/friends_repository.dart';
import '../../data/group_expenses_repository.dart';
import '../../data/groups_repository.dart';
import '../../domain/group_model.dart';
import '../../domain/guest.dart';

/// "Add someone without the app". Returns the new guest id, or null.
Future<String?> showAddGuestSheet(BuildContext context, GroupModel group) {
  return showAppSheet<String>(context, builder: (_) => _AddGuestSheet(group: group));
}

class _AddGuestSheet extends ConsumerStatefulWidget {
  final GroupModel group;
  const _AddGuestSheet({required this.group});

  @override
  ConsumerState<_AddGuestSheet> createState() => _AddGuestSheetState();
}

class _AddGuestSheetState extends ConsumerState<_AddGuestSheet> {
  final _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(groupsRepositoryProvider).addGuest(widget.group, _name.text);
      if (!mounted) return;
      Navigator.of(context).pop(id);
      Toast.success('${_name.text.trim()} added. Share their link when they get the app.');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: 'Add someone without the app',
      subtitle: 'Split with them now. When they install SplitMate, they take over their spot and balances.',
      children: [
        AppTextField(
          controller: _name,
          label: 'Their name',
          icon: Icons.person_outline_rounded,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: Space.md),
        PrimaryButton(label: 'Add', icon: Icons.person_add_alt_1_rounded, loading: _saving, onPressed: _add),
      ],
    );
  }
}

/// Shares a link made for [guest]: it joins the group and offers to take over the spot.
Future<void> shareGuestClaimLink(GroupModel group, GuestMember guest) async {
  final code = group.inviteCode;
  if (code == null) {
    Toast.info('This group has no invite code yet. Try again in a moment.');
    return;
  }
  await Share.share(
    'Hi ${guest.name}! I added you to "${group.name}" on SplitMate so we can split expenses.\n\n'
    'Tap to join and take over your spot:\n${guestClaimLink(code, guest.id)}',
  );
}

/// Moves a guest's expenses to a member who already joined (whoever added the
/// guest, or an admin).
Future<void> showLinkGuestSheet(BuildContext context, WidgetRef ref, GroupModel group, GuestMember guest) async {
  final picked = await showAppSheet<String>(
    context,
    builder: (ctx) => SheetBody(
      title: 'Who is ${guest.name}?',
      subtitle: 'Pick the member who is ${guest.name}. Their expenses and balances move to that person.',
      children: [
        for (final uid in group.members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: UserAvatar(uid: uid, size: 40),
            title: Text(ref.watch(realNameProvider(uid))),
            subtitle: uid == ref.read(currentUidProvider) ? const Text('You') : null,
            onTap: () => Navigator.of(ctx).pop(uid),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  final name = ref.read(realNameProvider(picked));
  final ok = await confirmAction(
    context,
    title: 'Move ${guest.name}\'s expenses to $name?',
    message: 'Everything ${guest.name} paid or owes in ${group.name} becomes $name\'s. This can\'t be undone.',
    confirmLabel: 'Move to $name',
    icon: Icons.merge_rounded,
  );
  if (!ok) return;
  try {
    await ref.read(groupExpensesRepositoryProvider).takeOverGuest(group, guest.id, toUid: picked, toName: name);
    Toast.success('${guest.name}\'s expenses now belong to $name');
  } catch (e) {
    Toast.error(e);
  }
}
