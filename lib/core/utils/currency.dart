import 'package:intl/intl.dart';
import 'money.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  const CurrencyInfo(this.code, this.symbol, this.name);
}

/// Currencies offered for expenses abroad. Groups always settle in rupees:
/// a foreign expense is converted when it's saved, and keeps its original
/// amount and rate for display.
class Currencies {
  Currencies._();

  static const String inr = 'INR';

  static const List<CurrencyInfo> all = [
    CurrencyInfo('INR', '₹', 'Indian rupee'),
    CurrencyInfo('USD', r'US$', 'US dollar'),
    CurrencyInfo('EUR', '€', 'Euro'),
    CurrencyInfo('GBP', '£', 'British pound'),
    CurrencyInfo('AED', 'AED', 'UAE dirham'),
    CurrencyInfo('THB', '฿', 'Thai baht'),
    CurrencyInfo('SGD', r'S$', 'Singapore dollar'),
    CurrencyInfo('MYR', 'RM', 'Malaysian ringgit'),
    CurrencyInfo('IDR', 'Rp', 'Indonesian rupiah'),
    CurrencyInfo('VND', '₫', 'Vietnamese dong'),
    CurrencyInfo('LKR', 'LKR', 'Sri Lankan rupee'),
    CurrencyInfo('NPR', 'NPR', 'Nepalese rupee'),
    CurrencyInfo('BTN', 'Nu.', 'Bhutanese ngultrum'),
    CurrencyInfo('MVR', 'MVR', 'Maldivian rufiyaa'),
    CurrencyInfo('JPY', '¥', 'Japanese yen'),
    CurrencyInfo('KRW', '₩', 'South Korean won'),
    CurrencyInfo('CNY', 'CN¥', 'Chinese yuan'),
    CurrencyInfo('HKD', r'HK$', 'Hong Kong dollar'),
    CurrencyInfo('AUD', r'A$', 'Australian dollar'),
    CurrencyInfo('NZD', r'NZ$', 'New Zealand dollar'),
    CurrencyInfo('CAD', r'C$', 'Canadian dollar'),
    CurrencyInfo('CHF', 'CHF', 'Swiss franc'),
    CurrencyInfo('SAR', 'SAR', 'Saudi riyal'),
    CurrencyInfo('QAR', 'QAR', 'Qatari riyal'),
    CurrencyInfo('TRY', '₺', 'Turkish lira'),
    CurrencyInfo('ZAR', 'R', 'South African rand'),
  ];

  static CurrencyInfo of(String? code) => all.firstWhere(
    (c) => c.code == code,
    orElse: () => CurrencyInfo(code ?? inr, code ?? '₹', code ?? 'Indian rupee'),
  );

  static bool isForeign(String? code) => code != null && code != inr;

  /// "₹1,200", "US$45.50", "AED 120". Rupees use the app's usual format.
  static String format(num value, String? code) {
    if (!isForeign(code)) return Money.format(value);
    final info = of(code);
    final whole = Money.toPaise(value) % 100 == 0;
    final letters = RegExp(r'^[A-Za-z.]+$').hasMatch(info.symbol);
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: letters ? '${info.symbol} ' : info.symbol,
      decimalDigits: whole ? 0 : 2,
    ).format(value);
  }

  /// Converts per-person amounts in a foreign currency to rupees at [rate]
  /// (₹ per unit). The rupee shares add up exactly to the converted total;
  /// leftover paise go to the largest fractional parts.
  static Map<String, double> toRupees(Map<String, double> shares, double rate) {
    if (shares.isEmpty) return const {};
    final cents = {for (final e in shares.entries) e.key: Money.toPaise(e.value)};
    final totalCents = cents.values.fold<int>(0, (a, b) => a + b);
    final targetPaise = (totalCents * rate).round();
    final exact = {for (final e in cents.entries) e.key: e.value * rate};
    final floor = {for (final e in exact.entries) e.key: e.value.floor()};
    var left = targetPaise - floor.values.fold<int>(0, (a, b) => a + b);
    final order = exact.keys.toList()..sort((a, b) => (exact[b]! - floor[b]!).compareTo(exact[a]! - floor[a]!));
    for (final k in order) {
      if (left <= 0) break;
      floor[k] = floor[k]! + 1;
      left--;
    }
    return {
      for (final e in floor.entries)
        if (e.value > 0) e.key: Money.fromPaise(e.value),
    };
  }

  /// ₹ amount for a foreign amount, rounded to paise.
  static double convert(double amount, double rate) => Money.fromPaise((Money.toPaise(amount) * rate).round());
}
