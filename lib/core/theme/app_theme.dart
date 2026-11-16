import 'package:animations/animations.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'aurora_colors.dart';
import 'tokens.dart';

/// "Pop Brutal" light & dark themes (neubrutalism, chosen with UI/UX Pro Max).
///
/// Note: use `GoogleFonts.x().fontFamily` (never `GoogleFonts.xTextTheme()`,
/// which returns legacy-material types).
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(AuroraColors.dark, Brightness.dark);
  static ThemeData get light => _build(AuroraColors.light, Brightness.light);

  static String? get _font => GoogleFonts.spaceGrotesk().fontFamily;

  /// Money: tabular figures so digits line up in lists.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme _textTheme(AuroraColors c) {
    TextStyle s(double size, FontWeight w, {Color? color, double? height, double spacing = 0}) => TextStyle(
          fontFamily: _font,
          fontSize: size,
          fontWeight: w,
          color: color ?? c.text,
          height: height,
          letterSpacing: spacing,
        );
    return TextTheme(
      displayLarge: s(44, FontWeight.w700, height: 1.05, spacing: -1.5),
      displayMedium: s(38, FontWeight.w700, height: 1.05, spacing: -1.2),
      displaySmall: s(32, FontWeight.w700, height: 1.1, spacing: -1),
      headlineLarge: s(30, FontWeight.w700, height: 1.15, spacing: -0.8),
      headlineMedium: s(26, FontWeight.w700, height: 1.15, spacing: -0.5),
      headlineSmall: s(23, FontWeight.w700, height: 1.2, spacing: -0.3),
      titleLarge: s(21, FontWeight.w700, height: 1.25, spacing: -0.2),
      titleMedium: s(18, FontWeight.w700, height: 1.3),
      titleSmall: s(16, FontWeight.w700, height: 1.3),
      bodyLarge: s(16, FontWeight.w500, height: 1.45),
      bodyMedium: s(14, FontWeight.w500, height: 1.45),
      bodySmall: s(13, FontWeight.w500, color: c.textMuted, height: 1.4),
      labelLarge: s(15, FontWeight.w700, spacing: 0.3),
      labelMedium: s(13, FontWeight.w600, color: c.textMuted),
      labelSmall: s(12, FontWeight.w700, color: c.textMuted, spacing: 1.1),
    );
  }

  static ThemeData _build(AuroraColors c, Brightness b) {
    final text = _textTheme(c);
    final inkSide = BorderSide(color: c.ink, width: Brutal.borderThin);
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: c.secondary,
      onSecondary: Colors.white,
      tertiary: c.positive,
      onTertiary: Colors.white,
      error: c.negative,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceHigh,
      surfaceContainerHighest: c.surfaceHigh,
      outline: c.ink,
      outlineVariant: c.outline,
      shadow: c.shadow,
      inverseSurface: c.text,
      onInverseSurface: c.bg,
    );

    final inputBorder = OutlineInputBorder(borderRadius: Radii.tile, borderSide: inkSide);

    // Hard-shadowed, ink-outlined pill buttons that "press in" when tapped.
    ButtonStyle chunky(Color bg, Color fg) => ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.surfaceHigh : bg,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : fg,
          ),
          side: WidgetStatePropertyAll(inkSide),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.tile)),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(64, 50)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.lg)),
          overlayColor: WidgetStatePropertyAll(c.ink.withValues(alpha: 0.06)),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: _font,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [c],
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: SharedAxisPageTransitionsBuilder(
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
        ),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: SharedAxisPageTransitionsBuilder(
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: Colors.transparent,
        ),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.text),
        systemOverlayStyle: b == Brightness.dark
            ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
            : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.card, side: inkSide),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
        hintStyle: text.bodyLarge?.copyWith(color: c.textMuted.withValues(alpha: 0.85)),
        labelStyle: text.bodyMedium?.copyWith(color: c.textMuted),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: c.text, fontWeight: FontWeight.w700),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: c.negative, fontWeight: FontWeight.w600),
        prefixIconColor: c.textMuted,
        suffixIconColor: c.textMuted,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.primary, width: 3)),
        errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.negative, width: 2)),
        focusedErrorBorder: inputBorder.copyWith(borderSide: BorderSide(color: c.negative, width: 3)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: chunky(c.cta, Palette.ink)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: chunky(c.cta, Palette.ink)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: chunky(c.surface, c.text)),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          textStyle: text.labelLarge?.copyWith(decoration: TextDecoration.underline, decorationThickness: 2),
          shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
          minimumSize: const Size(48, 44),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(44, 44)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.cta,
        foregroundColor: Palette.ink,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: Radii.tile, side: BorderSide(color: Palette.ink, width: Brutal.border)),
        extendedTextStyle: text.labelLarge,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.cta,
        side: inkSide,
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        labelStyle: text.labelMedium?.copyWith(color: c.text, fontWeight: FontWeight.w700),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: Palette.ink, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
        showCheckmark: false,
        checkmarkColor: Palette.ink,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.chip)),
          side: WidgetStatePropertyAll(inkSide),
          textStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.cta : c.surface),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Palette.ink : c.text,
          ),
          iconColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.ink : c.text),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bg,
        modalBackgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.ink,
        dragHandleSize: const Size(44, 5),
        shape: RoundedRectangleBorder(
          borderRadius: Radii.sheet,
          side: BorderSide(color: c.ink, width: Brutal.border),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.hero, side: BorderSide(color: c.ink, width: Brutal.border)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.text, fontWeight: FontWeight.w600),
        actionTextColor: c.primary,
        shape: RoundedRectangleBorder(borderRadius: Radii.tile, side: BorderSide(color: c.ink, width: Brutal.border)),
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: c.cta,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: Radii.chip,
          side: BorderSide(color: Palette.ink, width: Brutal.borderThin),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => text.labelSmall?.copyWith(
              letterSpacing: 0.4,
              color: s.contains(WidgetState.selected) ? c.text : c.textMuted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? Palette.ink : c.textMuted,
              size: 24,
            )),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Palette.ink,
        unselectedLabelColor: c.textMuted,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: c.cta,
          borderRadius: Radii.chip,
          border: Border.all(color: Palette.ink, width: Brutal.borderThin),
        ),
        splashBorderRadius: Radii.chip,
        labelPadding: const EdgeInsets.symmetric(horizontal: Space.md),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.text,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        subtitleTextStyle: text.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: Radii.tile),
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
        minVerticalPadding: Space.sm,
      ),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1.5, space: 1.5),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.text,
        linearTrackColor: c.surfaceHigh,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 10,
        borderRadius: Radii.round,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.ink : c.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.cta : c.surfaceHigh),
        trackOutlineColor: WidgetStatePropertyAll(c.ink),
        trackOutlineWidth: const WidgetStatePropertyAll(Brutal.borderThin),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: c.ink, width: Brutal.borderThin),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.cta : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(Palette.ink),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.tile, side: BorderSide(color: c.ink, width: Brutal.borderThin)),
        textStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.text, borderRadius: Radii.chip),
        textStyle: text.labelMedium?.copyWith(color: c.bg),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.hero, side: BorderSide(color: c.ink, width: Brutal.border)),
        headerBackgroundColor: c.cta,
        headerForegroundColor: Palette.ink,
        todayBorder: BorderSide(color: c.ink, width: Brutal.borderThin),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: Palette.coral, textColor: Palette.ink),
    );
  }
}
