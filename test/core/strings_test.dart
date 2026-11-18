import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:split_mate/core/l10n/strings.dart';

void main() {
  test('every language fills in names and amounts', () {
    for (final lang in AppLanguage.values) {
      final s = S(lang);
      expect(s.youOweName('Riya'), contains('Riya'), reason: lang.name);
      expect(s.nameOwesName('Riya', 'Aman'), allOf(contains('Riya'), contains('Aman')), reason: lang.name);
      expect(s.youOweAmount('₹120'), contains('₹120'), reason: lang.name);
      expect(s.groupEmptyBody('Goa'), contains('Goa'), reason: lang.name);
      expect(s.navHome, isNotEmpty);
    }
  });

  test('the three languages read differently', () {
    expect(const S(AppLanguage.en).addExpense, 'Add expense');
    expect(const S(AppLanguage.hi).addExpense, 'ख़र्च जोड़ें');
    expect(const S(AppLanguage.hinglish).addExpense, 'Kharcha jodo');
  });

  test('unknown saved language falls back to English', () {
    expect(AppLanguage.fromKey('fr'), AppLanguage.en);
    expect(AppLanguage.fromKey(null), AppLanguage.en);
    expect(AppLanguage.fromKey('hinglish'), AppLanguage.hinglish);
  });

  testWidgets('context.s follows the chosen language', (tester) async {
    Widget app(AppLanguage lang) => MaterialApp(
          home: StringsScope(
            strings: S(lang),
            child: Builder(builder: (context) => Text(context.s.navFriends)),
          ),
        );
    await tester.pumpWidget(app(AppLanguage.en));
    expect(find.text('Friends'), findsOneWidget);
    await tester.pumpWidget(app(AppLanguage.hi));
    expect(find.text('दोस्त'), findsOneWidget);
    await tester.pumpWidget(app(AppLanguage.hinglish));
    expect(find.text('Dost'), findsOneWidget);
  });
}
