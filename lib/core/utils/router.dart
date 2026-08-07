import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/is_seeding_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/personal_expenses/presentation/expense_list_screen.dart';
import '../../features/personal_expenses/presentation/add_expense_screen.dart';
import '../../features/categories/presentation/category_settings_screen.dart';
import '../../features/groups/presentation/group_list_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/groups/presentation/add_group_expense_screen.dart';
import '../../features/groups/presentation/settlement_screen.dart';
import '../../features/groups/presentation/join_group_screen.dart';
import '../../features/recurring_expenses/presentation/recurring_expenses_screen.dart';
import '../../features/friends/presentation/friends_list_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/personal_info_screen.dart';
import '../../features/notifications/presentation/notifications_list_screen.dart';
import '../../features/profile/presentation/receipts_vault_screen.dart';
import '../../features/personal_expenses/presentation/personal_insights_screen.dart';
import '../../features/groups/presentation/group_insights_screen.dart';
import '../../app.dart';

class RouterNotifier extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  RouterNotifier(Ref ref) {
    // Re-run GoRouter redirect whenever auth state changes
    _subscription = ref.read(firebaseAuthProvider).authStateChanges().listen((_) {
      notifyListeners();
    });
    
    // Re-run GoRouter redirect whenever isAuthSeedingProvider state changes
    ref.listen(isAuthSeedingProvider, (_, __) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerRefreshListenableProvider = Provider<Listenable>((ref) {
  final notifier = RouterNotifier(ref);
  ref.onDispose(() {
    notifier.dispose();
  });
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(routerRefreshListenableProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final user = ref.read(firebaseAuthProvider).currentUser;
      final isSeeding = ref.read(isAuthSeedingProvider);
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      final isVerifyingEmail = state.matchedLocation == '/verify-email';

      if (isSeeding) {
        // Stay on current screen during database seeding
        return null;
      }

      if (user == null) {
        // Not logged in -> send to login page (unless already navigating to login or signup)
        return isLoggingIn ? null : '/login';
      }

      // Check if email/password user needs email verification
      final isGoogleUser = user.providerData.any((p) => p.providerId == 'google.com');
      final requiresVerification = !isGoogleUser && !user.emailVerified;

      if (requiresVerification) {
        return isVerifyingEmail ? null : '/verify-email';
      }

      // Logged in and verified -> redirect to home if on auth/verification pages
      if (isLoggingIn || isVerifyingEmail) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategorySettingsScreen(),
      ),
      GoRoute(
        path: '/profile/personal-info',
        builder: (context, state) => const PersonalInfoScreen(),
      ),
      GoRoute(
        path: '/profile/receipts',
        builder: (context, state) => const ReceiptsVaultScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsListScreen(),
      ),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) {
          final expenseId = state.uri.queryParameters['expenseId'];
          return AddExpenseScreen(editExpenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/recurring-expenses',
        builder: (context, state) => const RecurringExpensesScreen(),
      ),
      GoRoute(
        path: '/personal-insights',
        builder: (context, state) => const PersonalInsightsScreen(),
      ),
      GoRoute(
        path: '/groups/:groupId/insights',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupInsightsScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:groupId/recurring-expenses',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return RecurringExpensesScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:groupId/add-expense',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          final expenseId = state.uri.queryParameters['expenseId'];
          return AddGroupExpenseScreen(groupId: groupId, editExpenseId: expenseId);
        },
      ),
      GoRoute(
        path: '/groups/join',
        builder: (context, state) {
          final groupId = state.uri.queryParameters['groupId'] ?? '';
          final inviteCode = state.uri.queryParameters['inviteCode'] ?? '';
          return JoinGroupScreen(groupId: groupId, inviteCode: inviteCode);
        },
      ),
      GoRoute(
        path: '/groups/:groupId',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return GroupDetailScreen(groupId: groupId);
        },
      ),
      GoRoute(
        path: '/groups/:groupId/settlement',
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return SettlementScreen(groupId: groupId);
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ExpenseListScreen(),
          ),
          GoRoute(
            path: '/groups',
            builder: (context, state) => const GroupListScreen(),
          ),
          GoRoute(
            path: '/friends',
            builder: (context, state) => const FriendsListScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});
