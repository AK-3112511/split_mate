import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/aurora_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared_widgets/buttons.dart';
import '../../../shared_widgets/cards.dart';
import '../../../shared_widgets/feedback.dart';
import '../../../shared_widgets/states.dart';
import '../data/groups_repository.dart';

final _codePreviewProvider = FutureProvider.autoDispose.family<GroupCodeInfo, String>((ref, code) {
  return ref.watch(groupsRepositoryProvider).lookupCode(code);
});

/// Opened from an invite link (https://…/join?code=… or splitmate://join?code=…).
class JoinGroupScreen extends ConsumerStatefulWidget {
  final String code;
  const JoinGroupScreen({super.key, required this.code});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      final res = await ref.read(groupsRepositoryProvider).joinByCode(widget.code);
      Haptics.success();
      if (!mounted) return;
      context.go('/groups/${res.groupId}');
      Toast.success(res.alreadyMember ? 'You\'re already in ${res.groupName}' : 'Welcome to ${res.groupName}! 🎉');
    } catch (e) {
      if (mounted) setState(() => _joining = false);
      Toast.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final preview = ref.watch(_codePreviewProvider(widget.code));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group invite'),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.popOrGo('/groups'),
        ),
      ),
      body: AuroraBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: preview.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => EmptyState(
                icon: Icons.link_off_rounded,
                title: 'This invite doesn\'t work',
                message: friendlyError(e),
                actionLabel: 'Go to groups',
                onAction: () => context.go('/groups'),
              ),
              data: (info) => AppCard(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Palette.popFor(info.groupId),
                        borderRadius: Radii.card,
                        border: c.inkBorder,
                        boxShadow: c.hardShadow(),
                      ),
                      child: Text(info.groupName.characters.first.toUpperCase(),
                          style: context.text.headlineLarge?.copyWith(color: c.onPop)),
                    ),
                    const SizedBox(height: Space.md),
                    Text('You\'re invited to', style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
                    const SizedBox(height: 4),
                    Text(info.groupName, textAlign: TextAlign.center, style: context.text.headlineSmall),
                    const SizedBox(height: Space.xs),
                    Text('Code ${info.code}', style: context.text.labelMedium),
                    const SizedBox(height: Space.xl),
                    PrimaryButton(label: 'Join group', icon: Icons.login_rounded, loading: _joining, onPressed: _join),
                    const SizedBox(height: Space.sm),
                    SecondaryButton(label: 'Not now', onPressed: () => context.popOrGo('/groups')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
