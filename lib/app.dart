import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'core/l10n/strings.dart';
import 'core/router/app_router.dart';
import 'core/security/app_lock.dart';
import 'core/session/bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'shared_widgets/feedback.dart';

class SplitMateApp extends ConsumerStatefulWidget {
  const SplitMateApp({super.key});

  @override
  ConsumerState<SplitMateApp> createState() => _SplitMateAppState();
}

class _SplitMateAppState extends ConsumerState<SplitMateApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _links;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(sessionBootstrapProvider).onResumed());
    // Invite links: https://splitmate-6b600.web.app/join?code=… (App Link) and
    // the older splitmate://join?code=… both end up here.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri);
    }).catchError((_) {});
    _links = _appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  void _handleLink(Uri uri) {
    // Home-screen widget and long-press shortcuts.
    if (uri.scheme == 'splitmate' && (uri.host == 'add' || uri.host == 'scan')) {
      _quickLaunch(uri.host == 'add' ? '/expense/new' : '/scan');
      return;
    }
    final isJoin = (uri.scheme == 'splitmate' && uri.host == 'join') || uri.path == '/join';
    final code = uri.queryParameters['code'];
    final guest = uri.queryParameters['guest'];
    if (isJoin && code != null && code.isNotEmpty) {
      // The router's redirect parks this behind login/verification if needed.
      final claim = guest == null || guest.isEmpty ? '' : '&guest=${Uri.encodeComponent(guest)}';
      ref.read(routerProvider).go('/join?code=${Uri.encodeComponent(code)}$claim');
    }
  }

  String? _lastQuick;
  DateTime _lastQuickAt = DateTime(2000);

  /// Opens [path] straight away: no intro animation, and on top of whatever
  /// was open when the app is already running (Close goes back there).
  void _quickLaunch(String path) {
    // On a cold start the same link arrives twice (initial link + stream).
    final now = DateTime.now();
    if (path == _lastQuick && now.difference(_lastQuickAt) < const Duration(seconds: 3)) return;
    _lastQuick = path;
    _lastQuickAt = now;

    final router = ref.read(routerProvider);
    final splash = ref.read(splashDoneProvider.notifier);
    final running = splash.state && ref.read(authStateProvider).valueOrNull != null;
    splash.state = true;
    if (router.routerDelegate.currentConfiguration.uri.path == path) return;
    running ? router.push(path) : router.go(path);
  }

  @override
  void dispose() {
    _links?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionBootstrapProvider);
    final router = ref.watch(routerProvider);
    final strings = S(ref.watch(appLanguageProvider));
    S.current = strings;
    return MaterialApp.router(
      title: 'SplitMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      scaffoldMessengerKey: rootMessengerKey,
      // Bridges ThemeData/localizations to third-party packages (go_router,
      // fl_chart, confetti…) that still import legacy package:flutter/material.dart.
      // Remove once those packages migrate to package:material_ui.
      // ignore: deprecated_member_use
      builder: (context, child) => MaterialUiCompatibilityBridge(
        child: StringsScope(strings: strings, child: AppLockGate(child: child!)),
      ),
    );
  }
}
