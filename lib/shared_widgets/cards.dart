import 'package:material_ui/material_ui.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import 'motion.dart';

/// Standard Pop Brutal card: paper fill, ink outline, hard shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final BorderRadius borderRadius;

  /// Kept for API compatibility; Pop Brutal cards are always outlined.
  final bool outlined;
  final double shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.md),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderRadius = Radii.card,
    this.outlined = true,
    this.shadow = Brutal.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return BrutalSurface(
      color: color,
      borderRadius: borderRadius,
      padding: padding,
      onTap: onTap,
      onLongPress: onLongPress,
      shadow: shadow,
      child: child,
    );
  }
}

/// Bold pop-colour hero card (headline numbers). Text inside is ink by default.
/// (Name kept from v2.0; there are no gradients in Pop Brutal.)
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const GradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return BrutalSurface(
      color: color ?? c.cta,
      borderRadius: Radii.hero,
      shadow: 6,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: padding,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: c.onPop),
          child: IconTheme.merge(data: IconThemeData(color: c.onPop), child: child),
        ),
      ),
    );
  }
}

/// Small pop-colour stat tile used inside hero areas (owed / owe …).
class PopTile extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const PopTile({
    super.key,
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(Space.sm),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return BrutalSurface(
      color: color,
      borderRadius: Radii.tile,
      shadow: Brutal.shadowSmall,
      borderWidth: Brutal.borderThin,
      padding: padding,
      onTap: onTap,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: c.onPop),
        child: IconTheme.merge(data: IconThemeData(color: c.onPop), child: child),
      ),
    );
  }
}

/// Plain paper background with a faint dot grid (notebook vibes).
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return ColoredBox(
      color: c.bg,
      child: CustomPaint(
        painter: _DotGrid(c.ink.withValues(alpha: c.isDark ? 0.07 : 0.08)),
        child: child,
      ),
    );
  }
}

class _DotGrid extends CustomPainter {
  final Color color;
  _DotGrid(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const step = 22.0;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid old) => old.color != color;
}
