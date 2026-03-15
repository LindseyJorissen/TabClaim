import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  const SettingsState({this.currency = 'USD'});
  final String currency;
}

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  static const _kCurrency = 'tc_currency';

  @override
  Future<SettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsState(currency: prefs.getString(_kCurrency) ?? 'USD');
  }

  Future<void> setCurrency(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, currency);
    state = AsyncData(SettingsState(currency: currency));
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);

/// Supported currencies shown in the picker.
const supportedCurrencies = [
  (code: 'USD', label: 'US Dollar',        symbol: '\$'),
  (code: 'EUR', label: 'Euro',             symbol: '€'),
  (code: 'GBP', label: 'British Pound',    symbol: '£'),
  (code: 'CAD', label: 'Canadian Dollar',  symbol: 'C\$'),
  (code: 'AUD', label: 'Australian Dollar',symbol: 'A\$'),
  (code: 'JPY', label: 'Japanese Yen',     symbol: '¥'),
];
