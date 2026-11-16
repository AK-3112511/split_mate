import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/code_chip.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../auth/data/auth_repository.dart';
import '../../friends/presentation/friends_screen.dart' show friendShareText;

/// Name, email, friend code and UPI ID. (v1's "primary currency" did nothing — removed.)
class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _upi = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _upi.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(authRepositoryProvider);
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (_name.text.trim() != profile?.displayName) await repo.updateDisplayName(_name.text);
      if (_upi.text.trim() != (profile?.upiId ?? '')) await repo.updateUpiId(_upi.text);
      Toast.success('Saved');
      if (mounted) context.popOrGo('/profile');
    } catch (e) {
      Toast.error(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? '';
    final verified = ref.watch(authStateProvider).valueOrNull?.emailVerified ?? false;
    if (!_seeded && profile != null) {
      _seeded = true;
      _name.text = profile.displayName;
      _upi.text = profile.upiId ?? '';
    }

    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrGo('/profile')), title: const Text('Personal info')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 120),
          children: [
            AppTextField(
              controller: _name,
              label: 'Display name',
              icon: Icons.person_outline_rounded,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null,
            ),
            const SizedBox(height: Space.md),
            AppCard(
              child: Row(
                children: [
                  const IconBadge(Icons.alternate_email_rounded, size: 40),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email', style: context.text.labelMedium),
                        Text(email, style: context.text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (verified) const Pill('Verified', tone: PillTone.positive, icon: Icons.verified_rounded),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Only you can see your email.', style: context.text.bodySmall),
            ),
            const SizedBox(height: Space.lg),
            CodeChip(
              code: profile?.appCode,
              label: 'Friend code',
              shareText: friendShareText(profile?.displayName ?? '', profile?.appCode ?? ''),
            ),
            const SizedBox(height: Space.xl),
            Text('UPI ID', style: context.text.titleSmall),
            const SizedBox(height: 4),
            Text('Friends who owe you can tap "Pay via UPI" and pay straight from their UPI app.',
                style: context.text.bodySmall),
            const SizedBox(height: Space.sm),
            AppTextField(
              controller: _upi,
              label: 'UPI ID (optional)',
              hint: 'yourname@okaxis',
              icon: Icons.account_balance_wallet_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return null;
                return AuthRepository.upiPattern.hasMatch(t) ? null : 'Looks like name@bank (e.g. riya@okicici)';
              },
            ),
            if (profile?.createdAt != null) ...[
              const SizedBox(height: Space.xl),
              Center(child: Text('Member since ${Dates.monthYear(profile!.createdAt!)}', style: context.text.bodySmall)),
            ],
          ],
        ),
      ),
      // Lifted above the keyboard so Save stays reachable while typing.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              Space.gutter, Space.xs, Space.gutter, Space.sm + MediaQuery.viewInsetsOf(context).bottom),
          child: PrimaryButton(label: 'Save', icon: Icons.check_rounded, loading: _saving, onPressed: _save),
        ),
      ),
    );
  }
}
