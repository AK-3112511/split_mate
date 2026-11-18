import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/legal.dart';
import '../../../core/security/app_lock.dart';
import '../../../core/settings/device_settings.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/image_codec.dart';
import '../../../shared_widgets/avatars.dart';
import '../../../shared_widgets/bits.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/inputs.dart';
import '../../../shared_widgets/motion.dart';
import '../../auth/data/auth_repository.dart';
import '../../friends/data/friends_repository.dart';
import '../../groups/data/groups_repository.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../personal_expenses/data/expense_repository.dart';
import 'export_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.aurora;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final user = ref.watch(authStateProvider).valueOrNull;
    final groups = ref.watch(groupsStreamProvider).valueOrNull?.length ?? 0;
    final friends = ref.watch(acceptedFriendsProvider).length;
    final now = DateTime.now();
    final thisMonth = (ref.watch(personalExpensesProvider).valueOrNull ?? const [])
        .where((e) => Dates.isSameMonth(e.date, now))
        .length;
    final unread = ref.watch(unreadNotificationCountProvider);
    final isPasswordUser = ref.read(authRepositoryProvider).isPasswordUser;

    Widget stat(String label, int v) => Expanded(
          child: Column(
            children: [
              Text('$v', style: context.text.titleLarge),
              Text(label, style: context.text.labelMedium),
            ],
          ),
        );

    Widget tile(IconData icon, String title, {String? subtitle, VoidCallback? onTap, Widget? trailing, Color? color}) =>
        ListTile(
          leading: IconBadge(icon, size: 40, color: color),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: c.textMuted),
          onTap: onTap,
        );

    Widget section(String title, List<Widget> children, int index) => Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: Space.xxs, bottom: Space.xs),
                child: Text(title.toUpperCase(),
                    style: context.text.titleSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
              ),
              AppCard(padding: const EdgeInsets.symmetric(vertical: Space.xxs), child: Column(children: children)),
            ],
          ).entrance(context, index: index),
        );

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 140),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
                child: Text(context.s.profile, style: context.text.headlineLarge),
              ),
              const SizedBox(height: Space.lg),
              Center(
                child: GestureDetector(
                  onTap: () => _changePhoto(context, ref, hasPhoto: profile?.photoData != null),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c.cta,
                          shape: BoxShape.circle,
                          border: c.inkBorder,
                          boxShadow: c.hardShadow(),
                        ),
                        child: PersonAvatar(
                          seed: user?.uid ?? '',
                          name: profile?.displayName ?? user?.displayName,
                          photo: profile?.avatar,
                          size: 96,
                          ring: true,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Palette.violet, shape: BoxShape.circle, border: c.thinBorder),
                          child: Icon(Icons.photo_camera_rounded, size: 16, color: c.onPop),
                        ),
                      ),
                    ],
                  ),
                ),
              ).entrance(context),
              const SizedBox(height: Space.sm),
              Center(child: Text(profile?.displayName ?? user?.displayName ?? '', style: context.text.titleLarge)),
              Center(child: Text(user?.email ?? '', style: context.text.bodySmall)),
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AppCard(
                  child: Row(children: [
                    stat(context.s.statGroups, groups),
                    stat(context.s.statFriends, friends),
                    stat(context.s.statThisMonth, thisMonth),
                  ]),
                ),
              ),
              section(context.s.account, [
                tile(Icons.badge_rounded, context.s.personalInfo,
                    subtitle: context.s.personalInfoSub, onTap: () => context.push('/personal-info')),
                tile(Icons.notifications_rounded, context.s.notifications,
                    onTap: () => context.push('/notifications'),
                    trailing: unread > 0 ? Badge(label: Text('$unread')) : null),
                if (isPasswordUser)
                  tile(Icons.lock_reset_rounded, context.s.changePassword, onTap: () => _changePassword(context, ref)),
                tile(Icons.privacy_tip_rounded, context.s.privacyPolicy,
                    trailing: Icon(Icons.open_in_new_rounded, color: c.textMuted), onTap: openPrivacyPolicy),
              ], 1),
              section(context.s.money, [
                tile(Icons.category_rounded, context.s.categoriesBudgets, onTap: () => context.push('/categories')),
                tile(Icons.autorenew_rounded, context.s.recurringExpenses, onTap: () => context.push('/recurring')),
                tile(Icons.receipt_long_rounded, context.s.receipts, onTap: () => context.push('/receipts')),
                tile(Icons.auto_awesome_rounded, context.s.monthlyRecap,
                    subtitle: context.s.monthInReview(Dates.monthName(DateTime(now.year, now.month - 1))),
                    onTap: () => context.push('/recap')),
                tile(Icons.ios_share_rounded, context.s.exportData, subtitle: 'CSV / PDF', onTap: () => showExportSheet(context)),
              ], 2),
              section(context.s.appearance, [
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const IconBadge(Icons.palette_rounded, size: 40),
                        const SizedBox(width: Space.md),
                        Text(context.s.theme, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: Space.sm),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                              value: ThemeMode.system,
                              label: Text(context.s.themeAuto),
                              icon: const Icon(Icons.brightness_auto_rounded, size: 18)),
                          ButtonSegment(
                              value: ThemeMode.light,
                              label: Text(context.s.themeLight),
                              icon: const Icon(Icons.light_mode_rounded, size: 18)),
                          ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text(context.s.themeDark),
                              icon: const Icon(Icons.dark_mode_rounded, size: 18)),
                        ],
                        selected: {ref.watch(themeModeProvider)},
                        onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                      ),
                      const SizedBox(height: Space.lg),
                      Row(children: [
                        const IconBadge(Icons.translate_rounded, size: 40),
                        const SizedBox(width: Space.md),
                        Text(context.s.language, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: Space.sm),
                      SegmentedButton<AppLanguage>(
                        showSelectedIcon: false,
                        segments: [
                          for (final l in AppLanguage.values)
                            ButtonSegment(
                              value: l,
                              label: FittedBox(fit: BoxFit.scaleDown, child: Text(l.label, maxLines: 1)),
                            ),
                        ],
                        selected: {ref.watch(appLanguageProvider)},
                        onSelectionChanged: (s) => ref.read(appLanguageProvider.notifier).set(s.first),
                      ),
                    ],
                  ),
                ),
              ], 3),
              section(context.s.privacySecurity, [
                SwitchListTile(
                  secondary: const IconBadge(Icons.fingerprint_rounded, size: 40),
                  title: Text(context.s.appLock),
                  subtitle: Text(context.s.appLockSub),
                  value: ref.watch(appLockEnabledProvider),
                  onChanged: (on) async {
                    if (on) {
                      if (!await AppLock.available()) {
                        Toast.show(S.current.appLockNoDevice, type: ToastType.error);
                        return;
                      }
                      // Prove it works before relying on it.
                      if (!await AppLock.authenticate(S.current.unlockReason)) return;
                    }
                    await ref.read(appLockEnabledProvider.notifier).set(on);
                    Toast.success(on ? S.current.appLockOn : S.current.appLockOff);
                  },
                ),
                SwitchListTile(
                  secondary: const IconBadge(Icons.bug_report_rounded, size: 40),
                  title: Text(context.s.crashReports),
                  subtitle: Text(context.s.crashReportsSub),
                  value: ref.watch(crashReportsProvider),
                  onChanged: (on) => ref.read(crashReportsProvider.notifier).set(on),
                ),
              ], 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
                child: SecondaryButton(
                  label: context.s.signOut,
                  icon: Icons.logout_rounded,
                  color: c.negative,
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: context.s.signOutQ,
                      message: context.s.signOutBody,
                      confirmLabel: context.s.signOut,
                      icon: Icons.logout_rounded,
                    );
                    if (!ok) return;
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                    } catch (e) {
                      Toast.error(e);
                    }
                  },
                ),
              ),
              const SizedBox(height: Space.sm),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/delete-account'),
                  style: TextButton.styleFrom(foregroundColor: c.negative),
                  child: Text(context.s.deleteAccount),
                ),
              ),
              const SizedBox(height: Space.lg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref, {required bool hasPhoto}) {
    Future<void> pick(BuildContext ctx, ImageSource source) async {
      Navigator.of(ctx).pop();
      try {
        final img = await ImageCodec.pickAvatar(source);
        if (img == null) return;
        await ref.read(authRepositoryProvider).updatePhoto(img);
        Toast.success('Photo updated');
      } catch (e) {
        Toast.error(e);
      }
    }

    return showAppSheet<void>(
      context,
      builder: (ctx) => SheetBody(
        title: 'Profile photo',
        subtitle: 'Friends and group members see this.',
        children: [
          ListTile(
            leading: const IconBadge(Icons.photo_camera_rounded, size: 40),
            title: const Text('Take a photo'),
            onTap: () => pick(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const IconBadge(Icons.photo_library_rounded, size: 40),
            title: const Text('Choose from gallery'),
            onTap: () => pick(ctx, ImageSource.gallery),
          ),
          if (hasPhoto)
            ListTile(
              leading: IconBadge(Icons.delete_outline_rounded, size: 40, color: ctx.aurora.negative),
              title: const Text('Remove photo'),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(authRepositoryProvider).updatePhoto(null);
                } catch (e) {
                  Toast.error(e);
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final form = GlobalKey<FormState>();
    var saving = false;
    await showAppSheet<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SheetBody(
          title: 'Change password',
          children: [
            Form(
              key: form,
              child: Column(
                children: [
                  AppTextField(
                    controller: current,
                    label: 'Current password',
                    obscure: true,
                    icon: Icons.lock_outline_rounded,
                    validator: (v) => (v?.isEmpty ?? true) ? 'Enter your current password' : null,
                  ),
                  const SizedBox(height: Space.md),
                  AppTextField(
                    controller: next,
                    label: 'New password',
                    obscure: true,
                    icon: Icons.lock_reset_rounded,
                    validator: (v) => (v?.length ?? 0) < 6 ? 'Use at least 6 characters' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              label: 'Update password',
              loading: saving,
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                set(() => saving = true);
                try {
                  await ref.read(authRepositoryProvider).changePassword(current: current.text, next: next.text);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  Toast.success('Password updated');
                } catch (e) {
                  set(() => saving = false);
                  Toast.error(e);
                }
              },
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
  }
}
