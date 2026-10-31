import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:expenses_tracker/models/balance_reset.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/services/balance_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx(double amount, DateTime date) =>
    Transaction(title: 't', amount: amount, date: date);

void main() {
  final before = DateTime(2026, 4, 10);
  final resetAt = DateTime(2026, 10, 31, 20, 0);
  final after = DateTime(2026, 10, 31, 21, 0);

  group('BalanceCalculator.balance', () {
    test('without a reset counts everything', () {
      final balance = BalanceCalculator.balance(
        incomes: [_tx(1000, before)],
        expenses: [_tx(300, before)],
        sharedExpenses: [_tx(50, before)],
        savings: [_tx(100, before)],
      );
      expect(balance, 550);
    });

    test('with a reset starts from its amount and ignores older entries', () {
      final reset = BalanceReset(
        target: ResetTarget.balance,
        date: resetAt,
        amount: 200,
        previousAmount: -4700,
      );
      final balance = BalanceCalculator.balance(
        incomes: [_tx(1000, before), _tx(80, after)],
        expenses: [_tx(5700, before), _tx(30, after)],
        sharedExpenses: [_tx(20, before), _tx(10, after)],
        savings: [_tx(100, before), _tx(15, after)],
        reset: reset,
      );
      // 200 + 80 − 30 − 10 − 15
      expect(balance, 225);
    });

    test('reset to zero with nothing after it shows zero', () {
      final reset = BalanceReset(
        target: ResetTarget.balance,
        date: resetAt,
        amount: 0,
        previousAmount: -4700,
      );
      final balance = BalanceCalculator.balance(
        incomes: const [],
        expenses: [_tx(4700, before)],
        sharedExpenses: const [],
        savings: const [],
        reset: reset,
      );
      expect(balance, 0);
    });
  });

  group('BalanceCalculator.savings', () {
    test('with a reset adds only later deposits', () {
      final reset = BalanceReset(
        target: ResetTarget.savings,
        date: resetAt,
        amount: 500,
        previousAmount: 1200,
      );
      final total = BalanceCalculator.savings(
        savings: [_tx(1200, before), _tx(50, after)],
        reset: reset,
      );
      expect(total, 550);
    });
  });

  group('BalanceCalculator.latestReset', () {
    test('picks the newest reset for the requested target only', () {
      final older = BalanceReset(
        target: ResetTarget.balance,
        date: before,
        amount: 0,
        previousAmount: 0,
      );
      final newer = BalanceReset(
        target: ResetTarget.balance,
        date: resetAt,
        amount: 0,
        previousAmount: 0,
      );
      final savings = BalanceReset(
        target: ResetTarget.savings,
        date: after,
        amount: 0,
        previousAmount: 0,
      );

      final resets = [older, savings, newer];
      expect(BalanceCalculator.latestReset(resets, ResetTarget.balance), newer);
      expect(
        BalanceCalculator.latestReset(resets, ResetTarget.savings),
        savings,
      );
      expect(
        BalanceCalculator.latestReset(const [], ResetTarget.balance),
        isNull,
      );
    });
  });

  group('BalanceReset serialization', () {
    test('round-trips through toMap/fromMap', () {
      final reset = BalanceReset(
        id: 'r1',
        target: ResetTarget.savings,
        date: resetAt,
        amount: 12.5,
        previousAmount: -3,
      );
      final restored = BalanceReset.fromMap(reset.toMap())!;
      expect(restored.id, 'r1');
      expect(restored.target, ResetTarget.savings);
      expect(restored.date, resetAt);
      expect(restored.amount, 12.5);
      expect(restored.previousAmount, -3);
    });

    test('returns null for malformed documents', () {
      expect(BalanceReset.fromMap({'target': 'nope'}), isNull);
      expect(
        BalanceReset.fromMap({
          'target': 'balance',
          'date': Timestamp.fromDate(resetAt),
        }),
        isNull,
      );
    });
  });
}
