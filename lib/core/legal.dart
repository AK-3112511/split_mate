import 'package:url_launcher/url_launcher.dart';

/// Public pages on Firebase Hosting (see `hosting/`).
const String privacyPolicyUrl = 'https://splitmate-6b600.web.app/privacy';
const String deleteAccountInfoUrl = 'https://splitmate-6b600.web.app/delete-account';
const String supportEmail = 'splitmate.support123@gmail.com';

Future<void> openPrivacyPolicy() async {
  try {
    await launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication);
  } catch (_) {}
}
