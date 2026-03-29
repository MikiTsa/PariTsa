import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:expenses_tracker/models/transaction.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Firestore collection name constants — single source of truth used by
// both FirebaseService and AuthService.
const kUsersCollection      = 'users';
const kExpensesCollection   = 'expenses';
const kIncomesCollection    = 'incomes';
const kSavingsCollection    = 'savings';
const kCategoriesCollection = 'categories';

// Default categories per transaction type
const _kDefaultExpenseCategories = [
  'Food', 'Transport', 'Groceries', 'Fixed Expenses',
  'Entertainment', 'Gifts', 'Shopping', 'Other',
];
const _kDefaultIncomeCategories = [
  'Salary', 'Parents', 'Gift', 'Investment', 'Other',
];
const _kDefaultSavingCategories = [
  'Emergency Fund', 'Education', 'Vacation', 'Gifts', 'Home', 'Other',
];

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Collection references for each transaction type (USER-SPECIFIC)
  CollectionReference? get expensesCollection {
    if (_currentUserId == null) return null;
    return _firestore
        .collection(kUsersCollection)
        .doc(_currentUserId)
        .collection(kExpensesCollection);
  }

  CollectionReference? get incomesCollection {
    if (_currentUserId == null) return null;
    return _firestore
        .collection(kUsersCollection)
        .doc(_currentUserId)
        .collection(kIncomesCollection);
  }

  CollectionReference? get savingsCollection {
    if (_currentUserId == null) return null;
    return _firestore
        .collection(kUsersCollection)
        .doc(_currentUserId)
        .collection(kSavingsCollection);
  }

  // Get the correct collection based on transaction type
  CollectionReference? _getCollection(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return expensesCollection;
      case TransactionType.income:
        return incomesCollection;
      case TransactionType.saving:
        return savingsCollection;
    }
  }

  // Add a new transaction
  Future<void> addTransaction(
    Transaction transaction,
    TransactionType type,
  ) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final collection = _getCollection(type);
      if (collection == null) {
        throw Exception('Failed to get collection');
      }

      await collection.doc(transaction.id).set(transaction.toMap());
    } catch (e) {
      debugPrint('Error adding transaction: $e');
      rethrow;
    }
  }

  // Update an existing transaction
  Future<void> updateTransaction(
    Transaction transaction,
    TransactionType type,
  ) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final collection = _getCollection(type);
      if (collection == null) {
        throw Exception('Failed to get collection');
      }

      await collection.doc(transaction.id).set(transaction.toMap());
    } catch (e) {
      debugPrint('Error updating transaction: $e');
      rethrow;
    }
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id, TransactionType type) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final collection = _getCollection(type);
      if (collection == null) {
        throw Exception('Failed to get collection');
      }

      await collection.doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }

  // Get all transactions of a specific type as a stream
  Stream<List<Transaction>> getTransactionsStream(TransactionType type) {
    if (_currentUserId == null) {
      return Stream.value([]); // Return empty stream if not authenticated
    }

    final collection = _getCollection(type);
    if (collection == null) {
      return Stream.value([]);
    }

    return collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Transaction.fromFirestore(doc))
          .toList();
    });
  }

  // ── Categories ────────────────────────────────────────────────────────────

  DocumentReference? _categoriesDoc(TransactionType type) {
    if (_currentUserId == null) return null;
    final docId = switch (type) {
      TransactionType.expense => 'expenses',
      TransactionType.income  => 'incomes',
      TransactionType.saving  => 'savings',
    };
    return _firestore
        .collection(kUsersCollection)
        .doc(_currentUserId)
        .collection(kCategoriesCollection)
        .doc(docId);
  }

  List<String> _defaultCategories(TransactionType type) => switch (type) {
    TransactionType.expense => List.from(_kDefaultExpenseCategories),
    TransactionType.income  => List.from(_kDefaultIncomeCategories),
    TransactionType.saving  => List.from(_kDefaultSavingCategories),
  };

  List<String> _parseCategories(DocumentSnapshot snapshot, TransactionType type) {
    if (!snapshot.exists) return _defaultCategories(type);
    final data = snapshot.data() as Map<String, dynamic>?;
    final items = data?['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return _defaultCategories(type);
    return items.cast<String>();
  }

  Stream<List<String>> getCategoriesStream(TransactionType type) {
    final doc = _categoriesDoc(type);
    if (doc == null) return Stream.value(_defaultCategories(type));
    return doc.snapshots().map((s) => _parseCategories(s, type));
  }

  Future<List<String>> getCategories(TransactionType type) async {
    final doc = _categoriesDoc(type);
    if (doc == null) return _defaultCategories(type);
    return _parseCategories(await doc.get(), type);
  }

  Future<void> addCategory(String name, TransactionType type) async {
    if (_currentUserId == null) return;
    final current = await getCategories(type);
    if (current.contains(name)) return;
    await _categoriesDoc(type)!.set({'items': [...current, name]});
  }

  Future<void> deleteCategory(String name, TransactionType type) async {
    if (_currentUserId == null) return;
    final current = await getCategories(type);
    await _categoriesDoc(type)!.set({
      'items': current.where((c) => c != name).toList(),
    });
  }

  Future<void> insertCategoryAt(
    String name,
    TransactionType type,
    int index,
  ) async {
    if (_currentUserId == null) return;
    final current = await getCategories(type);
    if (current.contains(name)) return;
    final updated = List<String>.from(current)
      ..insert(index.clamp(0, current.length), name);
    await _categoriesDoc(type)!.set({'items': updated});
  }

  Future<void> reorderCategories(
    List<String> reorderedList,
    TransactionType type,
  ) async {
    if (_currentUserId == null) return;
    await _categoriesDoc(type)!.set({'items': reorderedList});
  }

  // Get all unique tags used across all transaction types, sorted alphabetically
  Future<List<String>> getUsedTags() async {
    if (_currentUserId == null) return [];
    final results = await Future.wait([
      getTransactions(TransactionType.expense),
      getTransactions(TransactionType.income),
      getTransactions(TransactionType.saving),
    ]);
    final tags = <String>{};
    for (final list in results) {
      for (final t in list) {
        if (t.tag != null && t.tag!.isNotEmpty) tags.add(t.tag!);
      }
    }
    return tags.toList()..sort();
  }

  // Get all transactions of a specific type (one-time fetch)
  Future<List<Transaction>> getTransactions(TransactionType type) async {
    try {
      if (_currentUserId == null) {
        return [];
      }

      final collection = _getCollection(type);
      if (collection == null) {
        return [];
      }

      final snapshot = await collection.get();
      return snapshot.docs
          .map((doc) => Transaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting transactions: $e');
      return [];
    }
  }
}
