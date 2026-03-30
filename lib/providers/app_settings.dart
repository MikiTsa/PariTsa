import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenses_tracker/services/settings_service.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode     = ThemeMode.system;
  String    _currency      = 'EUR';
  String    _dateFormat    = 'yMMMd';
  int       _defaultTab    = 0;
  bool      _biometricLock = false;

  ThemeMode get themeMode     => _themeMode;
  String    get currency      => _currency;
  String    get dateFormat    => _dateFormat;
  int       get defaultTab    => _defaultTab;
  bool      get biometricLock => _biometricLock;

  // ── Currency symbol ────────────────────────────────────────────────────────

  static const Map<String, String> _symbols = {
    'EUR': '€',
    'USD': '\$',
    'GBP': '£',
    'CHF': 'Fr',
    'JPY': '¥',
    'CNY': '¥',
    'CAD': 'CA\$',
    'AUD': 'A\$',
    'INR': '₹',
    'BRL': 'R\$',
    'RUB': '₽',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'PLN': 'zł',
    'RON': 'lei',
    'BGN': 'лв',
    'HUF': 'Ft',
    'CZK': 'Kč',
    'TRY': '₺',
  };

  String get currencySymbol => _symbols[_currency] ?? _currency;

  // ── Formatting helpers ─────────────────────────────────────────────────────

  String formatAmount(double amount) =>
      '$currencySymbol${amount.toStringAsFixed(2)}';

  String formatAmountFull(double amount) {
    final fmt = NumberFormat('#,##0.00');
    return '$currencySymbol${fmt.format(amount)}';
  }

  String formatDate(DateTime date) {
    switch (_dateFormat) {
      case 'dd/MM/yyyy':
        return DateFormat('dd/MM/yyyy').format(date);
      case 'MM/dd/yyyy':
        return DateFormat('MM/dd/yyyy').format(date);
      case 'yyyy-MM-dd':
        return DateFormat('yyyy-MM-dd').format(date);
      default:
        return DateFormat.yMMMd().format(date);
    }
  }

  String formatDateWithTime(DateTime date) {
    switch (_dateFormat) {
      case 'dd/MM/yyyy':
        return DateFormat('dd/MM/yyyy HH:mm').format(date);
      case 'MM/dd/yyyy':
        return DateFormat('MM/dd/yyyy h:mm a').format(date);
      case 'yyyy-MM-dd':
        return DateFormat('yyyy-MM-dd HH:mm').format(date);
      default:
        return DateFormat.yMMMd().add_jm().format(date);
    }
  }

  // ── Load / save ────────────────────────────────────────────────────────────

  Future<void> load() async {
    _themeMode     = await SettingsService.loadTheme();
    _currency      = await SettingsService.loadCurrency();
    _dateFormat    = await SettingsService.loadDateFormat();
    _defaultTab    = await SettingsService.loadDefaultTab();
    _biometricLock = await SettingsService.loadBiometricLock();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await SettingsService.saveTheme(mode);
  }

  Future<void> setCurrency(String code) async {
    if (_currency == code) return;
    _currency = code;
    notifyListeners();
    await SettingsService.saveCurrency(code);
  }

  Future<void> setDateFormat(String format) async {
    if (_dateFormat == format) return;
    _dateFormat = format;
    notifyListeners();
    await SettingsService.saveDateFormat(format);
  }

  Future<void> setDefaultTab(int tab) async {
    if (_defaultTab == tab) return;
    _defaultTab = tab;
    notifyListeners();
    await SettingsService.saveDefaultTab(tab);
  }

  Future<void> setBiometricLock(bool enabled) async {
    if (_biometricLock == enabled) return;
    _biometricLock = enabled;
    notifyListeners();
    await SettingsService.saveBiometricLock(enabled);
  }
}

// ─── InheritedNotifier — makes AppSettings available to the whole tree ────────

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()!
        .notifier!;
  }
}
