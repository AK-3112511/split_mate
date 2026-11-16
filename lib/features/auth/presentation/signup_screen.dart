import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _requireTerms() {
    if (_agreed) return true;
    setState(() => _error = 'Please accept the Terms & Privacy Policy to continue.');
    return false;
  }

  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();
    final valid = _form.currentState!.validate();
    if (!valid || !_requireTerms()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
          );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (!_requireTerms()) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _showTerms() {
    showAppSheet<void>(
      context,
      builder: (ctx) => SheetBody(
        title: 'Terms & privacy, in short',
        children: [
          for (final line in const [
            'SplitMate helps you track expenses and split bills with friends. It never moves money for you.',
            'Your personal expenses are visible only to you. Group expenses are visible to members of that group.',
            'Friends see your name, photo, friend code and UPI ID (if you add one) — never your email.',
            'Data is stored in Google Firebase. You can delete your expenses at any time.',
            'Use SplitMate responsibly and only add people who agreed to share expenses with you.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: ctx.aurora.positive),
                  const SizedBox(width: Space.xs),
                  Expanded(child: Text(line, style: ctx.text.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: Space.sm),
          PrimaryButton(
            label: 'I agree',
            onPressed: () {
              setState(() {
                _agreed = true;
                _error = null;
              });
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final from = GoRouterState.of(context).uri.queryParameters;
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Split bills, track spending, stay friends',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Already have an account?', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
          TextButton(
            onPressed: () => context.go(Uri(path: '/login', queryParameters: from.isEmpty ? null : from).toString()),
            child: const Text('Sign in'),
          ),
        ],
      ),
      children: [
        FormErrorBanner(_error),
        AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              children: [
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  maxLength: 40,
                  validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null,
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                ),
                const SizedBox(height: Space.md),
                AppTextField(
                  controller: _password,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) => _signUp(),
                  validator: (v) => (v?.length ?? 0) < 6 ? 'Use at least 6 characters' : null,
                  suffix: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        InkWell(
          borderRadius: Radii.tile,
          onTap: () => setState(() {
            _agreed = !_agreed;
            if (_agreed) _error = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.xs),
            child: Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() {
                    _agreed = v ?? false;
                    if (_agreed) _error = null;
                  }),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: context.text.bodyMedium?.copyWith(color: c.textMuted),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms & Privacy Policy',
                          style: TextStyle(color: c.primary, fontWeight: FontWeight.w700),
                          recognizer: TapGestureRecognizer()..onTap = _showTerms,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        PrimaryButton(label: 'Create account', loading: _loading, onPressed: _googleLoading ? null : _signUp),
        const OrDivider(),
        GoogleButton(onPressed: _loading ? null : _google, loading: _googleLoading),
      ],
    );
  }
}
