import 'package:url_launcher/url_launcher.dart';

/// Public pages on Firebase Hosting (see `hosting/`).
const String webBase = 'https://splitmate-6b600.web.app';
const String privacyPolicyUrl = '$webBase/privacy';
const String deleteAccountInfoUrl = '$webBase/delete-account';

/// Tappable group invite. Android opens it in the app (App Links, verified by
/// hosting/.well-known/assetlinks.json); otherwise it shows hosting/join.html.
String groupInviteLink(String code) => '$webBase/join?code=${Uri.encodeQueryComponent(code)}';
const String supportEmail = 'splitmate.support123@gmail.com';

Future<void> openPrivacyPolicy() async {
  try {
    await launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication);
  } catch (_) {}
}
