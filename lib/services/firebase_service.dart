import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:expenses_tracker/models/shared_tracker.dart';
import 'package:expenses_tracker/models/transaction.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Firestore collection name constants — single source of truth used by
// both FirebaseService and AuthService.
const kUsersCollection          = 'users';
const kExpensesCollection       = 'expenses';
const kIncomesCollection        = 'incomes';
const kSavingsCollection        = 'savings';
const kCategoriesCollection     = 'categories';
const kSharedTrackersCollection = 'sharedTrackers';
const kSharedTxCollection       = 'transactions';
const kInviteCodesCollection    = 'inviteCodes';

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

  // Get current user ID (public for HomeScreen nested-stream logic)
  String? get currentUserId => _auth.currentUser?.uid;
  String? get _currentUserId => currentUserId;

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

  // ── Shared Trackers ───────────────────────────────────────────────────────

  /// Creates a new shared tracker, writes an invite-code index document,
  /// and returns the resulting [SharedTracker].
  Future<SharedTracker> createSharedTracker(String name) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final user = _auth.currentUser!;
    final displayName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : (user.email ?? 'Unknown');

    final inviteCode = SharedTracker.generateInviteCode();
    final creator = TrackerMember(
      uid: uid,
      displayName: displayName,
      colorValue: AppColors.sharedMemberColors[0].toARGB32(),
    );
    final tracker = SharedTracker(
      name: name,
      createdAt: DateTime.now(),
      createdBy: uid,
      inviteCode: inviteCode,
      members: [creator],
      memberIds: [uid],
    );

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(kSharedTrackersCollection).doc(tracker.id),
      tracker.toMap(),
    );
    batch.set(
      _firestore.collection(kInviteCodesCollection).doc(inviteCode),
      {'trackerId': tracker.id, 'createdBy': uid},
    );
    await batch.commit();

    return tracker;
  }

  /// Real-time stream of all shared trackers the current user is a member of.
  Stream<List<SharedTracker>> getSharedTrackersStream() {
    final uid = _currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection(kSharedTrackersCollection)
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SharedTracker.fromFirestore(d)).toList());
  }

  /// Looks up [code] in the invite-code index, then adds the current user
  /// to the matching tracker's members list.
  ///
  /// Uses FieldValue.arrayUnion so no tracker read is required before
  /// updating — this avoids a read-permission catch-22 for first-time joiners.
  /// After the join the user is a member and can read the tracker normally.
  Future<SharedTracker> joinSharedTrackerByCode(String code) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    // Step 1: read the invite-code index (any authenticated user may read).
    final inviteDoc = await _firestore
        .collection(kInviteCodesCollection)
        .doc(code.toUpperCase().trim())
        .get();
    if (!inviteDoc.exists) throw Exception('Invalid invite code');

    final trackerId = inviteDoc.data()!['trackerId'] as String;

    // Step 2: build the new member without reading the tracker first.
    // Color is derived from the uid so it stays stable across devices.
    final user = _auth.currentUser!;
    final displayName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : (user.email ?? 'Unknown');
    final colorIndex =
        uid.hashCode.abs() % AppColors.sharedMemberColors.length;
    final newMember = TrackerMember(
      uid: uid,
      displayName: displayName,
      colorValue: AppColors.sharedMemberColors[colorIndex].toARGB32(),
    );

    // Step 3: join via arrayUnion — the isJoiningTracker() rule validates
    // server-side that the uid is not already a member.
    await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .update({
      'members': FieldValue.arrayUnion([newMember.toMap()]),
      'memberIds': FieldValue.arrayUnion([uid]),
    });

    // Step 4: now that we're a member the read is allowed.
    final trackerDoc = await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .get();
    if (!trackerDoc.exists) throw Exception('Tracker not found');
    return SharedTracker.fromFirestore(trackerDoc);
  }

  /// Removes the current user from a shared tracker.
  /// The tracker creator cannot leave — they must delete instead.
  Future<void> leaveSharedTracker(String trackerId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final doc = await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .get();
    if (!doc.exists) throw Exception('Tracker not found');

    final tracker = SharedTracker.fromFirestore(doc);
    if (tracker.createdBy == uid) {
      throw Exception(
          'You created this tracker. Delete it instead of leaving.');
    }

    await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .update({
      'members': tracker.members
          .where((m) => m.uid != uid)
          .map((m) => m.toMap())
          .toList(),
      'memberIds': tracker.memberIds.where((id) => id != uid).toList(),
    });
  }

  /// Deletes a shared tracker and its invite-code index document.
  /// Only the tracker creator may call this.
  Future<void> deleteSharedTracker(String trackerId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final doc = await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .get();
    if (!doc.exists) throw Exception('Tracker not found');

    final tracker = SharedTracker.fromFirestore(doc);
    if (tracker.createdBy != uid) {
      throw Exception('Only the creator can delete this tracker');
    }

    final batch = _firestore.batch();
    batch.delete(
        _firestore.collection(kInviteCodesCollection).doc(tracker.inviteCode));
    batch.delete(
        _firestore.collection(kSharedTrackersCollection).doc(trackerId));
    await batch.commit();
  }

  /// Renames a shared tracker. Any member may rename.
  Future<void> renameSharedTracker(String trackerId, String newName) async {
    if (_currentUserId == null) throw Exception('Not authenticated');
    await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .update({'name': newName});
  }

  // ── Shared Transactions ───────────────────────────────────────────────────

  Stream<List<SharedTransaction>> getSharedTransactionsStream(
      String trackerId) {
    return _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .collection(kSharedTxCollection)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SharedTransaction.fromMap(d.data()))
            .toList());
  }

  Future<void> addSharedTransaction(
      String trackerId, SharedTransaction tx) async {
    await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .collection(kSharedTxCollection)
        .doc(tx.id)
        .set(tx.toMap());
  }

  Future<void> updateSharedTransaction(
      String trackerId, SharedTransaction tx) async {
    await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .collection(kSharedTxCollection)
        .doc(tx.id)
        .set(tx.toMap());
  }

  Future<void> deleteSharedTransaction(
      String trackerId, String txId) async {
    await _firestore
        .collection(kSharedTrackersCollection)
        .doc(trackerId)
        .collection(kSharedTxCollection)
        .doc(txId)
        .delete();
  }

  /// Returns a stream of the current user's shared expenses across ALL their
  /// shared trackers, projected as [Transaction] objects (with [sharedTrackerId]
  /// set and [amount] = the user's split portion).
  ///
  /// Internally manages nested subscriptions: one for the tracker list and one
  /// per tracker's transactions subcollection. All are cleaned up on cancel.
  Stream<List<Transaction>> getMySharedExpensesStream() {
    final uid = _currentUserId;
    if (uid == null) return Stream.value([]);

    // ignore: close_sinks — closed via onCancel
    final controller = StreamController<List<Transaction>>.broadcast();

    final Map<String, StreamSubscription<dynamic>> txSubs = {};
    final Map<String, List<Transaction>> txData = {};
    StreamSubscription<dynamic>? trackersSub;

    trackersSub = _firestore
        .collection(kSharedTrackersCollection)
        .where('memberIds', arrayContains: uid)
        .snapshots()
        .listen(
      (snap) {
        final currentIds = snap.docs.map((d) => d.id).toSet();

        // Cancel subscriptions for trackers we're no longer in
        for (final id
            in txSubs.keys.where((k) => !currentIds.contains(k)).toList()) {
          txSubs[id]?.cancel();
          txSubs.remove(id);
          txData.remove(id);
        }

        // Subscribe to transactions in newly joined trackers
        for (final trackerDoc in snap.docs) {
          final trackerId = trackerDoc.id;
          if (txSubs.containsKey(trackerId)) continue;

          txSubs[trackerId] = _firestore
              .collection(kSharedTrackersCollection)
              .doc(trackerId)
              .collection(kSharedTxCollection)
              .snapshots()
              .listen((txSnap) {
            txData[trackerId] = txSnap.docs
                .map((d) => SharedTransaction.fromMap(d.data()))
                .where((tx) => tx.splits.any((s) => s.uid == uid))
                .map((tx) {
                  final split = tx.splits.firstWhere((s) => s.uid == uid);
                  return Transaction(
                    id: tx.id,
                    title: tx.title,
                    amount: split.amount,
                    date: tx.date,
                    category: tx.category,
                    note: tx.note,
                    tag: tx.tag,
                    sharedTrackerId: trackerId,
                  );
                })
                .toList();

            if (!controller.isClosed) {
              controller.add(txData.values.expand((l) => l).toList());
            }
          });
        }

        if (currentIds.isEmpty && !controller.isClosed) {
          controller.add([]);
        }
      },
      onError: (Object e) => debugPrint('Shared expenses stream error: $e'),
    );

    controller.onCancel = () {
      trackersSub?.cancel();
      for (final sub in txSubs.values) {
        sub.cancel();
      }
    };

    return controller.stream;
  }
}
