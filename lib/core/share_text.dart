import 'legal.dart';
import 'utils/money.dart';

/// Tappable pay link for chat apps: WhatsApp doesn't make `upi://` links
/// tappable, so this points to hosting/pay.html, which opens the UPI app.
String upiPayPageLink({required String vpa, required String name, required double amount, required String note}) {
  final params = {
    'pa': vpa.trim(),
    'pn': name,
    'am': Money.round2(amount).toStringAsFixed(2),
    'tn': note.length > 50 ? note.substring(0, 50) : note,
  };
  final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
  return '$webBase/pay?$query';
}

/// Friendly "you owe me" message for WhatsApp. Adds a pay link when I have a
/// UPI ID, and a claim link when the person isn't on SplitMate yet.
String paymentReminderText({
  required String debtorName,
  required String groupName,
  required double amount,
  String? payLink,
  String? claimLink,
}) {
  // One line, no breaks: reads as a single message in WhatsApp.
  final b = StringBuffer('Hi $debtorName! A quick reminder from SplitMate: you owe me ${Money.format(amount)} for "$groupName".');
  if (payLink != null) b.write(' Pay with any UPI app: $payLink');
  if (claimLink != null) b.write(' See the details and take over your spot on SplitMate: $claimLink');
  b.write(' Thanks!');
  return b.toString();
}
