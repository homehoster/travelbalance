import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static final Map<String, double> _cache = {};

  static const List<String> supportedCurrencies = [
    'EUR', 'USD', 'GBP', 'CHF', 'JPY', 'CAD', 'AUD', 'SEK', 'NOK', 'DKK',
    'CZK', 'PLN', 'HUF', 'TRY', 'RON', 'BGN', 'HRK', 'ISK', 'MXN', 'BRL',
    'CNY', 'KRW', 'SGD', 'HKD', 'THB', 'INR', 'IDR', 'ZAR',
  ];

  /// Returns how many EUR you get for 1 unit of [currency].
  static Future<double> getRateToEur(String currency) async {
    if (currency == 'EUR') return 1.0;
    if (_cache.containsKey(currency)) return _cache[currency]!;
    try {
      final uri = Uri.parse(
        'https://api.frankfurter.app/latest?from=$currency&to=EUR',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>;
        final rate = (rates['EUR'] as num).toDouble();
        _cache[currency] = rate;
        return rate;
      }
    } catch (_) {}
    return _cache[currency] ?? 1.0;
  }

  static void clearCache() => _cache.clear();
}
