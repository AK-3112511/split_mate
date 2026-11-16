import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/feedback.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

/// Waits for the user to click the verification link. The email was already
/// sent at signup (once); this screen only resends when asked.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _checking = false;
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking || _verified) return;
    if (!silent && mounted) setState(() => _checking = true);
    try {
      final ok = await ref.read(authRepositoryProvider).reloadAndCheckVerified();
      if (!mounted) return;
      if (ok) {
        _poll?.cancel();
        setState(() => _verified = true);
        // userChanges() fires after reload → the router moves on automatically.
      } else if (!silent) {
        Toast.info('Not verified yet — tap the link in your email');
      }
    } catch (e) {
      if (!silent) Toast.error(e);
    } finally {
      if (mounted && !silent) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      Toast.success('Verification email sent');
      setState(() => _cooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
    } catch (e) {
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? 'your inbox';
    return AuthScaffold(
      title: _verified ? 'You\'re verified!' : 'Check your email',
      subtitle: _verified ? 'Taking you in…' : 'We sent a verification link to',
      children: [
        Center(
          child: AnimatedSwitcher(
            duration: Motion.slow,
            child: _verified
                ? Icon(Icons.verified_rounded, key: const ValueKey('v'), size: 72, color: c.positive)
                    .animate()
                    .scale(begin: const Offset(0.4, 0.4), curve: Curves.elasticOut, duration: 900.ms)
                : Icon(Icons.mark_email_unread_rounded, key: const ValueKey('m'), size: 64, color: c.primary),
          ),
        ),
        const SizedBox(height: Space.md),
        Text(email, textAlign: TextAlign.center, style: context.text.titleMedium),
        const SizedBox(height: Space.xs),
        Text(
          'Open the link, then come back — we\'ll notice automatically. Check spam if you don\'t see it.',
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'I\'ve verified', icon: Icons.refresh_rounded, loading: _checking, onPressed: _check),
        const SizedBox(height: Space.sm),
        SecondaryButton(
          label: _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
          icon: Icons.forward_to_inbox_rounded,
          onPressed: _cooldown > 0 ? null : _resend,
        ),
        const SizedBox(height: Space.sm),
        TextButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}
