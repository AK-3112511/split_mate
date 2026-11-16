import 'package:material_ui/material_ui.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';
import '../core/utils/money.dart';

/// Formatted money with tabular digits, optional sign colouring and count-up.
class AmountText extends StatelessWidget {
  final double amount;
  final TextStyle? style;

  /// Colour green when positive / red when negative (from my point of view).
  final bool colored;

  /// Show the absolute value (sign conveyed by colour / label instead).
  final bool absolute;
  final bool signed;
  final bool animate;
  final bool compact;
  final TextAlign? textAlign;

  const AmountText(
    this.amount, {
    super.key,
    this.style,
    this.colored = false,
    this.absolute = false,
    this.signed = false,
    this.animate = false,
    this.compact = false,
    this.textAlign,
  });

  String _format(double v) {
    final value = absolute ? v.abs() : v;
    return compact ? Money.compact(value) : Money.format(value, signed: signed);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final base = (style ?? context.text.bodyLarge!).copyWith(fontFeatures: AppTheme.tabular);
    final s = colored ? base.copyWith(color: c.amountColor(amount)) : base;

    Widget text(double v) => Text(
          _format(v),
          style: s,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          textAlign: textAlign,
        );

    if (!animate || Motion.reduced(context)) return text(amount);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount),
      duration: Motion.celebrate,
      curve: Curves.easeOutExpo,
      builder: (_, v, __) => text(v),
    );
  }
}
