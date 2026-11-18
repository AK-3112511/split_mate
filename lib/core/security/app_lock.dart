import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:material_ui/material_ui.dart';
import '../../shared_widgets/buttons.dart';
import '../../shared_widgets/logo_mark.dart';
import '../l10n/strings.dart';
import '../settings/device_settings.dart';
import '../theme/tokens.dart';

/// Fingerprint (or the phone's PIN / pattern) unlock.
class AppLock {
  AppLock._();
  static final _auth = LocalAuthentication();

  /// True when the phone has a screen lock or biometrics we can ask for.
  static Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows the system prompt. Phone PIN / pattern is allowed as a fallback.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

/// Locks after the app has been in the background this long (and on start).
const lockAfter = Duration(seconds: 60);

/// Wraps the whole app; when app lock is on it covers everything with the
/// lock screen on start and after [lockAfter] in the background.
class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  late bool _locked = ref.read(appLockEnabledProvider);
  bool _authenticating = false;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The fingerprint prompt itself pauses the app: ignore those events.
    if (_authenticating || !ref.read(appLockEnabledProvider)) return;
    if (state == AppLifecycleState.hidden || state == AppLifecycleState.paused) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (!_locked && left != null && DateTime.now().difference(left) >= lockAfter) {
        setState(() => _locked = true);
        WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    // Screen lock removed from the phone since: don't lock people out.
    if (!await AppLock.available()) {
      await ref.read(appLockEnabledProvider.notifier).set(false);
      if (mounted) setState(() => _locked = false);
      return;
    }
    setState(() => _authenticating = true);
    final ok = await AppLock.authenticate(S.current.unlockReason);
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _locked = false;
    });
    _leftAt = null;
  }

  @override
  Widget build(BuildContext context) {
    // Turning the lock off elsewhere unlocks straight away.
    ref.listen<bool>(appLockEnabledProvider, (_, on) {
      if (!on && _locked) setState(() => _locked = false);
    });
    return Stack(
      children: [
        // Keep the app alive underneath, but out of reach while locked.
        ExcludeSemantics(excluding: _locked, child: IgnorePointer(ignoring: _locked, child: widget.child)),
        if (_locked) Positioned.fill(child: _LockScreen(busy: _authenticating, onUnlock: _unlock)),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool busy;
  final VoidCallback onUnlock;
  const _LockScreen({required this.busy, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Material(
      color: Palette.yellow,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            children: [
              const Spacer(),
              const LogoMark(size: 112),
              const SizedBox(height: Space.xl),
              Text(s.lockedTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Palette.ink, fontWeight: FontWeight.w800)),
              const SizedBox(height: Space.xs),
              Text(s.lockedBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Palette.ink)),
              const Spacer(),
              PrimaryButton(label: s.unlock, icon: Icons.fingerprint_rounded, loading: busy, onPressed: onUnlock),
              const SizedBox(height: Space.md),
            ],
          ),
        ),
      ),
    );
  }
}
