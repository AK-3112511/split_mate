import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/features/groups/presentation/widgets/settle_up.dart';

void main() {
  test('UPI link encodes spaces as %20, never +', () {
    final uri = upiUri(vpa: ' friend@okaxis ', name: 'Arham Kansal', amount: 150, note: 'SplitMate · Goa Trip');
    final s = uri.toString();
    expect(s, startsWith('upi://pay?'));
    expect(s, isNot(contains('+')));
    expect(s, contains('pn=Arham%20Kansal'));
    expect(s, contains('tn=SplitMate%20%C2%B7%20Goa%20Trip'));
    expect(uri.queryParameters['pa'], 'friend@okaxis');
    expect(uri.queryParameters['am'], '150.00');
    expect(uri.queryParameters['cu'], 'INR');
  });

  test('UPI note is capped at 50 characters', () {
    final uri = upiUri(vpa: 'a@b', name: 'A', amount: 1.005, note: 'x' * 80);
    expect(uri.queryParameters['tn']!.length, 50);
  });
}
