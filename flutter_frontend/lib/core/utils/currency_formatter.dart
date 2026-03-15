import 'package:intl/intl.dart';

abstract final class CurrencyFormatter {
  static String format(double amount, {String currency = 'USD'}) {
    final formatter = NumberFormat.currency(
      symbol: _symbolFor(currency),
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currency = 'USD'}) {
    if (amount == amount.roundToDouble()) {
      return '${_symbolFor(currency)}${amount.toInt()}';
    }
    return format(amount, currency: currency);
  }

  static String _symbolFor(String currency) {
    return switch (currency.toUpperCase()) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      'AUD' => 'A\$',
      'CAD' => 'C\$',
      _ => currency,
    };
  }
}
