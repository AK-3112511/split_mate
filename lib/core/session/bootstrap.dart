import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/groups/data/group_mirror_service.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../router/app_router.dart';
import '../utils/recurring_engine.dart';

/// Runs once per signed-in, verified user per app launch:
/// profile migration → recurring instances → personal mirrors → housekeeping.
/// Every step is isolated so one failure (e.g. offline) never blocks the rest.
class SessionBootstrap {
  final Ref _ref;
  final Set<String> _done = {};

  SessionBootstrap(this._ref);

  void onAuthChanged(User? user) {
    if (user == null || !isVerified(user) || _done.contains(user.uid)) return;
    _done.add(user.uid);
    _run(user);
  }

  Future<void> _run(User user) async {
    Future<void> step(String name, Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        debugPrint('Bootstrap "$name" skipped: $e');
      }
    }

    await step('profile', () => _ref.read(authRepositoryProvider).ensureProfile(user));
    await step('recurring', () => _ref.read(recurringEngineProvider).run(user.uid));
    await step('mirrors', () => _ref.read(mirrorServiceProvider).scanAll());
    await step('notifications', () => _ref.read(notificationsRepositoryProvider).cleanupOld(user.uid));
  }
}

final sessionBootstrapProvider = Provider<SessionBootstrap>((ref) {
  final b = SessionBootstrap(ref);
  ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) => b.onAuthChanged(next.valueOrNull),
      fireImmediately: true);
  return b;
});
