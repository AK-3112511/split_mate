import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/theme/aurora_colors.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared_widgets/buttons.dart';
import '../../../../shared_widgets/cards.dart';
import '../../../../shared_widgets/feedback.dart';
import '../../../../shared_widgets/logo_mark.dart';
import '../../../../shared_widgets/motion.dart';

/// The short terms everyone accepts before an account is created.
const List<String> termsSummary = [
  'SplitMate helps you track expenses and split bills with friends. It never moves money for you.',
  'Your personal expenses are visible only to you. Group expenses are visible to members of that group.',
  'Friends see your name, photo, friend code and UPI ID (if you add one) — never your email.',
  'Data is stored in Google Firebase. You can delete your expenses at any time.',
  'Use SplitMate responsibly and only add people who agreed to share expenses with you.',
];

class TermsLine extends StatelessWidget {
  final String text;
  const TermsLine(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: context.aurora.positive),
          const SizedBox(width: Space.xs),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// Terms for someone whose account is being created outside the sign-up
/// screen (a first "Continue with Google" from login). True only on "I agree".
Future<bool> askToAcceptTerms(BuildContext context) async {
  final agreed = await showAppSheet<bool>(
    context,
    builder: (ctx) => SheetBody(
      title: 'New to SplitMate?',
      subtitle: 'Accept the terms to create your account.',
      children: [
        for (final line in termsSummary) TermsLine(line),
        const SizedBox(height: Space.sm),
        PrimaryButton(label: 'I agree', onPressed: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: Space.xs),
        SecondaryButton(label: 'Not now', onPressed: () => Navigator.of(ctx).pop(false)),
      ],
    ),
  );
  return agreed ?? false;
}

final RegExp emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

String? validateEmail(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Enter your email';
  if (!emailPattern.hasMatch(t)) return 'That email doesn\'t look right';
  return null;
}

/// App logo in a soft gradient tile with a gentle breathing glow.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) {
    final mark = Transform.rotate(angle: -0.08, child: LogoMark(size: size));
    if (Motion.reduced(context)) return mark;
    return mark
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .rotate(begin: 0, end: 0.02, duration: 1600.ms, curve: Curves.easeInOut);
  }
}

/// Shared layout for login / signup / verify.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;
  final Widget? leading;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (leading != null) Align(alignment: Alignment.centerLeft, child: leading),
                    const Center(child: BrandMark()).entrance(context),
                    const SizedBox(height: Space.xl),
                    Text(title, textAlign: TextAlign.center, style: context.text.headlineLarge)
                        .entrance(context, index: 1),
                    const SizedBox(height: Space.xs),
                    Text(subtitle,
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge?.copyWith(color: c.textMuted))
                        .entrance(context, index: 2),
                    const SizedBox(height: Space.xl),
                    AppCard(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                    ).entrance(context, index: 3),
                    if (footer != null) ...[
                      const SizedBox(height: Space.lg),
                      footer!.entrance(context, index: 4),
                    ],
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

/// Inline error banner inside forms.
class FormErrorBanner extends StatelessWidget {
  final String? message;
  const FormErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.enter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: Space.md),
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: c.negative.withValues(alpha: 0.12),
                borderRadius: Radii.tile,
                border: Border.all(color: c.negative.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: c.negative, size: 20),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(message!, style: context.text.bodyMedium?.copyWith(color: c.negative)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// "or" divider.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Text('or', style: context.text.labelMedium),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// "Continue with Google" button.
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  const GoogleButton({super.key, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
          else
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Palette.ink, width: 1.5)),
              child: const Text(
                'G',
                style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
          const SizedBox(width: Space.sm),
          const Text('Continue with Google'),
        ],
      ),
    );
  }
}
