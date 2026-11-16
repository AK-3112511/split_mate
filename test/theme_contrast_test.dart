import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:split_mate/core/theme/aurora_colors.dart';
import 'package:split_mate/core/theme/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// WCAG checks for the Pop Brutal tokens (UI/UX Pro Max: text ≥ 4.5:1, UI ≥ 3:1).
void main() {
  for (final (name, c) in [('light', AuroraColors.light), ('dark', AuroraColors.dark)]) {
    group('$name theme', () {
      test('body & muted text are readable on background and cards', () {
        for (final bg in [c.bg, c.surface, c.surfaceHigh]) {
          expect(contrast(c.text, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(c.textMuted, bg), greaterThanOrEqualTo(4.5));
        }
      });

      test('semantic money colours are readable as text', () {
        for (final col in [c.positive, c.negative, c.primary]) {
          expect(contrast(col, c.surface), greaterThanOrEqualTo(4.5), reason: '$col on surface');
        }
        expect(contrast(c.warning, c.surface), greaterThanOrEqualTo(3.0));
      });

      test('ink outlines are visible (non-text ≥ 3:1)', () {
        expect(contrast(c.ink, c.bg), greaterThanOrEqualTo(3));
        expect(contrast(c.ink, c.surface), greaterThanOrEqualTo(3));
      });
    });
  }

  test('ink text on every pop fill is readable', () {
    for (final pop in Palette.pops) {
      expect(contrast(Palette.ink, pop), greaterThanOrEqualTo(4.5), reason: '$pop');
    }
  });
}
