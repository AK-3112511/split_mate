import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the instance loaded before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(sharedPreferencesProvider));
});

/// System / Light / Dark, persisted locally so the first frame is already right.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';
  final SharedPreferences? _prefs;

  ThemeModeNotifier(this._prefs) : super(_read(_prefs));

  static ThemeMode _read(SharedPreferences? prefs) {
    try {
      switch (prefs?.getString(_key)) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
      }
    } catch (_) {}
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await _prefs?.setString(_key, mode.name);
    } catch (_) {}
  }
}
