import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:split_mate/core/theme/app_theme.dart';
import 'package:split_mate/core/theme/aurora_colors.dart';
import 'package:split_mate/features/auth/presentation/login_screen.dart';
import 'package:split_mate/shared_widgets/amount_text.dart';
import 'package:split_mate/shared_widgets/states.dart';

Widget _app(Widget child, {ThemeMode mode = ThemeMode.dark}) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: child,
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Login screen renders with friendly copy and real forgot-password', (tester) async {
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    // v1 showed fake security badges / copyright; v2 shouldn't.
    expect(find.textContaining('ENCRYPTION'), findsNothing);
  });

  testWidgets('Login validates email before calling Firebase', (tester) async {
    await tester.pumpWidget(_app(const LoginScreen()));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.text('Sign in'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('Both themes build and expose Aurora colours', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      late AuroraColors colors;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        colors = context.aurora;
        return const Scaffold(body: EmptyState(icon: Icons.inbox, title: 'Nothing here'));
      }), mode: mode));
      await tester.pump(const Duration(milliseconds: 600));
      expect(colors.isDark, mode == ThemeMode.dark);
      expect(find.text('Nothing here'), findsOneWidget);
    }
  });

  testWidgets('AmountText formats Indian rupees', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: Center(child: AmountText(123456.5)))));
    expect(find.text('₹1,23,456.50'), findsOneWidget);
  });
}
