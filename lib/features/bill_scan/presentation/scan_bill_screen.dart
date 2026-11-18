import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared_widgets/avatars.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/states.dart';
import '../../groups/data/groups_repository.dart';
import '../../groups/domain/group_model.dart';

/// "Scan a bill" from the widget or the app shortcut: pick the group, then
/// the camera opens on that group's Add expense screen.
class ScanBillScreen extends ConsumerStatefulWidget {
  const ScanBillScreen({super.key});

  @override
  ConsumerState<ScanBillScreen> createState() => _ScanBillScreenState();
}

class _ScanBillScreenState extends ConsumerState<ScanBillScreen> {
  bool _forwarded = false;

  void _open(GroupModel g) {
    if (_forwarded) return;
    _forwarded = true;
    // `go`, not push: after saving you land in the group, with its back stack.
    context.go('/groups/${g.groupId}/expense/new?scan=1');
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsStreamProvider);
    final groups = groupsAsync.valueOrNull;

    // Only one group: no need to ask.
    if (groups != null && groups.length == 1 && !_forwarded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(groups.first);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan a bill'),
        leading: CloseButton(onPressed: () => context.popOrGo()),
      ),
      body: groups == null
          ? Center(
              child: groupsAsync.hasError
                  ? const EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Couldn\'t load your groups',
                      message: 'Check your connection and try again.',
                    )
                  : const CircularProgressIndicator(),
            )
          : groups.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.group_add_rounded,
                title: 'No groups yet',
                message: 'Bills are split inside a group. Create one, then scan.',
                actionLabel: 'Go to Groups',
                onAction: () => context.go('/groups'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xl),
              children: [
                Text('Which group is this bill for?', style: context.text.titleMedium),
                const SizedBox(height: Space.md),
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: AppCard(
                      onTap: () => _open(g),
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          AvatarStack(uids: g.participants, size: 26),
                          const SizedBox(width: Space.xs),
                          Icon(Icons.chevron_right_rounded, color: context.aurora.textMuted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
