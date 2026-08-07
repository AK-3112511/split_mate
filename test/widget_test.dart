import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:split_mate/app.dart';
import 'package:split_mate/core/utils/router.dart';
import 'package:split_mate/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('Login screen compiles and renders', (WidgetTester tester) async {
    final testRouter = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWithValue(testRouter),
        ],
        child: const MyApp(),
      ),
    );

    // Wait for route and animations
    await tester.pumpAndSettle();

    // Verify that the login screen is loaded
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
