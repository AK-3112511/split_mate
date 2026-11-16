import 'package:material_ui/material_ui.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../features/categories/domain/category_model.dart';

enum PillTone { neutral, primary, positive, negative, warning }

/// Sticker-style status label: pop fill, thin ink outline, ink text.
class Pill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final IconData? icon;
  const Pill(this.label, {super.key, this.tone = PillTone.neutral, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final fill = switch (tone) {
      PillTone.neutral => c.surfaceHigh,
      PillTone.primary => Palette.violet,
      PillTone.positive => Palette.mint,
      PillTone.negative => Palette.coral,
      PillTone.warning => Palette.yellow,
    };
    final fg = tone == PillTone.neutral ? c.text : c.onPop;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: Radii.chip,
        border: Border.all(color: c.ink, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(color: fg, letterSpacing: 0.3, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category icon on a solid category-colour tile with an ink outline.
class CategoryBubble extends StatelessWidget {
  final CategoryModel category;
  final double size;
  const CategoryBubble(this.category, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.ink, width: Brutal.borderThin),
      ),
      child: Icon(category.icon, color: c.onPop, size: size * 0.5),
    );
  }
}

/// Icon on a soft pop tile (rows, empty states). [color] tints the tile.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  const IconBadge(this.icon, {super.key, this.size = 44, this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final base = color ?? Palette.violet;
    // Lighten strong semantic colours so ink icons stay readable.
    final fill = Color.alphaBlend(base.withValues(alpha: 0.6), Colors.white);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.ink, width: Brutal.borderThin),
      ),
      child: Icon(icon, color: c.onPop, size: size * 0.5),
    );
  }
}

/// Bold section title + optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.md, Space.xs),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(),
                style: context.text.titleSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Chunky progress bar: ink-outlined track, solid fill.
class SoftProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  const SoftProgressBar({super.key, required this.value, this.color, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    return Container(
      width: double.infinity,
      height: height + 3,
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: Radii.round,
        border: Border.all(color: c.ink, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: Radii.round,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
          duration: Motion.slow,
          curve: Motion.smooth,
          builder: (_, v, __) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Container(color: color ?? Palette.violet),
          ),
        ),
      ),
    );
  }
}
