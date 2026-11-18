import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/aurora_colors.dart';
import '../core/theme/tokens.dart';

/// Labelled text field with the theme's filled, rounded style.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscure;
  final Widget? suffix;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool autofocus;
  final bool enabled;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscure = false,
    this.suffix,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.autofocus = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscure,
      maxLines: obscure ? 1 : maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      autofocus: autofocus,
      enabled: enabled,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        suffixIcon: suffix,
        counterText: '',
      ),
    );
  }
}

/// Only digits, one decimal separator ("." or ","), grouping commas, max 2 decimals.
final List<TextInputFormatter> moneyInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
  TextInputFormatter.withFunction((oldValue, newValue) {
    final t = newValue.text;
    final sep = t.contains('.') ? '.' : null;
    if (sep != null && '.'.allMatches(t).length > 1) return oldValue;
    if (sep != null) {
      final decimals = t.substring(t.indexOf('.') + 1);
      if (decimals.length > 2) return oldValue;
    }
    if (t.length > 14) return oldValue;
    return newValue;
  }),
];

/// Big hero amount input ("₹ 1,250").
class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  const MoneyField({
    super.key,
    required this.controller,
    this.validator,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final style = context.text.displayMedium?.copyWith(fontFeatures: AppTheme.tabular);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: Text('₹', style: style?.copyWith(color: c.textMuted)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                autofocus: autofocus,
                validator: validator,
                onChanged: onChanged,
                textInputAction: textInputAction,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInputFormatters,
                style: style,
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: '0',
                  hintStyle: style?.copyWith(color: c.textMuted.withValues(alpha: 0.5)),
                  errorStyle: context.text.bodySmall?.copyWith(color: c.negative),
                  errorMaxLines: 2,
                  contentPadding: const EdgeInsets.symmetric(vertical: Space.xs),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Selectable chip used for filters / quick picks.
class ChoiceChipX extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  const ChoiceChipX({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.aurora;
    final fill = color ?? c.cta;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 3, bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? fill : c.surface,
            borderRadius: Radii.chip,
            border: Border.all(color: c.ink, width: Brutal.borderThin),
            boxShadow: selected ? c.hardShadow(Brutal.shadowSmall) : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? c.onPop : c.textMuted),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.text.labelMedium?.copyWith(
                  color: selected ? c.onPop : c.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
