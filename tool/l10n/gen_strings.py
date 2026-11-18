"""Regenerates lib/core/l10n/strings.dart from strings_table.py.

Run from the repo root:  python tool/l10n/gen_strings.py
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from strings_table import ROWS  # noqa: E402

root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
keys = [r[0] for r in ROWS]
assert len(keys) == len(set(keys)), 'duplicate keys'


def dart(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def params(en):
    return list(dict.fromkeys(re.findall(r'\{(\w+)\}', en)))


for r in ROWS:
    for t in r[2:]:
        assert params(t) == params(r[1]) or set(params(t)) == set(params(r[1])), r

out = ['''// Generated from one table (English, Hindi, Hinglish). Keep the three in step.
// ignore_for_file: lines_longer_than_80_chars
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../theme/theme_mode_provider.dart';

/// App text language. Hinglish = Hindi in English letters.
enum AppLanguage {
  en('English', 'English'),
  hi('हिन्दी', 'Hindi'),
  hinglish('Hinglish', 'Hindi in English letters');

  final String label;
  final String hint;
  const AppLanguage(this.label, this.hint);

  static AppLanguage fromKey(String? key) =>
      AppLanguage.values.firstWhere((l) => l.name == key, orElse: () => AppLanguage.en);
}

final appLanguageProvider = StateNotifierProvider<AppLanguageNotifier, AppLanguage>((ref) {
  return AppLanguageNotifier(ref);
});

class AppLanguageNotifier extends StateNotifier<AppLanguage> {
  static const _key = 'app_language';
  final Ref _ref;
  AppLanguageNotifier(this._ref) : super(_read(_ref));

  static AppLanguage _read(Ref ref) {
    try {
      return AppLanguage.fromKey(ref.read(sharedPreferencesProvider)?.getString(_key));
    } catch (_) {
      return AppLanguage.en;
    }
  }

  Future<void> set(AppLanguage lang) async {
    state = lang;
    try {
      await _ref.read(sharedPreferencesProvider)?.setString(_key, lang.name);
    } catch (_) {}
  }
}

/// Puts the current strings in the tree; `context.s` reads them (and
/// rebuilds the widget when the language changes).
class StringsScope extends InheritedWidget {
  final S strings;
  const StringsScope({super.key, required this.strings, required super.child});

  @override
  bool updateShouldNotify(StringsScope old) => old.strings.lang != strings.lang;
}

extension StringsContext on BuildContext {
  S get s => dependOnInheritedWidgetOfExactType<StringsScope>()?.strings ?? S.current;
}

/// The app's text in the chosen language. Screens not translated yet keep
/// their English text in place.
class S {
  final AppLanguage lang;
  const S(this.lang);

  /// For code without a BuildContext (toasts, helpers). Set by the app.
  static S current = const S(AppLanguage.en);

  String _t(String key) =>
      (switch (lang) { AppLanguage.en => _en, AppLanguage.hi => _hi, AppLanguage.hinglish => _hinglish })[key] ??
      _en[key] ??
      key;
''']
for r in ROWS:
    key, en = r[0], r[1]
    ps = params(en)
    if ps:
        args = ', '.join(f'String {p}' for p in ps)
        chain = ''.join(f".replaceAll('{{{p}}}', {p})" for p in ps)
        out.append(f"  String {key}({args}) => _t('{key}'){chain};")
    else:
        out.append(f"  String get {key} => _t('{key}');")
out.append('}\n')
for name, idx in [('_en', 1), ('_hi', 2), ('_hinglish', 3)]:
    out.append(f'const Map<String, String> {name} = {{')
    for r in ROWS:
        out.append(f"  '{r[0]}': {dart(r[idx])},")
    out.append('};\n')
open(root + '/lib/core/l10n/strings.dart', 'w', encoding='utf-8').write('\n'.join(out))
print(len(ROWS), 'strings')
