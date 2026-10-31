import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Which running total a [BalanceReset] applies to.
enum ResetTarget { balance, savings }

/// A non-destructive reset point for the balance or the savings total.
///
/// Transactions are never deleted. From [date] onward the total is calculated
/// as [amount] plus every transaction dated after [date]. Older transactions
/// remain visible in the lists, History and Analytics.
class BalanceReset {
  final String id;
  final ResetTarget target;
  final DateTime date;

  /// The value the total was set to at [date].
  final double amount;

  /// The value the total showed right before the reset (shown in History).
  final double previousAmount;

  BalanceReset({
    String? id,
    required this.target,
    required this.date,
    required this.amount,
    required this.previousAmount,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'target': target.name,
    'date': Timestamp.fromDate(date),
    'amount': amount,
    'previousAmount': previousAmount,
  };

  /// Returns null for malformed documents so a bad record never breaks totals.
  static BalanceReset? fromMap(Map<String, dynamic> map) {
    final target =
        ResetTarget.values.where((t) => t.name == map['target']).firstOrNull;
    final date = map['date'];
    final amount = map['amount'];
    if (target == null || date is! Timestamp || amount is! num) return null;

    return BalanceReset(
      id: map['id'] as String? ?? '',
      target: target,
      date: date.toDate(),
      amount: amount.toDouble(),
      previousAmount: (map['previousAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
