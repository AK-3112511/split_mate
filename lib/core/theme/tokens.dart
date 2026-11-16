import 'package:material_ui/material_ui.dart';

/// Spacing scale (4-pt grid). Screen gutter is [gutter].
class Space {
  Space._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double gutter = 20;
}

/// Corner radii — "slightly rounded" neubrutalism.
class Radii {
  Radii._();
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;

  static const BorderRadius chip = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius tile = BorderRadius.all(Radius.circular(md));
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xl));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(xl - 2));
  static const BorderRadius round = BorderRadius.all(Radius.circular(pill));
}

/// Pop Brutal structure: thick ink outlines and hard, unblurred offset shadows.
class Brutal {
  Brutal._();
  static const double border = 2.5;
  static const double borderThin = 2;
  static const double shadow = 4; // cards
  static const double shadowSmall = 3; // buttons, chips
}

/// Motion durations.
class Motion {
  Motion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration celebrate = Duration(milliseconds: 1100);
  static const Duration stagger = Duration(milliseconds: 50);
  static const Curve enter = Curves.easeOutBack;
  static const Curve smooth = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// True when the OS asks for reduced motion.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Raw brand colours (widgets should use [AuroraColors] via `context.aurora`).
class Palette {
  Palette._();

  // Ink & paper
  static const Color ink = Color(0xFF111111);
  static const Color cream = Color(0xFFFFF8E7);
  static const Color paper = Color(0xFFFFFFFF);

  // Pop fills (text on them is always ink)
  static const Color yellow = Color(0xFFFFD23F);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color mint = Color(0xFF4ECDC4);
  static const Color violet = Color(0xFFA78BFA);
  static const Color sky = Color(0xFF74B9FF);
  static const Color pink = Color(0xFFFF8FAB);
  static const Color lime = Color(0xFFB8F25F);
  static const Color orange = Color(0xFFFF9F43);

  static const List<Color> pops = [yellow, mint, coral, violet, sky, pink, lime, orange];

  /// A stable pop colour per person / group (picked by hashing the id).
  static Color popFor(String seed) {
    final hash = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    return pops[hash % pops.length];
  }

  // Dark mode surfaces
  static const Color night = Color(0xFF141414);
  static const Color nightCard = Color(0xFF1E1E1E);
  static const Color nightHigh = Color(0xFF2A2A2A);
}
