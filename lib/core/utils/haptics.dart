import 'package:flutter/services.dart';

/// Thin wrapper so every interaction uses the same, subtle haptic vocabulary.
class Haptics {
  Haptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.mediumImpact();
  static void warning() => HapticFeedback.heavyImpact();
}
