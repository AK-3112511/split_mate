import 'package:flutter_test/flutter_test.dart';
import 'package:split_mate/core/legal.dart';
import 'package:split_mate/core/router/app_router.dart';

void main() {
  test('group invites are https links on the verified host', () {
    final link = Uri.parse(groupInviteLink('AB12CD'));
    expect(link.scheme, 'https');
    expect(link.host, 'splitmate-6b600.web.app'); // must match AndroidManifest + assetlinks.json
    expect(link.path, '/join');
    expect(link.queryParameters['code'], 'AB12CD');
  });

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
