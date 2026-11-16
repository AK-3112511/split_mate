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

  DateTime? _lastMirrorScan;
  static const Duration _resumeScanEvery = Duration(minutes: 1);

  void onAuthChanged(User? user) {
    if (user == null) {
      // Signing back in later (same process) must run again, or shares others
      // settled meanwhile never reach this user's personal ledger.
      _done.clear();
      return;
    }
    if (!isVerified(user) || _done.contains(user.uid)) return;
    _done.add(user.uid);
    _run(user);
  }

  /// App back in the foreground: mirror shares that others settled while we
  /// were away (e.g. a friend marked my payment received). Incremental + throttled.
  void onResumed() {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user == null || !isVerified(user) || !_done.contains(user.uid)) return;
    final last = _lastMirrorScan;
    if (last != null && DateTime.now().difference(last) < _resumeScanEvery) return;
    _lastMirrorScan = DateTime.now();
    _ref.read(mirrorServiceProvider).scanAll().catchError((Object e) {
      debugPrint('Resume mirror scan skipped: $e');
    });
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
    _lastMirrorScan = DateTime.now();
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
