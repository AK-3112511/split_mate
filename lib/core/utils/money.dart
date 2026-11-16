import 'package:intl/intl.dart';

/// Result of parsing user-typed money input.
class MoneyParseResult {
  final double? value;
  final String? error;
  const MoneyParseResult.ok(double this.value) : error = null;
  const MoneyParseResult.fail(String this.error) : value = null;
  bool get isValid => value != null;
}

/// Single source of truth for currency math & formatting (INR, en_IN grouping).
///
/// All arithmetic that must be exact is done in integer **paise**.
class Money {
  Money._();

  /// Upper bound for a single entry: ₹1 crore.
  static const double maxAmount = 10000000;

  static final NumberFormat _full =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final NumberFormat _whole =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final NumberFormat _plain = NumberFormat.decimalPattern('en_IN');

  static int toPaise(num value) => (value * 100).round();
  static double fromPaise(int paise) => paise / 100.0;
  static double round2(num value) => fromPaise(toPaise(value));

  /// True when both values are the same number of paise.
  static bool equals(num a, num b) => toPaise(a) == toPaise(b);
  static bool isZero(num v) => toPaise(v) == 0;

  /// ₹1,23,456.50 — drops ".00" for whole amounts unless [alwaysDecimals].
  static String format(num value, {bool alwaysDecimals = false, bool signed = false}) {
    final rounded = round2(value);
    final abs = rounded.abs();
    final isWhole = toPaise(abs) % 100 == 0;
    final body = (isWhole && !alwaysDecimals) ? _whole.format(abs) : _full.format(abs);
    if (toPaise(rounded) < 0) return '-$body';
    if (signed && toPaise(rounded) > 0) return '+$body';
    return body;
  }

  /// Compact label for charts / tight spaces: ₹950, ₹1.2K, ₹3.4L, ₹1.1Cr.
  static String compact(num value) {
    final v = value.abs().toDouble();
    final sign = value < 0 ? '-' : '';
    String trim(double x) {
      final s = x.toStringAsFixed(1);
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }

    if (v >= 10000000) return '$sign₹${trim(v / 10000000)}Cr';
    if (v >= 100000) return '$sign₹${trim(v / 100000)}L';
    if (v >= 1000) return '$sign₹${trim(v / 1000)}K';
    return '$sign${_whole.format(v.round())}';
  }

  /// Plain digits for pre-filling input fields: "1200" or "1200.5".
  static String plain(num value) {
    final r = round2(value);
    if (toPaise(r) % 100 == 0) return r.toStringAsFixed(0);
    final s = r.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }

  /// Grouped digits without symbol: "1,20,000".
  static String grouped(num value) => _plain.format(round2(value));

  /// Parses user input such as "1,200", "1,20,000.5", "12,5" (decimal comma)
  /// or "₹ 450". Rejects negatives, NaN/∞, more than 2 decimals and absurd values.
  static MoneyParseResult parse(String? raw, {bool allowZero = false}) {
    var s = (raw ?? '')
        .trim()
        .replaceAll('₹', '')
        .replaceAll(' ', '')
        .replaceAll(' ', '');
    if (s.isEmpty) return const MoneyParseResult.fail('Enter an amount');
    if (s.startsWith('-')) return const MoneyParseResult.fail('Amount can\'t be negative');

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');
    if (hasComma && hasDot) {
      s = s.replaceAll(',', ''); // commas are thousands separators
    } else if (hasComma) {
      s = _looksLikeDecimalComma(s) ? s.replaceAll(',', '.') : s.replaceAll(',', '');
    }

    if (!RegExp(r'^(\d+\.?\d*|\.\d+)$').hasMatch(s)) {
      return const MoneyParseResult.fail('Use numbers only');
    }
    final parts = s.split('.');
    if (parts.length == 2 && parts[1].length > 2) {
      return const MoneyParseResult.fail('Max 2 decimal places');
    }
    final value = double.tryParse(s);
    if (value == null || value.isNaN || value.isInfinite) {
      return const MoneyParseResult.fail('Use numbers only');
    }
    if (value > maxAmount) {
      return MoneyParseResult.fail('That\'s more than ${_whole.format(maxAmount)}');
    }
    if (!allowZero && toPaise(value) <= 0) {
      return const MoneyParseResult.fail('Amount must be more than ₹0');
    }
    return MoneyParseResult.ok(round2(value));
  }

  /// "12,5" / "12,50" → decimal comma. "1,200" / "12,000" / "1,20,000" → grouping.
  static bool _looksLikeDecimalComma(String s) {
    final segments = s.split(',');
    return segments.length == 2 && segments[1].isNotEmpty && segments[1].length <= 2;
  }
}
