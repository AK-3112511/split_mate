import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color surfaceBase = Color(0xFF14171A);
  static const Color surfaceCard = Color(0xFF1E2226);
  static const Color textPrimary = Color(0xFFEDEAE3);
  static const Color textSecondary = Color(0xFF8B8F94);
  static const Color accent = Color(0xFFC9A24B);
  static const Color semanticPositive = Color(0xFF6FA88A);
  static const Color semanticNegative = Color(0xFFC0645A);

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();
    
    return baseTheme.copyWith(
      scaffoldBackgroundColor: surfaceBase,
      cardColor: surfaceCard,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surfaceCard,
        error: semanticNegative,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        displayMedium: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        displaySmall: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        headlineLarge: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        headlineMedium: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        headlineSmall: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
        titleLarge: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        titleMedium: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        ),
        titleSmall: GoogleFonts.lora(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        ),
        bodyLarge: GoogleFonts.inter(
          textStyle: const TextStyle(color: textPrimary),
        ),
        bodyMedium: GoogleFonts.inter(
          textStyle: const TextStyle(color: textSecondary),
        ),
        labelLarge: GoogleFonts.inter(
          textStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Monospace helper styles for currency/ledger layout
  static TextStyle get monoStyle {
    return GoogleFonts.ibmPlexMono(
      textStyle: const TextStyle(color: textPrimary),
    );
  }

  static TextStyle get monoSecondary {
    return GoogleFonts.ibmPlexMono(
      textStyle: const TextStyle(color: textSecondary),
    );
  }
}
