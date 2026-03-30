import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class SettingsService {
  static const _kTheme          = 'settings_theme';
  static const _kCurrency       = 'settings_currency';
  static const _kDateFormat     = 'settings_date_format';
  static const _kDefaultTab     = 'settings_default_tab';
  static const _kBiometricLock  = 'settings_biometric_lock';

  // ── Theme ──────────────────────────────────────────────────────────────────

  static Future<ThemeMode> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kTheme) ?? 0;
    return ThemeMode.values[idx.clamp(0, ThemeMode.values.length - 1)];
  }

  static Future<void> saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTheme, mode.index);
  }

  // ── Currency ───────────────────────────────────────────────────────────────

  static Future<String> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrency) ?? 'EUR';
  }

  static Future<void> saveCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrency, code);
  }

  // ── Date format ────────────────────────────────────────────────────────────

  static Future<String> loadDateFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDateFormat) ?? 'yMMMd';
  }

  static Future<void> saveDateFormat(String format) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDateFormat, format);
  }

  // ── Default tab ────────────────────────────────────────────────────────────

  static Future<int> loadDefaultTab() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_kDefaultTab) ?? 0).clamp(0, 2);
  }

  static Future<void> saveDefaultTab(int tab) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDefaultTab, tab);
  }

  // ── Biometric lock ─────────────────────────────────────────────────────────

  static Future<bool> loadBiometricLock() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricLock) ?? false;
  }

  static Future<void> saveBiometricLock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricLock, enabled);
  }
}
