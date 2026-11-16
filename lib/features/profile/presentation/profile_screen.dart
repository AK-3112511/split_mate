import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
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
                child: Text('Profile', style: context.text.headlineLarge),
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
                    stat('Groups', groups),
                    stat('Friends', friends),
                    stat('This month', thisMonth),
                  ]),
                ),
              ),
              section('Account', [
                tile(Icons.badge_rounded, 'Personal info', subtitle: 'Name, friend code, UPI ID', onTap: () => context.push('/personal-info')),
                tile(Icons.notifications_rounded, 'Notifications',
                    onTap: () => context.push('/notifications'),
                    trailing: unread > 0 ? Badge(label: Text('$unread')) : null),
                if (isPasswordUser)
                  tile(Icons.lock_reset_rounded, 'Change password', onTap: () => _changePassword(context, ref)),
              ], 1),
              section('Money', [
                tile(Icons.category_rounded, 'Categories & budgets', onTap: () => context.push('/categories')),
                tile(Icons.autorenew_rounded, 'Recurring expenses', onTap: () => context.push('/recurring')),
                tile(Icons.receipt_long_rounded, 'Receipts', onTap: () => context.push('/receipts')),
                tile(Icons.auto_awesome_rounded, 'Monthly recap',
                    subtitle: 'Your ${Dates.monthName(DateTime(now.year, now.month - 1))} in review',
                    onTap: () => context.push('/recap')),
                tile(Icons.ios_share_rounded, 'Export my data', subtitle: 'CSV or PDF', onTap: () => showExportSheet(context)),
              ], 2),
              section('Appearance', [
                Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const IconBadge(Icons.palette_rounded, size: 40),
                        const SizedBox(width: Space.md),
                        Text('Theme', style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: Space.sm),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto_rounded, size: 18)),
                          ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded, size: 18)),
                          ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded, size: 18)),
                        ],
                        selected: {ref.watch(themeModeProvider)},
                        onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                      ),
                    ],
                  ),
                ),
              ], 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
                child: SecondaryButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
                  color: c.negative,
                  onPressed: () async {
                    final ok = await confirmAction(
                      context,
                      title: 'Sign out?',
                      message: 'Your data stays safe in your account.',
                      confirmLabel: 'Sign out',
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
