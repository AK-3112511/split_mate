import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared_widgets/avatars.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../../shared_widgets/inputs.dart';
import '../../../friends/data/friends_repository.dart';
import '../../data/groups_repository.dart';
import '../../domain/group_model.dart';

/// Create a group and (optionally) invite friends. Navigates into it after.
Future<void> showCreateGroupSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _CreateGroup());
}

class _CreateGroup extends ConsumerStatefulWidget {
  const _CreateGroup();

  @override
  ConsumerState<_CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends ConsumerState<_CreateGroup> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = await ref.read(groupsRepositoryProvider).createGroup(_name.text, _selected.toList());
      Haptics.success();
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go('/groups/$id');
      Toast.success(_selected.isEmpty ? 'Group created' : 'Group created · invites sent');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(acceptedFriendsProvider);
    return SheetBody(
      title: 'New group',
      subtitle: 'Trips, flatmates, office lunches…',
      children: [
        Form(
          key: _form,
          child: AppTextField(
            controller: _name,
            label: 'Group name',
            hint: 'e.g. Goa Trip 🌴',
            icon: Icons.groups_rounded,
            maxLength: 40,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Give your group a name' : null,
          ),
        ),
        const SizedBox(height: Space.lg),
        Text('Invite friends', style: context.text.titleSmall),
        const SizedBox(height: Space.xs),
        if (friends.isEmpty)
          Text('Add friends from the Friends tab, or share the group code after creating it.',
              style: context.text.bodySmall)
        else
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final f in friends)
                FilterChip(
                  avatar: UserAvatar(uid: f.uid, size: 24),
                  label: Text(ref.watch(realNameProvider(f.uid))),
                  selected: _selected.contains(f.uid),
                  onSelected: (v) => setState(() => v ? _selected.add(f.uid) : _selected.remove(f.uid)),
                ),
            ],
          ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Create group', icon: Icons.check_rounded, loading: _saving, onPressed: _create),
      ],
    );
  }
}

/// Enter a 6-character group code to join.
Future<void> showJoinByCodeSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _JoinByCode());
}

class _JoinByCode extends ConsumerStatefulWidget {
  const _JoinByCode();

  @override
  ConsumerState<_JoinByCode> createState() => _JoinByCodeState();
}

class _JoinByCodeState extends ConsumerState<_JoinByCode> {
  final _code = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = GroupsRepository.normalizeCode(_code.text);
    if (code.length != 6) {
      setState(() => _error = 'Group codes are 6 characters');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final res = await ref.read(groupsRepositoryProvider).joinByCode(code);
      Haptics.success();
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go('/groups/${res.groupId}');
      Toast.success(res.alreadyMember ? 'You\'re already in ${res.groupName}' : 'Welcome to ${res.groupName}! 🎉');
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return SheetBody(
      title: 'Join a group',
      subtitle: 'Ask a member for the 6-character group code.',
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
          onSubmitted: (_) => _join(),
          decoration: InputDecoration(
            hintText: 'ABC123',
            hintStyle: context.text.headlineMedium?.copyWith(letterSpacing: 8, color: c.textMuted.withValues(alpha: 0.4)),
            counterText: '',
            errorText: _error,
          ),
        ),
        const SizedBox(height: Space.lg),
        PrimaryButton(label: 'Join group', icon: Icons.login_rounded, loading: _joining, onPressed: _join),
      ],
    );
  }
}

/// Invite friends who aren't in the group yet.
Future<void> showInviteFriendsSheet(BuildContext context, GroupModel group) {
  return showAppSheet<void>(context, builder: (_) => _InviteFriends(group: group));
}

class _InviteFriends extends ConsumerStatefulWidget {
  final GroupModel group;
  const _InviteFriends({required this.group});

  @override
  ConsumerState<_InviteFriends> createState() => _InviteFriendsState();
}

class _InviteFriendsState extends ConsumerState<_InviteFriends> {
  final Set<String> _selected = {};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final pending = (ref.watch(groupPendingInvitesProvider(widget.group.groupId)).valueOrNull ?? const [])
        .map((i) => i.recipientUid)
        .toSet();
    final candidates = ref
        .watch(acceptedFriendsProvider)
        .where((f) => !widget.group.members.contains(f.uid) && !pending.contains(f.uid))
        .toList();
    return SheetBody(
      title: 'Invite friends',
      subtitle: 'They\'ll get an invite to accept. Not on SplitMate yet? Add them below Members with "Add someone without the app".',
      children: [
        if (candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Text('All your friends are already here or invited.', style: context.text.bodyMedium),
          )
        else
          for (final f in candidates)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selected.contains(f.uid),
              onChanged: (v) => setState(() => v == true ? _selected.add(f.uid) : _selected.remove(f.uid)),
              secondary: UserAvatar(uid: f.uid, size: 40),
              title: Text(ref.watch(realNameProvider(f.uid))),
            ),
        const SizedBox(height: Space.lg),
        PrimaryButton(
          label: _selected.isEmpty ? 'Select friends' : 'Send ${_selected.length} invite${_selected.length == 1 ? '' : 's'}',
          icon: Icons.send_rounded,
          loading: _sending,
          onPressed: _selected.isEmpty
              ? null
              : () async {
                  setState(() => _sending = true);
                  try {
                    await ref.read(groupsRepositoryProvider).sendInvites(widget.group, _selected.toList());
                    if (context.mounted) Navigator.of(context).pop();
                    Toast.success('Invites sent');
                  } catch (e) {
                    if (mounted) setState(() => _sending = false);
                    Toast.error(e);
                  }
                },
        ),
      ],
    );
  }
}
