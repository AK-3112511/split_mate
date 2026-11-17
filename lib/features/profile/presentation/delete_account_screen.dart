import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/legal.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/money.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../auth/data/account_deletion_service.dart';
import '../../friends/data/friends_repository.dart';
import '../../groups/data/balances_providers.dart';

/// Profile → Delete account. Blocked while the user owes anyone money.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _step;
  String? _error;
  List<ReauthMethod>? _methods;
  ReauthMethod? _method;

  @override
  void initState() {
    super.initState();
    ref.read(accountDeletionServiceProvider).reauthMethods().then((m) {
      if (!mounted) return;
      setState(() {
        _methods = m;
        _method = m.isEmpty ? null : m.first;
      });
    });
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final method = _method;
    if (method == null) return;
    if (method == ReauthMethod.password && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Delete your account?',
      message: 'Your profile, personal expenses, friends and notifications will be erased. This can\'t be undone.',
      confirmLabel: 'Delete forever',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !mounted) return;
    final service = ref.read(accountDeletionServiceProvider);
    setState(() {
      _busy = true;
      _error = null;
      _step = 'Confirming it\'s you';
    });
    try {
      await service.reauthenticate(method, password: _password.text);
      await service.deleteAccount(onStep: (s) {
        if (mounted) setState(() => _step = s);
      });
      Toast.success('Your account has been deleted');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final balance = ref.watch(overallBalanceProvider);
    final method = _method;
    final owes = balance.iOwe > 0;
    final canDelete = !_busy && !balance.loading && !owes && method != null;
    final other = (_methods ?? const <ReauthMethod>[]).where((m) => m != method).firstOrNull;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: Text(text, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        );
    Widget line(IconData icon, String text, Color color) => Padding(
          padding: const EdgeInsets.only(bottom: Space.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: Space.xs),
              Expanded(child: Text(text, style: context.text.bodyMedium)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? null : () => context.popOrGo('/profile')),
        title: const Text('Delete account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.xxl),
        children: [
          Text('This permanently deletes your SplitMate account. It can\'t be undone.', style: context.text.bodyLarge),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('What gets deleted'),
                line(Icons.close_rounded, 'Your profile, photo, friend code and UPI ID', c.negative),
                line(Icons.close_rounded, 'Your personal expenses, categories, budgets and receipts', c.negative),
                line(Icons.close_rounded, 'Your friends list and your notifications', c.negative),
                line(Icons.close_rounded, 'Your sign-in (email or Google)', c.negative),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('What stays'),
                line(Icons.groups_rounded,
                    'Expenses you shared in groups stay in those groups, so the other members\' balances stay correct. You\'ll appear there as "Deleted user".',
                    c.textMuted),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          if (balance.loading)
            Text('Checking your balances…', style: context.text.bodyMedium?.copyWith(color: c.textMuted))
          else if (owes)
            AppCard(
              color: c.negativeFill,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading('Settle up first'),
                  Text(
                    'You owe ${Money.format(balance.iOwe)}. Pay it, or record the payment, before deleting your account so nobody is left unpaid.',
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  for (final e in balance.byPerson.entries)
                    if (e.value < 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.xxs),
                        child: Row(children: [
                          Expanded(child: Text(ref.watch(memberNameProvider(e.key)), style: context.text.bodyLarge)),
                          Text(Money.format(-e.value), style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                        ]),
                      ),
                  const SizedBox(height: Space.sm),
                  SecondaryButton(label: 'Go to groups', icon: Icons.groups_rounded, onPressed: () => context.go('/groups')),
                ],
              ),
            )
          else if (balance.owedToMe > 0)
            AppCard(
              color: c.warning.withValues(alpha: 0.18),
              child: Text(
                'Friends still owe you ${Money.format(balance.owedToMe)}. If you delete your account, you won\'t be able to collect it in SplitMate.',
                style: context.text.bodyMedium,
              ),
            ),
          const SizedBox(height: Space.lg),
          if (method == ReauthMethod.password)
            AppTextField(
              controller: _password,
              label: 'Your password',
              icon: Icons.lock_rounded,
              obscure: true,
              enabled: !_busy && !owes,
              autofillHints: const [AutofillHints.password],
            )
          else if (method == ReauthMethod.google)
            Text('You\'ll confirm with your Google account.', style: context.text.bodyMedium)
          else if (_methods != null)
            Text('To delete this account, email $supportEmail.', style: context.text.bodyMedium),
          if (other != null && !_busy && !owes)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _method = other;
                  _error = null;
                }),
                child: Text(other == ReauthMethod.google ? 'Confirm with Google instead' : 'Use your password instead'),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: Space.sm),
            Text(_error!, style: context.text.bodyMedium?.copyWith(color: c.negative)),
          ],
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'Delete my account',
            icon: Icons.delete_forever_rounded,
            color: c.negative,
            loading: _busy,
            onPressed: canDelete ? _delete : null,
          ),
          if (_busy && _step != null) ...[
            const SizedBox(height: Space.sm),
            Center(child: Text('$_step…', style: context.text.bodySmall)),
          ],
          const SizedBox(height: Space.lg),
          Center(
            child: TextButton(onPressed: openPrivacyPolicy, child: const Text('Privacy policy')),
          ),
        ],
      ),
    );
  }
}
