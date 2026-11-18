import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:split_mate/core/theme/app_theme.dart';
import 'package:split_mate/features/groups/presentation/widgets/settle_up.dart';

void main() {
  testWidgets('UPI QR sheet shows a scannable code, the payee and the amount', (tester) async {
    var received = false;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showUpiQrSheet(
                  context,
                  vpa: 'riya@okicici',
                  name: 'Riya',
                  amount: 1105.72,
                  note: 'SplitMate · Goa',
                  onReceived: () => received = true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      upiUri(vpa: 'riya@okicici', name: 'Riya', amount: 1105.72).toString(),
      startsWith('upi://pay?pa=riya%40okicici&pn=Riya&am=1105.72&cu=INR'),
    );
    expect(find.text('riya@okicici'), findsOneWidget);
    expect(find.textContaining('1,105.72'), findsWidgets);

    await tester.tap(find.text('They paid · record it'));
    await tester.pumpAndSettle();
    expect(received, isTrue);
  });

  test('a plain QR has no amount', () {
    final uri = upiUri(vpa: 'riya@okicici', name: 'Riya');
    expect(uri.toString(), isNot(contains('am=')));
    expect(uri.toString(), isNot(contains('tn=')));
  });
}
