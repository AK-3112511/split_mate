import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _cooldownTimer;
  int _resendCooldown = 0;
  bool _isChecking = false;
  bool _isResending = false;
  bool _isVerified = false;

  late AnimationController _tickController;
  late Animation<double> _tickScaleAnimation;

  @override
  void initState() {
    super.initState();

    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tickScaleAnimation = CurvedAnimation(
      parent: _tickController,
      curve: Curves.elasticOut,
    );

    // Periodically check email verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkEmailVerified(isAutomatic: true);
    });

    // Post-frame fallback dispatch to guarantee email send
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null && !user.emailVerified) {
        user.sendEmailVerification().catchError((_) {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    _tickController.dispose();
    super.dispose();
  }

  Future<void> _checkEmailVerified({bool isAutomatic = false}) async {
    if (_isVerified) return;

    if (!isAutomatic) {
      setState(() {
        _isChecking = true;
      });
    }

    try {
      final currentUser = ref.read(firebaseAuthProvider).currentUser;
      if (currentUser != null) {
        await currentUser.reload();
        final refreshedUser = ref.read(firebaseAuthProvider).currentUser;

        if (refreshedUser != null && refreshedUser.emailVerified) {
          _timer?.cancel();
          setState(() {
            _isVerified = true;
            _isChecking = false;
          });

          // Play smooth animated tick sign
          await _tickController.forward();
          await Future.delayed(const Duration(milliseconds: 1200));

          if (mounted) {
            context.go('/');
          }
          return;
        }
      }

      if (!isAutomatic && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your inbox and tap the link.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!isAutomatic && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking verification: $e'), backgroundColor: AppTheme.semanticNegative),
        );
      }
    } finally {
      if (!isAutomatic && mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification email sent to ${user.email}!'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }

        // Start 60-second resend cooldown
        setState(() {
          _resendCooldown = 60;
        });
        _cooldownTimer?.cancel();
        _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_resendCooldown > 1) {
            setState(() {
              _resendCooldown--;
            });
          } else {
            timer.cancel();
            setState(() {
              _resendCooldown = 0;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend email: $e'),
            backgroundColor: AppTheme.semanticNegative,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final email = user?.email ?? 'your email';

    return Scaffold(
      backgroundColor: AppTheme.surfaceBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Animated Checkmark or Mail Icon
              if (_isVerified)
                ScaleTransition(
                  scale: _tickScaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.semanticPositive.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.semanticPositive, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.semanticPositive,
                      size: 72,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppTheme.accent,
                    size: 56,
                  ),
                ),
              const SizedBox(height: 32),

              // Title Header
              Text(
                _isVerified ? 'EMAIL VERIFIED!' : 'VERIFY YOUR EMAIL',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _isVerified ? AppTheme.semanticPositive : AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle & Explanation
              if (_isVerified)
                Text(
                  'Your account is verified! Redirecting to SplitMate...',
                  style: AppTheme.monoSecondary.copyWith(fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                )
              else ...[
                Text(
                  'A verification link has been sent to:',
                  style: AppTheme.monoSecondary.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    email,
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please check your inbox (and spam folder) and click the link to activate your account.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],

              const Spacer(),

              if (!_isVerified) ...[
                // Refresh Status Button
                InkWell(
                  onTap: _isChecking ? null : () => _checkEmailVerified(isAutomatic: false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                    ),
                    child: Center(
                      child: _isChecking
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Text(
                              'CHECK VERIFICATION STATUS',
                              style: AppTheme.monoStyle.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Resend Email Button
                InkWell(
                  onTap: (_resendCooldown > 0 || _isResending) ? null : _resendVerificationEmail,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      border: Border.all(
                        color: _resendCooldown > 0
                            ? AppTheme.textSecondary.withValues(alpha: 0.2)
                            : AppTheme.accent.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Center(
                      child: _isResending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _resendCooldown > 0
                                  ? 'RESEND EMAIL (${_resendCooldown}s)'
                                  : 'RESEND VERIFICATION EMAIL',
                              style: AppTheme.monoStyle.copyWith(
                                color: _resendCooldown > 0 ? AppTheme.textSecondary : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Logout Button
                TextButton.icon(
                  onPressed: () async {
                    _timer?.cancel();
                    await ref.read(authRepositoryProvider).signOut();
                    if (mounted) {
                      context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.logout_outlined, size: 16, color: AppTheme.semanticNegative),
                  label: Text(
                    'LOGOUT',
                    style: AppTheme.monoStyle.copyWith(
                      color: AppTheme.semanticNegative,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
