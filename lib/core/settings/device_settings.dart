import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_mode_provider.dart';

/// A yes/no setting kept on this phone (not in the account).
class DeviceToggle extends StateNotifier<bool> {
  final SharedPreferences? _prefs;
  final String key;
  DeviceToggle(this._prefs, this.key, bool fallback) : super(_read(_prefs, key, fallback));

  static bool _read(SharedPreferences? prefs, String key, bool fallback) {
    try {
      return prefs?.getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      await _prefs?.setBool(key, value);
    } catch (_) {}
  }
}

/// Ask for fingerprint / phone PIN when SplitMate opens. Off until turned on.
final appLockEnabledProvider = StateNotifierProvider<DeviceToggle, bool>(
  (ref) => DeviceToggle(ref.watch(sharedPreferencesProvider), 'app_lock', false),
);

/// Crashlytics. On by default (release builds only), switchable in Profile.
final crashReportsProvider = StateNotifierProvider<CrashReportsToggle, bool>(
  (ref) => CrashReportsToggle(ref.watch(sharedPreferencesProvider)),
);

class CrashReportsToggle extends DeviceToggle {
  static const prefKey = 'crash_reports';
  CrashReportsToggle(SharedPreferences? prefs) : super(prefs, prefKey, true);

  @override
  Future<void> set(bool value) async {
    await super.set(value);
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(value && !kDebugMode);
    } catch (_) {}
  }
}
