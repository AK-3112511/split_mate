import 'dart:ui' show lerpDouble;
import 'package:material_ui/material_ui.dart';
import 'tokens.dart';

/// Semantic colours for the **Pop Brutal** theme. Access with `context.aurora`.
///
/// (The class keeps its v2.0 name so every widget keeps compiling; the look is
/// neubrutalism: cream paper, ink outlines, hard shadows, pop fills.)
@immutable
class AuroraColors extends ThemeExtension<AuroraColors> {
  final Color bg;
  final Color surface;
  final Color surfaceHigh;

  /// Outline + hard-shadow colour (ink in light mode, cream in dark mode).
  final Color ink;

  /// Hairline dividers inside cards.
  final Color outline;

  /// Text / icon colour on any pop fill — always dark ink, in both modes.
  final Color onPop;

  /// Accent for links, selection and focus.
  final Color primary;
  final Color onPrimary;
  final Color secondary;

  /// Main call-to-action fill (sunny yellow).
  final Color cta;

  final Color positive;
  final Color negative;
  final Color warning;
  final Color positiveFill;
  final Color negativeFill;
  final Color text;
  final Color textMuted;
  final Color shadow;
  final double inkWidth;

  const AuroraColors({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.ink,
    required this.outline,
    required this.onPop,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.cta,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.positiveFill,
    required this.negativeFill,
    required this.text,
    required this.textMuted,
    required this.shadow,
    this.inkWidth = Brutal.border,
  });

  static const AuroraColors light = AuroraColors(
    bg: Palette.cream,
    surface: Palette.paper,
    surfaceHigh: Color(0xFFF6EEDB),
    ink: Palette.ink,
    outline: Color(0x1F111111),
    onPop: Palette.ink,
    primary: Color(0xFF6D28D9),
    onPrimary: Colors.white,
    secondary: Color(0xFF0369A1),
    cta: Palette.yellow,
    positive: Color(0xFF15803D),
    negative: Color(0xFFDC2626),
    warning: Color(0xFFB45309),
    positiveFill: Palette.mint,
    negativeFill: Palette.coral,
    text: Palette.ink,
    textMuted: Color(0xFF57534A),
    shadow: Palette.ink,
  );

  static const AuroraColors dark = AuroraColors(
    bg: Palette.night,
    surface: Palette.nightCard,
    surfaceHigh: Palette.nightHigh,
    ink: Palette.cream,
    outline: Color(0x29FFF8E7),
    onPop: Palette.ink,
    primary: Palette.violet,
    onPrimary: Palette.ink,
    secondary: Palette.sky,
    cta: Palette.yellow,
    positive: Color(0xFF4ADE80),
    negative: Color(0xFFFF8A8A),
    warning: Color(0xFFFBBF24),
    positiveFill: Palette.mint,
    negativeFill: Palette.coral,
    text: Palette.cream,
    textMuted: Color(0xFFBDB7A8),
    shadow: Palette.cream,
  );

  bool get isDark => bg.computeLuminance() < 0.2;

  /// Colour for a money value from my point of view (+ owed to me, − I owe).
  Color amountColor(num value) {
    final p = (value * 100).round();
    if (p > 0) return positive;
    if (p < 0) return negative;
    return textMuted;
  }

  /// Pop fill for a money value (used on tiles with ink text).
  Color amountFill(num value) {
    final p = (value * 100).round();
    if (p > 0) return positiveFill;
    if (p < 0) return negativeFill;
    return surfaceHigh;
  }

  Border get inkBorder => Border.all(color: ink, width: inkWidth);
  Border get thinBorder => Border.all(color: ink, width: Brutal.borderThin);

  /// The signature hard, unblurred offset shadow.
  List<BoxShadow> hardShadow([double offset = Brutal.shadow]) =>
      [BoxShadow(color: shadow, offset: Offset(offset, offset), blurRadius: 0, spreadRadius: 0)];

  List<BoxShadow> get cardShadow => hardShadow();

  @override
  AuroraColors copyWith({Color? primary}) => AuroraColors(
        bg: bg,
        surface: surface,
        surfaceHigh: surfaceHigh,
        ink: ink,
        outline: outline,
        onPop: onPop,
        primary: primary ?? this.primary,
        onPrimary: onPrimary,
        secondary: secondary,
        cta: cta,
        positive: positive,
        negative: negative,
        warning: warning,
        positiveFill: positiveFill,
        negativeFill: negativeFill,
        text: text,
        textMuted: textMuted,
        shadow: shadow,
        inkWidth: inkWidth,
      );

  @override
  AuroraColors lerp(AuroraColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AuroraColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceHigh: c(surfaceHigh, other.surfaceHigh),
      ink: c(ink, other.ink),
      outline: c(outline, other.outline),
      onPop: c(onPop, other.onPop),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      secondary: c(secondary, other.secondary),
      cta: c(cta, other.cta),
      positive: c(positive, other.positive),
      negative: c(negative, other.negative),
      warning: c(warning, other.warning),
      positiveFill: c(positiveFill, other.positiveFill),
      negativeFill: c(negativeFill, other.negativeFill),
      text: c(text, other.text),
      textMuted: c(textMuted, other.textMuted),
      shadow: c(shadow, other.shadow),
      inkWidth: lerpDouble(inkWidth, other.inkWidth, t)!,
    );
  }
}

extension AuroraContext on BuildContext {
  AuroraColors get aurora => Theme.of(this).extension<AuroraColors>() ?? AuroraColors.light;
  TextTheme get text => Theme.of(this).textTheme;
}
