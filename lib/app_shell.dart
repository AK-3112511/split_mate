import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'core/theme/aurora_colors.dart';
import 'core/utils/haptics.dart';
import 'features/friends/data/friends_repository.dart';
import 'features/groups/data/groups_repository.dart';
import 'core/l10n/strings.dart';

/// Bottom navigation shell. Each tab keeps its own stack & scroll state.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final invites =
        ref.watch(incomingGroupInvitesProvider).valueOrNull?.length ?? 0;
    final requests = ref.watch(incomingFriendRequestCountProvider);

    Widget badged(IconData icon, int count) => count > 0
        ? Badge(label: Text(count > 9 ? '9+' : '$count'), child: Icon(icon))
        : Icon(icon);

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.ink, width: 2.5)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) {
            Haptics.tap();
            // Tapping the active tab returns it to its root.
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: context.s.navHome,
            ),
            NavigationDestination(
              icon: badged(Icons.groups_outlined, invites),
              selectedIcon: badged(Icons.groups_rounded, invites),
              label: context.s.navGroups,
            ),
            NavigationDestination(
              icon: badged(Icons.people_outline_rounded, requests),
              selectedIcon: badged(Icons.people_rounded, requests),
              label: context.s.navFriends,
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: context.s.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}
