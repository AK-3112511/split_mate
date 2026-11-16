import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/friendly_error.dart';
import 'buttons.dart';
import 'motion.dart';

/// Friendly empty state with an optional call to action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Space.xl, vertical: compact ? Space.lg : Space.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.rotate(
            angle: -0.06,
            child: Container(
              width: compact ? 64 : 84,
              height: compact ? 64 : 84,
              decoration: BoxDecoration(
                color: c.cta,
                borderRadius: Radii.card,
                border: c.inkBorder,
                boxShadow: c.hardShadow(),
              ),
              child: Icon(icon, size: compact ? 30 : 38, color: c.onPop),
            ),
          ),
          const SizedBox(height: Space.md),
          Text(title, textAlign: TextAlign.center, style: context.text.titleMedium),
          if (message != null) ...[
            const SizedBox(height: Space.xs),
            Text(message!, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: c.textMuted)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.lg),
            PrimaryButton(label: actionLabel!, icon: actionIcon, onPressed: onAction, expand: false),
          ],
        ],
      ).entrance(context),
    );
  }
}

/// Friendly error with retry; never shows raw exception text.
class ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;
  const ErrorState({super.key, this.error, this.onRetry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Padding(
      padding: EdgeInsets.all(compact ? Space.md : Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: compact ? 32 : 44, color: c.textMuted),
          const SizedBox(height: Space.sm),
          Text('Couldn\'t load this', style: context.text.titleSmall),
          const SizedBox(height: Space.xxs),
          Text(friendlyError(error), textAlign: TextAlign.center, style: context.text.bodySmall),
          if (onRetry != null) ...[
            const SizedBox(height: Space.md),
            SecondaryButton(label: 'Try again', icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
          ],
        ],
      ),
    );
  }
}

/// Shimmering placeholder block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;
  const SkeletonBox({super.key, this.width, this.height = 16, this.borderRadius = Radii.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: context.aurora.surfaceHigh, borderRadius: borderRadius),
    );
  }
}

class Skeleton extends StatelessWidget {
  final Widget child;
  const Skeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    if (Motion.reduced(context)) return child;
    return Shimmer.fromColors(
      baseColor: c.surfaceHigh,
      highlightColor: c.isDark ? const Color(0xFF3A3A3A) : Colors.white,
      child: child,
    );
  }
}

/// List-shaped loading placeholder.
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  const SkeletonList({super.key, this.count = 5, this.padding = const EdgeInsets.symmetric(horizontal: Space.gutter)});

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Padding(
        padding: padding,
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    const SkeletonBox(width: 44, height: 44, borderRadius: Radii.tile),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 120 + (i % 3) * 30.0, height: 14),
                          const SizedBox(height: 8),
                          const SkeletonBox(width: 80, height: 12),
                        ],
                      ),
                    ),
                    const SkeletonBox(width: 64, height: 16),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
