import 'package:flutter/widgets.dart';

/// Supported currencies and currency metadata in MediCrate.
class AppCurrency {
  final String code;
  final String symbol;
  final String name;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  static const String inr = 'INR';
  static const String usd = 'USD';
  static const String eur = 'EUR';
  static const String gbp = 'GBP';
  static const String defaultCurrency = inr;
  static const List<String> codes = [inr, usd, eur, gbp];

  static const List<AppCurrency> supportedCurrencies = [
    AppCurrency(code: inr, symbol: '₹', name: 'Indian Rupee'),
    AppCurrency(code: usd, symbol: '\$', name: 'US Dollar'),
    AppCurrency(code: eur, symbol: '€', name: 'Euro'),
    AppCurrency(code: gbp, symbol: '£', name: 'British Pound'),
  ];

  static String getSymbol(String? code) {
    if (code == null || code.isEmpty) return '₹';
    for (final c in supportedCurrencies) {
      if (c.code.toUpperCase() == code.toUpperCase()) {
        return c.symbol;
      }
    }
    return code;
  }

  static String getName(String? code) {
    if (code == null || code.isEmpty) return 'Indian Rupee';
    for (final c in supportedCurrencies) {
      if (c.code.toUpperCase() == code.toUpperCase()) {
        return c.name;
      }
    }
    return code;
  }

  static String formatCodeAndName(String? code) {
    final symbol = getSymbol(code);
    final name = getName(code);
    final c = (code != null && code.isNotEmpty) ? code : defaultCurrency;
    return '$symbol $c — $name';
  }

  /// Derives initial default currency from device locale/region without requiring GPS permissions.
  /// Falls back to INR for unsupported/unknown regions.
  static String detectDefaultCurrency([String? countryCode]) {
    final code = countryCode != null
        ? countryCode.toUpperCase()
        : (WidgetsBinding.instance.platformDispatcher.locale.countryCode
                  ?.toUpperCase() ??
              '');

    switch (code) {
      case 'IN':
        return inr;
      case 'US':
        return usd;
      case 'GB':
        return gbp;
      case 'DE':
      case 'FR':
      case 'IT':
      case 'ES':
      case 'NL':
        return eur;
      default:
        return defaultCurrency;
    }
  }
}
