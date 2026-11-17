import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/share_text.dart';

void main() {
  test('pay link points at the hosted page with %20-encoded fields', () {
    final link = upiPayPageLink(vpa: ' arham@okaxis ', name: 'Arham Kansal', amount: 100, note: 'SplitMate · Goa Trip');
    final uri = Uri.parse(link);
    expect(uri.host, 'splitmate-6b600.web.app');
    expect(uri.path, '/pay');
    expect(link, isNot(contains('+')));
    expect(uri.queryParameters['pa'], 'arham@okaxis');
    expect(uri.queryParameters['pn'], 'Arham Kansal');
    expect(uri.queryParameters['am'], '100.00');
    expect(uri.queryParameters['tn'], 'SplitMate · Goa Trip');
  });

  test('reminder mentions the amount and group, and adds links only when given', () {
    final plain = paymentReminderText(debtorName: 'Rahul', groupName: 'Goa Trip', amount: 450);
    expect(plain, contains('you owe me ₹450 for "Goa Trip"'));
    expect(plain, isNot(contains('http')));

    final full = paymentReminderText(
      debtorName: 'Rahul',
      groupName: 'Goa Trip',
      amount: 450,
      payLink: 'https://pay.example',
      claimLink: 'https://claim.example',
    );
    expect(full, contains('Pay with any UPI app: https://pay.example'));
    expect(full, contains('take over your spot on SplitMate: https://claim.example'));
    expect(full, isNot(contains('\n'))); // one line in WhatsApp
  });
}
