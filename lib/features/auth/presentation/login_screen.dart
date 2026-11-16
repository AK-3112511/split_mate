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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text);
      // The router redirects once auth state updates.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
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

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    var sending = false;
    await showAppSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SheetBody(
          title: 'Reset your password',
          subtitle: 'We\'ll email you a link to choose a new password.',
          children: [
            Form(
              key: formKey,
              child: AppTextField(
                controller: controller,
                label: 'Email',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
                autofillHints: const [AutofillHints.email],
                autofocus: controller.text.isEmpty,
              ),
            ),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              label: 'Send reset link',
              icon: Icons.send_rounded,
              loading: sending,
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                setSheet(() => sending = true);
                try {
                  await ref.read(authRepositoryProvider).sendPasswordReset(controller.text);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  Toast.success('Check your inbox for the reset link');
                } catch (e) {
                  setSheet(() => sending = false);
                  Toast.error(e);
                }
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to keep your splits in sync',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('New to SplitMate?', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
          TextButton(
            onPressed: () {
              final qp = GoRouterState.of(context).uri.queryParameters;
              context.go(Uri(path: '/signup', queryParameters: qp.isEmpty ? null : qp).toString());
            },
            child: const Text('Create account'),
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
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _signIn(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _forgotPassword, child: const Text('Forgot password?')),
        ),
        const SizedBox(height: Space.xs),
        PrimaryButton(label: 'Sign in', loading: _loading, onPressed: _googleLoading ? null : _signIn),
        const OrDivider(),
        GoogleButton(onPressed: _loading ? null : _google, loading: _googleLoading),
      ],
    );
  }
}
