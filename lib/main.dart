import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/settings/device_settings.dart';
import 'core/theme/theme_mode_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // App Check: proves to Firebase that requests come from this app on a real
  // phone (Play Integrity), not from a script holding the API key. Debug
  // builds use the debug provider; its token is printed in logcat.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  } catch (_) {}
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    // Settings fall back to their defaults; nothing else depends on prefs.
  }

  // Crash reports (release builds, unless switched off in Profile). They carry
  // the stack trace and device model, never the user's name, email or money.
  final crashReports = (prefs?.getBool(CrashReportsToggle.prefKey) ?? true) && !kDebugMode;
  try {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(crashReports);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SplitMateApp(),
    ),
  );
}
