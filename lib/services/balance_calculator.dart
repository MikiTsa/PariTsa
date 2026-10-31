import 'package:expenses_tracker/models/balance_reset.dart';
import 'package:expenses_tracker/models/transaction.dart';

/// Live totals the Home screen hands to Settings → Reset.
typedef BalanceTotals =
    ({double balance, double savings, List<BalanceReset> resets});

/// Pure functions for the balance box totals, kept separate from widgets so
/// the reset logic can be unit-tested.
abstract final class BalanceCalculator {
  /// The most recent reset for [target], or null if there is none.
  static BalanceReset? latestReset(
    Iterable<BalanceReset> resets,
    ResetTarget target,
  ) {
    BalanceReset? latest;
    for (final r in resets) {
      if (r.target != target) continue;
      if (latest == null || r.date.isAfter(latest.date)) latest = r;
    }
    return latest;
  }

  /// income − expenses − shared splits − savings, counting only transactions
  /// dated after [reset] (if any) on top of the reset's starting amount.
  static double balance({
    required Iterable<Transaction> incomes,
    required Iterable<Transaction> expenses,
    required Iterable<Transaction> sharedExpenses,
    required Iterable<Transaction> savings,
    BalanceReset? reset,
  }) {
    return (reset?.amount ?? 0) +
        _sumAfter(incomes, reset) -
        _sumAfter(expenses, reset) -
        _sumAfter(sharedExpenses, reset) -
        _sumAfter(savings, reset);
  }

  /// Total savings, counting only deposits dated after [reset] (if any) on
  /// top of the reset's starting amount.
  static double savings({
    required Iterable<Transaction> savings,
    BalanceReset? reset,
  }) {
    return (reset?.amount ?? 0) + _sumAfter(savings, reset);
  }

  static double _sumAfter(Iterable<Transaction> list, BalanceReset? reset) {
    double sum = 0;
    for (final t in list) {
      if (reset == null || t.date.isAfter(reset.date)) sum += t.amount;
    }
    return sum;
  }
}
