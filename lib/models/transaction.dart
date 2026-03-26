import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

// Enum to represent transaction types
enum TransactionType { expense, income, saving }

// Transaction model for all financial entries
class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String? category;
  final String? note;
  final String? tag;

  Transaction({
    String? id,
    required this.title,
    required this.amount,
    required this.date,
    this.category,
    this.note,
    this.tag,
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
    );
  }

  // Create Transaction from Firestore DocumentSnapshot
  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Transaction.fromMap(data);
  }
}
