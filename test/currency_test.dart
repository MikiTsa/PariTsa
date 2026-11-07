import 'dart:convert';

import 'package:expenses_tracker/models/currency.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/services/exchange_rate_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('currency helpers', () {
    test('roundMoney rounds to cents and never returns 0 for positives', () {
      expect(roundMoney(89.9049), 89.90);
      expect(roundMoney(0.0004), 0.01);
      expect(roundMoney(-3.456), -3.46);
    });

    test('formatting', () {
      expect(formatWithCode(5529, 'MKD'), 'MKD 5,529.00');
      expect(formatRate(61.4, base: 'EUR', foreign: 'MKD'), '1 EUR = 61.40 MKD');
      expect(formatRate(0.0163, base: 'MKD', foreign: 'EUR'), '1 MKD = 0.0163 EUR');
    });

    test('catalogue lookups', () {
      expect(currencySymbol('MKD'), 'ден');
      expect(currencySymbol('EUR'), '€');
      expect(currencySymbol('XYZ'), 'XYZ');
      expect(kCurrencies.map((c) => c.code).toSet().length, kCurrencies.length);
    });
  });

  group('Transaction currency conversion', () {
    final date = DateTime(2026, 4, 5, 23, 39);

    test('withForeignAmount converts and keeps what was paid', () {
      final t = Transaction(title: 'Wizz Air', amount: 5.52, date: date)
          .withForeignAmount(foreignAmount: 5529, currency: 'MKD', rate: 61.5);

      expect(t.amount, 89.90);
      expect(t.originalAmount, 5529);
      expect(t.originalCurrency, 'MKD');
      expect(t.exchangeRate, 61.5);
      expect(t.rateEstimated, isFalse);
      expect(t.isForeign, isTrue);
    });

    test('foreign fields survive toMap/fromMap', () {
      final t = Transaction(id: 'x', title: 'Taxi', amount: 1, date: date)
          .withForeignAmount(
            foreignAmount: 300,
            currency: 'MKD',
            rate: 61.5,
            estimated: true,
          );
      final restored = Transaction.fromMap(t.toMap());

      expect(restored.amount, t.amount);
      expect(restored.originalAmount, 300);
      expect(restored.originalCurrency, 'MKD');
      expect(restored.exchangeRate, 61.5);
      expect(restored.rateEstimated, isTrue);
    });

    test('plain transactions write no currency fields', () {
      final map = Transaction(title: 'Lidl', amount: 52.43, date: date).toMap();
      expect(map.containsKey('originalAmount'), isFalse);
      expect(map.containsKey('originalCurrency'), isFalse);
      expect(map.containsKey('exchangeRate'), isFalse);
      expect(map.containsKey('rateEstimated'), isFalse);
    });

    test('rebasedTo multiplies plain amounts by the factor', () {
      final t = Transaction(title: 'Lidl', amount: 10, date: date);
      final r = t.rebasedTo('MKD', 61.4);
      expect(r.amount, 614.0);
      expect(r.isForeign, isFalse);
    });

    test('rebasedTo restores the exact amount when paid in the new base', () {
      final t = Transaction(title: 'Wizz Air', amount: 1, date: date)
          .withForeignAmount(foreignAmount: 5529, currency: 'MKD', rate: 61.5);
      final r = t.rebasedTo('MKD', 61.4);

      expect(r.amount, 5529);
      expect(r.isForeign, isFalse);
      expect(r.exchangeRate, isNull);
    });

    test('rebasedTo keeps other foreign payments consistent', () {
      // Paid 100 USD when 1 EUR = 1.10 USD → €90.91. Switch default to MKD.
      final t = Transaction(title: 'Hotel', amount: 1, date: date)
          .withForeignAmount(foreignAmount: 100, currency: 'USD', rate: 1.10);
      final r = t.rebasedTo('MKD', 61.4);

      expect(r.originalAmount, 100);
      expect(r.originalCurrency, 'USD');
      // New rate is USD per MKD: 1.10 / 61.4
      expect(r.exchangeRate, closeTo(1.10 / 61.4, 1e-12));
      expect(r.amount, roundMoney(90.91 * 61.4));
    });
  });

  group('ExchangeRateService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    String table(String base, Map<String, double> rates, {String date = '2026-10-31'}) =>
        jsonEncode({'date': date, base: rates});

    test('quotes from the primary source and caches the latest table', () async {
      var calls = 0;
      final service = ExchangeRateService(
        client: MockClient((req) async {
          calls++;
          expect(req.url.toString(), contains('@latest/v1/currencies/eur.min.json'));
          return http.Response(table('eur', {'mkd': 61.4, 'usd': 1.1}), 200);
        }),
      );

      final q = await service.quote(from: 'MKD', to: 'EUR');
      expect(q!.rate, 61.4);
      expect(q.estimated, isFalse);

      await service.quote(from: 'USD', to: 'EUR');
      expect(calls, 1, reason: 'second quote served from memory');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ExchangeRateService.prefsKey('EUR')), contains('"mkd":61.4'));
    });

    test('uses the dated table for past transactions', () async {
      final service = ExchangeRateService(
        client: MockClient((req) async {
          expect(req.url.toString(), contains('@2026-04-05/'));
          return http.Response(table('eur', {'mkd': 61.54}, date: '2026-04-05'), 200);
        }),
      );
      final q = await service.quote(from: 'MKD', to: 'EUR', date: DateTime(2026, 4, 5, 23));
      expect(q!.rate, 61.54);
    });

    test('falls back to the mirror, then open.er-api', () async {
      final service = ExchangeRateService(
        client: MockClient((req) async {
          if (req.url.host == 'open.er-api.com') {
            return http.Response(
              jsonEncode({'result': 'success', 'rates': {'MKD': 61.5}}),
              200,
            );
          }
          return http.Response('down', 503);
        }),
      );
      final q = await service.quote(from: 'MKD', to: 'EUR');
      expect(q!.rate, 61.5);
    });

    test('offline: uses the cached table and marks it estimated', () async {
      SharedPreferences.setMockInitialValues({
        ExchangeRateService.prefsKey('EUR'):
            jsonEncode({'date': '2026-10-30', 'rates': {'mkd': 61.3}}),
      });
      final service = ExchangeRateService(
        client: MockClient((_) async => throw Exception('offline')),
      );

      final q = await service.quote(from: 'MKD', to: 'EUR');
      expect(q!.rate, 61.3);
      expect(q.estimated, isTrue);

      final strict = await service.quote(from: 'MKD', to: 'EUR', allowCached: false);
      expect(strict, isNull);
    });

    test('same currency needs no lookup; unknown currency returns null', () async {
      final service = ExchangeRateService(
        client: MockClient((_) async => http.Response(table('eur', {'mkd': 61.4}), 200)),
      );
      expect((await service.quote(from: 'EUR', to: 'EUR'))!.rate, 1);
      expect(await service.quote(from: 'XYZ', to: 'EUR'), isNull);
    });
  });
}
