import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency.dart';

/// Exchange rates to rupees from ExchangeRate-API's open endpoint (free, no
/// key, updated daily; attribution shown next to the rate). Only the currency
/// code is sent. The last rate for each currency is kept on the phone so it
/// still works offline, and the rate is always editable.
class FxRates {
  FxRates._();

  static const String attributionUrl = 'https://www.exchangerate-api.com';
  static final Map<String, ({double rate, DateTime at})> _memory = {};

  /// ₹ per 1 unit of [code], or null when unknown and offline.
  static Future<({double rate, bool live})?> toInr(String code) async {
    if (!Currencies.isForeign(code)) return (rate: 1.0, live: true);
    final cached = _memory[code];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(hours: 6)) {
      return (rate: cached.rate, live: true);
    }
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      try {
        final req = await client.getUrl(Uri.parse('https://open.er-api.com/v6/latest/$code'));
        final res = await req.close().timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
          final inr = (body['rates'] as Map?)?['INR'];
          if (inr is num && inr > 0) {
            final rate = inr.toDouble();
            _memory[code] = (rate: rate, at: DateTime.now());
            _save(code, rate);
            return (rate: rate, live: true);
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // Offline or the service is down: fall back to the last rate we saw.
    }
    final saved = await _load(code);
    return saved == null ? null : (rate: saved, live: false);
  }

  static Future<void> _save(String code, double rate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('fx_$code', rate);
    } catch (_) {}
  }

  static Future<double?> _load(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble('fx_$code');
    } catch (_) {
      return null;
    }
  }
}
