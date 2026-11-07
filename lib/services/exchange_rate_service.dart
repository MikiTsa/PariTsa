import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A conversion rate between a foreign currency and the default currency.
class RateQuote {
  /// Units of the foreign currency per 1 unit of the default currency.
  final double rate;

  /// True when the rate came from the offline cache instead of a live fetch.
  final bool estimated;

  const RateQuote(this.rate, {this.estimated = false});
}

/// Fetches daily exchange rates (free, no API key):
///   1. fawazahmed0/currency-api via jsDelivr — 300+ currencies, history by date
///   2. the same data mirrored on Cloudflare Pages
///   3. open.er-api.com — latest rates only
///
/// The latest table for the default currency is also stored in
/// SharedPreferences under [prefsKey]; the Android wallet service reads the
/// same entry ("flutter.fx_latest_<code>") to convert payments offline.
class ExchangeRateService {
  ExchangeRateService({http.Client? client})
      : _client = client ?? http.Client();

  static final ExchangeRateService instance = ExchangeRateService();

  final http.Client _client;
  final Map<String, Map<String, double>> _tables = {};
  final Map<String, DateTime> _latestFetchedAt = {};

  static const _timeout = Duration(seconds: 8);
  static const _latestMaxAge = Duration(hours: 6);

  /// History in the primary source starts here; older dates use latest.
  static final _firstDatedDay = DateTime(2024, 3, 2);

  static String prefsKey(String base) => 'fx_latest_${base.toLowerCase()}';

  /// Rate to convert [from] into [to] on [date] (today when null).
  ///
  /// Returns null when the currency is unknown, or when offline with no
  /// cached table (or [allowCached] is false).
  Future<RateQuote?> quote({
    required String from,
    required String to,
    DateTime? date,
    bool allowCached = true,
  }) async {
    final f = from.toLowerCase();
    final t = to.toLowerCase();
    if (f == t) return const RateQuote(1);

    final tag = _tagFor(date);
    var table = await _table(t, tag);
    if (table == null && tag != 'latest') table = await _table(t, 'latest');
    if (table != null) return _rateFrom(table, f);

    if (!allowCached) return null;
    final cached = await _cachedLatest(t);
    if (cached == null) return null;
    final q = _rateFrom(cached, f);
    return q == null ? null : RateQuote(q.rate, estimated: true);
  }

  /// Fetches and stores the latest table so offline conversions (including
  /// the Android wallet service) have recent rates to fall back on.
  Future<void> prewarm(String base) async {
    await _table(base.toLowerCase(), 'latest');
  }

  RateQuote? _rateFrom(Map<String, double> table, String code) {
    final r = table[code];
    return (r != null && r > 0) ? RateQuote(r) : null;
  }

  /// 'latest' for today, future dates and dates before the history starts;
  /// otherwise the day as YYYY-MM-DD.
  String _tagFor(DateTime? date) {
    if (date == null) return 'latest';
    final now = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (!day.isBefore(today) || day.isBefore(_firstDatedDay)) return 'latest';
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  Future<Map<String, double>?> _table(String base, String tag) async {
    final key = '$base@$tag';
    final cached = _tables[key];
    if (cached != null) {
      final fetchedAt = _latestFetchedAt[base];
      final stale = tag == 'latest' &&
          (fetchedAt == null ||
              DateTime.now().difference(fetchedAt) > _latestMaxAge);
      if (!stale) return cached;
    }

    final fetched = await _fetch(base, tag);
    if (fetched == null) return cached; // keep a stale in-memory table
    _tables[key] = fetched.rates;
    if (tag == 'latest') {
      _latestFetchedAt[base] = DateTime.now();
      await _storeLatest(base, fetched);
    }
    return fetched.rates;
  }

  Future<_FetchedTable?> _fetch(String base, String tag) async {
    final urls = [
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@$tag/v1/currencies/$base.min.json',
      'https://$tag.currency-api.pages.dev/v1/currencies/$base.min.json',
    ];
    for (final url in urls) {
      final json = await _getJson(url);
      final rates = json?[base];
      if (rates is Map) {
        return _FetchedTable(
          json!['date'] as String? ?? tag,
          _toRates(rates, lowercase: false),
        );
      }
    }

    if (tag == 'latest') {
      final json = await _getJson(
        'https://open.er-api.com/v6/latest/${base.toUpperCase()}',
      );
      final rates = json?['rates'];
      if (json?['result'] == 'success' && rates is Map) {
        final now = DateTime.now().toUtc();
        final date =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        return _FetchedTable(date, _toRates(rates, lowercase: true));
      }
    }
    return null;
  }

  Map<String, double> _toRates(Map raw, {required bool lowercase}) {
    final out = <String, double>{};
    raw.forEach((k, v) {
      if (k is String && v is num) {
        out[lowercase ? k.toLowerCase() : k] = v.toDouble();
      }
    });
    return out;
  }

  Future<Map<String, dynamic>?> _getJson(String url) async {
    try {
      final res = await _client.get(Uri.parse(url)).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('Rate fetch failed ($url): $e');
      return null;
    }
  }

  Future<void> _storeLatest(String base, _FetchedTable table) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefsKey(base),
        jsonEncode({'date': table.date, 'rates': table.rates}),
      );
    } catch (e) {
      debugPrint('Could not cache rates: $e');
    }
  }

  Future<Map<String, double>?> _cachedLatest(String base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // The Android wallet service may have written a newer table.
      await prefs.reload();
      final raw = prefs.getString(prefsKey(base));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      final rates = decoded is Map ? decoded['rates'] : null;
      return rates is Map ? _toRates(rates, lowercase: false) : null;
    } catch (e) {
      debugPrint('Could not read cached rates: $e');
      return null;
    }
  }
}

class _FetchedTable {
  final String date;
  final Map<String, double> rates;
  const _FetchedTable(this.date, this.rates);
}
