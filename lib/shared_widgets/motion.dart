import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/haptics.dart';

extension EntranceX on Widget {
  /// Staggered pop-in (fade + slide + slight overshoot). Respects reduce-motion.
  Widget entrance(BuildContext context, {int index = 0, double dy = 0.12}) {
    if (Motion.reduced(context)) return this;
    final delay = Motion.stagger * (index.clamp(0, 8));
    return animate(delay: delay)
        .fadeIn(duration: Motion.slow, curve: Motion.smooth)
        .slideY(begin: dy, end: 0, duration: Motion.slow, curve: Motion.enter);
  }
}

/// The Pop Brutal building block: ink outline + hard offset shadow.
/// When tapped it slides into its shadow ("pressed in"), with a haptic.
class BrutalSurface extends StatefulWidget {
  final Widget child;
  final Color? color;
  final BorderRadius borderRadius;
  final double shadow;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool haptic;
  final String? semanticLabel;
  final double? borderWidth;
  final BoxShape shape;

  const BrutalSurface({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = Radii.card,
    this.shadow = Brutal.shadow,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.haptic = true,
    this.semanticLabel,
    this.borderWidth,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<BrutalSurface> createState() => _BrutalSurfaceState();
}

class _BrutalSurfaceState extends State<BrutalSurface> {
  bool _down = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (!_interactive || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final pressed = _down && !Motion.reduced(context);
    final offset = pressed ? widget.shadow : 0.0;
    final isCircle = widget.shape == BoxShape.circle;
    final box = AnimatedContainer(
      duration: Motion.fast,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(offset, offset, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        // Composite tints onto the opaque surface: the hard shadow is painted
        // under the fill, so a translucent fill would let it show through black.
        color: widget.color == null ? c.surface : Color.alphaBlend(widget.color!, c.surface),
        shape: widget.shape,
        borderRadius: isCircle ? null : widget.borderRadius,
        border: Border.all(color: c.ink, width: widget.borderWidth ?? Brutal.border),
        boxShadow: pressed || widget.shadow == 0 ? const [] : c.hardShadow(widget.shadow),
      ),
      child: Material(type: MaterialType.transparency, child: widget.child),
    );
    if (!_interactive) return box;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) Haptics.tap();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: box,
      ),
    );
  }
}

/// Lightweight press feedback for flat rows (list tiles): slight dip + haptic.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final bool haptic;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = Radii.card,
    this.haptic = true,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: Motion.fast,
          curve: Curves.easeOut,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: widget.borderRadius,
              onTap: widget.onTap == null
                  ? null
                  : () {
                      if (widget.haptic) Haptics.tap();
                      widget.onTap!();
                    },
              onLongPress: widget.onLongPress,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
