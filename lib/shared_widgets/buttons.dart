import 'package:material_ui/material_ui.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/haptics.dart';
import 'motion.dart';

/// Chunky pop-colour button (yellow by default) that presses into its shadow.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final Color? color;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final enabled = onPressed != null && !loading;
    final fill = enabled ? (color ?? c.cta) : c.surfaceHigh;
    final fg = enabled ? c.onPop : c.textMuted;
    final content = SizedBox(
      height: 50,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: Motion.fast,
            child: loading
                ? SizedBox(
                    key: const ValueKey('l'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 3, color: c.onPop),
                  )
                : Row(
                    key: const ValueKey('c'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: Space.xs)],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelLarge?.copyWith(color: fg, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: BrutalSurface(
        color: fill,
        borderRadius: Radii.tile,
        shadow: enabled ? Brutal.shadow : 0,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        haptic: false,
        onTap: enabled
            ? () {
                Haptics.light();
                onPressed!();
              }
            : null,
        child: content,
      ),
    );
  }
}

/// Floating action in the Pop Brutal style (yellow, ink outline, hard shadow).
class PopFab extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const PopFab({super.key, required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return BrutalSurface(
      color: c.cta,
      borderRadius: Radii.tile,
      onTap: onPressed,
      semanticLabel: label,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: SizedBox(
        height: 54,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.onPop, size: 24),
            const SizedBox(width: Space.xs),
            Text(label, style: context.text.labelLarge?.copyWith(color: c.onPop, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Paper button with ink outline; [color] tints the label (e.g. destructive).
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final Color? color;
  final bool loading;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.color,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final enabled = onPressed != null && !loading;
    final fg = enabled ? (color ?? c.text) : c.textMuted;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: BrutalSurface(
        color: c.surface,
        borderRadius: Radii.tile,
        shadow: enabled ? Brutal.shadowSmall : 0,
        borderWidth: Brutal.borderThin,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
              else ...[
                if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: Space.xs)],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(color: fg)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Square ink-outlined icon button (headers, rows).
class TonalIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? color;
  final int? badge;
  final double size;

  const TonalIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color,
    this.badge,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    Widget btn = Tooltip(
      message: tooltip,
      child: BrutalSurface(
        color: color ?? c.surface,
        borderRadius: Radii.tile,
        shadow: Brutal.shadowSmall,
        borderWidth: Brutal.borderThin,
        onTap: onPressed,
        semanticLabel: tooltip,
        child: SizedBox(
          width: size - 4,
          height: size - 4,
          child: Icon(icon, color: color == null ? c.text : c.onPop, size: size * 0.48),
        ),
      ),
    );
    if (badge != null && badge! > 0) {
      btn = Badge(
        label: Text(badge! > 99 ? '99+' : '$badge', style: const TextStyle(fontWeight: FontWeight.w800)),
        offset: const Offset(-4, -2),
        child: btn,
      );
    }
    return btn;
  }
}
