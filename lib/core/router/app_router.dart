import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../app_shell.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/is_seeding_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/groups/presentation/add_group_expense_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/group_list_screen.dart';
import '../../features/groups/presentation/join_group_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/personal_expenses/presentation/add_expense_screen.dart';
import '../../features/profile/presentation/delete_account_screen.dart';
import '../../features/profile/presentation/personal_info_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/recap/presentation/recap_screen.dart';
import '../../features/receipts/presentation/receipts_vault_screen.dart';
import '../../features/recurring_expenses/presentation/recurring_screen.dart';
import '../../features/search/presentation/search_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Re-runs redirects whenever auth or the signup-seeding flag changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(isAuthSeedingProvider, (_, __) => notifyListeners());
    ref.listen(splashDoneProvider, (_, __) => notifyListeners());
  }
}

bool isVerified(User user) =>
    user.emailVerified || user.providerData.any((p) => p.providerId != 'password');

/// Only internal paths are accepted as post-login targets.
String? _safeFrom(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = Uri.decodeComponent(raw);
  if (!decoded.startsWith('/') || decoded.startsWith('//')) return null;
  if (decoded.startsWith('/login') || decoded.startsWith('/signup') || decoded.startsWith('/splash')) {
    return null;
  }
  return decoded;
}

/// Locations worth restoring after sign-in: only `/join?code=…` invite links.
bool isInviteLink(String? location) =>
    location != null && Uri.tryParse(location)?.path == '/join';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      if (ref.read(isAuthSeedingProvider)) return null;

      final loc = state.matchedLocation;
      final isAuthPage = loc == '/login' || loc == '/signup';
      final from = _safeFrom(state.uri.queryParameters['from']);
      final here = state.uri.toString();
      String withFrom(String path, String? target) =>
          (target == null || target == '/') ? path : '$path?from=${Uri.encodeComponent(target)}';

      // Let the intro animation finish first (any deep link is kept in ?from=).
      if (!ref.read(splashDoneProvider)) {
        return loc == '/splash' ? null : withFrom('/splash', here);
      }

      if (!auth.hasValue) {
        // Session still restoring: park on the splash, remembering the target.
        return loc == '/splash' ? null : withFrom('/splash', here);
      }

      final user = auth.valueOrNull;
      if (user == null) {
        if (isAuthPage) return null;
        // Only an invite link survives signing in. Any other location is where
        // the previous account was (after sign-out) and may not even be
        // visible to whoever signs in next.
        final target = loc == '/splash' || loc == '/verify-email' ? from : here;
        return withFrom('/login', isInviteLink(target) ? target : null);
      }
      if (!isVerified(user)) {
        if (loc == '/verify-email') return null;
        return withFrom('/verify-email', isAuthPage || loc == '/splash' ? from : here);
      }
      if (isAuthPage || loc == '/verify-email' || loc == '/splash') return from ?? '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),

      // Full-screen flows above the tab bar.
      GoRoute(
        path: '/expense/new',
        builder: (_, s) => AddExpenseScreen(startRecurring: s.uri.queryParameters['recurring'] == '1'),
      ),
      GoRoute(
        path: '/expense/:id/edit',
        builder: (_, s) => AddExpenseScreen(editId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/join',
        builder: (_, s) => JoinGroupScreen(
          code: s.uri.queryParameters['code'] ?? '',
          guestId: s.uri.queryParameters['guest'],
        ),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/categories', builder: (_, __) => const CategoriesScreen()),
      GoRoute(path: '/recurring', builder: (_, __) => const RecurringScreen()),
      GoRoute(path: '/receipts', builder: (_, __) => const ReceiptsVaultScreen()),
      GoRoute(path: '/personal-info', builder: (_, __) => const PersonalInfoScreen()),
      GoRoute(path: '/delete-account', builder: (_, __) => const DeleteAccountScreen()),
      GoRoute(
        path: '/recap',
        builder: (_, s) {
          final m = DateTime.tryParse(s.uri.queryParameters['month'] ?? '');
          return RecapScreen(month: m);
        },
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/groups',
              builder: (_, __) => const GroupListScreen(),
              routes: [
                GoRoute(
                  path: ':groupId',
                  builder: (_, s) => GroupDetailScreen(
                    groupId: s.pathParameters['groupId']!,
                    initialTab: s.uri.queryParameters['tab'],
                  ),
                  routes: [
                    GoRoute(
                      path: 'expense/new',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, s) => AddGroupExpenseScreen(
                        groupId: s.pathParameters['groupId']!,
                        startRecurring: s.uri.queryParameters['recurring'] == '1',
                      ),
                    ),
                    GoRoute(
                      path: 'expense/:expenseId/edit',
                      parentNavigatorKey: rootNavigatorKey,
                      builder: (_, s) => AddGroupExpenseScreen(
                        groupId: s.pathParameters['groupId']!,
                        editId: s.pathParameters['expenseId'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/friends', builder: (_, __) => const FriendsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

extension SafeNav on BuildContext {
  /// Pops when possible, otherwise goes to [fallback] (never "nothing to pop").
  void popOrGo([String fallback = '/']) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
