import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/router/app_router.dart';

void main() {
  test('only invite links are kept across sign-in', () {
    expect(isInviteLink('/join?code=AFX8S8'), isTrue);
    expect(isInviteLink('/join'), isTrue);
    // Where the previous account was when it signed out.
    expect(isInviteLink('/profile'), isFalse);
    expect(isInviteLink('/groups/abc123'), isFalse);
    expect(isInviteLink('/joined-groups'), isFalse);
    expect(isInviteLink(null), isFalse);
  });
}
