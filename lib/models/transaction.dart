import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:expenses_tracker/models/currency.dart';

// Enum to represent transaction types
enum TransactionType { expense, income, saving }

/// "MKD 5,529.00 · 1 EUR = 61.40 MKD" — the "Paid in" line on detail sheets.
String originalAmountDetail(Transaction t, String baseCurrency) {
  final paid = formatWithCode(t.originalAmount!, t.originalCurrency!);
  final rate = t.exchangeRate;
  if (rate == null) return '$paid · rate pending';
  final rateText =
      formatRate(rate, base: baseCurrency, foreign: t.originalCurrency!);
  return '$paid · $rateText${t.rateEstimated ? ' (estimate)' : ''}';
}

// Transaction model for all financial entries
class Transaction {
  final String id;
  final String title;

  /// Always in the user's default currency — every total (balance, savings,
  /// analytics) sums this field directly.
  final double amount;
  final DateTime date;
  final String? category;
  final String? note;
  final String? tag;
  // Non-null when this entry is derived from a shared tracker (Option B).
  // The stored amount is only the current user's split portion.
  final String? sharedTrackerId;

  /// Set when the transaction was paid in another currency: what was actually
  /// paid, in which currency, and the rate used to get [amount].
  final double? originalAmount;
  final String? originalCurrency;

  /// Units of [originalCurrency] per 1 unit of the default currency
  /// (e.g. 61.40 for MKD when the default is EUR).
  final double? exchangeRate;

  /// True when the rate was a fallback (offline cache). The app re-converts
  /// these with the exact rate for [date] once it is online.
  final bool rateEstimated;

  bool get isShared => sharedTrackerId != null;
  bool get isForeign => originalAmount != null && originalCurrency != null;

  Transaction({
    String? id,
    required this.title,
    required this.amount,
    required this.date,
    this.category,
    this.note,
    this.tag,
    this.sharedTrackerId,
    this.originalAmount,
    this.originalCurrency,
    this.exchangeRate,
    this.rateEstimated = false,
  }) : id = id ?? const Uuid().v4();

  // Create a copy of the transaction with some modified fields
  Transaction copyWith({
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? note,
    String? tag,
  }) {
    return Transaction(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
      tag: tag ?? this.tag,
      sharedTrackerId: sharedTrackerId,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      exchangeRate: exchangeRate,
      rateEstimated: rateEstimated,
    );
  }

  /// This transaction re-expressed from a foreign amount: [amount] becomes
  /// [foreignAmount] / [rate], where [rate] is units of [currency] per 1 unit
  /// of the default currency.
  Transaction withForeignAmount({
    required double foreignAmount,
    required String currency,
    required double rate,
    bool estimated = false,
  }) {
    return Transaction(
      id: id,
      title: title,
      amount: roundMoney(foreignAmount / rate),
      date: date,
      category: category,
      note: note,
      tag: tag,
      sharedTrackerId: sharedTrackerId,
      originalAmount: foreignAmount,
      originalCurrency: currency,
      exchangeRate: rate,
      rateEstimated: estimated,
    );
  }

  /// This transaction after the default currency changes to [newBase].
  /// [factor] is units of [newBase] per 1 unit of the old default currency.
  ///
  /// If it was originally paid in [newBase], the exact original amount is
  /// restored and the foreign fields are dropped.
  Transaction rebasedTo(String newBase, double factor) {
    if (isForeign && originalCurrency == newBase) {
      return Transaction(
        id: id,
        title: title,
        amount: originalAmount!,
        date: date,
        category: category,
        note: note,
        tag: tag,
        sharedTrackerId: sharedTrackerId,
      );
    }
    return Transaction(
      id: id,
      title: title,
      amount: roundMoney(amount * factor),
      date: date,
      category: category,
      note: note,
      tag: tag,
      sharedTrackerId: sharedTrackerId,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
      exchangeRate: exchangeRate == null ? null : exchangeRate! / factor,
      rateEstimated: rateEstimated,
    );
  }

  // Convert Transaction to Map for Firestore.
  // Null optional fields are omitted so Firestore security rules
  // (which reject null values for typed fields) don't reject the write.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
    };
    if (category != null) map['category'] = category;
    if (note != null) map['note'] = note;
    if (tag != null) map['tag'] = tag;
    if (originalAmount != null) map['originalAmount'] = originalAmount;
    if (originalCurrency != null) map['originalCurrency'] = originalCurrency;
    if (exchangeRate != null) map['exchangeRate'] = exchangeRate;
    if (rateEstimated) map['rateEstimated'] = true;
    return map;
  }

  // Create Transaction from Firestore document with null-safe fallbacks.
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      category: map['category'] as String?,
      note: map['note'] as String?,
      tag: map['tag'] as String?,
      originalAmount: (map['originalAmount'] as num?)?.toDouble(),
      originalCurrency: map['originalCurrency'] as String?,
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble(),
      rateEstimated: map['rateEstimated'] == true,
    );
  }

  // Create Transaction from Firestore DocumentSnapshot
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Transaction.fromMap(data);
  }
}
