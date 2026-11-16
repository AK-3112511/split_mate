import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'core/router/app_router.dart';
import 'core/session/bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'shared_widgets/feedback.dart';

class SplitMateApp extends ConsumerStatefulWidget {
  const SplitMateApp({super.key});

  @override
  ConsumerState<SplitMateApp> createState() => _SplitMateAppState();
}

class _SplitMateAppState extends ConsumerState<SplitMateApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _links;

  @override
  void initState() {
    super.initState();
    // Deep links: splitmate://join?groupId=…&code=…  (also accepts /join?code=…)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleLink(uri);
    }).catchError((_) {});
    _links = _appLinks.uriLinkStream.listen(_handleLink, onError: (_) {});
  }

  void _handleLink(Uri uri) {
    final isJoin = (uri.scheme == 'splitmate' && uri.host == 'join') || uri.path == '/join';
    final code = uri.queryParameters['code'];
    if (isJoin && code != null && code.isNotEmpty) {
      // The router's redirect parks this behind login/verification if needed.
      ref.read(routerProvider).go('/join?code=${Uri.encodeComponent(code)}');
    }
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionBootstrapProvider);
    final router = ref.watch(routerProvider);
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
      builder: (context, child) => MaterialUiCompatibilityBridge(child: child!),
    );
  }
}
