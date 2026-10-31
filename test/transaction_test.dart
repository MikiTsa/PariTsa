import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:expenses_tracker/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Transaction', () {
    test('toMap omits null optional fields', () {
      final t = Transaction(
        title: 'Lidl',
        amount: 12.5,
        date: DateTime(2026, 4, 1),
      );

      final map = t.toMap();

      expect(map.keys, containsAll(['id', 'title', 'amount', 'date']));
      expect(map.containsKey('category'), isFalse);
      expect(map.containsKey('note'), isFalse);
      expect(map.containsKey('tag'), isFalse);
    });

    test('toMap never persists sharedTrackerId', () {
      final t = Transaction(
        title: 'Dinner',
        amount: 20,
        date: DateTime(2026, 4, 1),
        sharedTrackerId: 'tracker-1',
      );

      expect(t.isShared, isTrue);
      expect(t.toMap().containsKey('sharedTrackerId'), isFalse);
    });

    test('toMap and fromMap round-trip all fields', () {
      final original = Transaction(
        id: 'abc',
        title: 'Salary',
        amount: 1500.75,
        date: DateTime(2026, 3, 31, 9, 30),
        category: 'Salary',
        note: 'March',
        tag: 'Work',
      );

      final restored = Transaction.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.amount, original.amount);
      expect(restored.date, original.date);
      expect(restored.category, original.category);
      expect(restored.note, original.note);
      expect(restored.tag, original.tag);
    });

    test('fromMap falls back safely when fields are missing', () {
      final t = Transaction.fromMap(<String, dynamic>{});

      expect(t.id, '');
      expect(t.title, '');
      expect(t.amount, 0.0);
      expect(t.category, isNull);
    });

    test('fromMap accepts integer amounts', () {
      final t = Transaction.fromMap({
        'id': 'x',
        'title': 'Gift',
        'amount': 50,
        'date': Timestamp.fromDate(DateTime(2026, 1, 1)),
      });

      expect(t.amount, 50.0);
    });

    test('copyWith keeps id and sharedTrackerId', () {
      final t = Transaction(
        id: 'keep-me',
        title: 'Coffee',
        amount: 3,
        date: DateTime(2026, 4, 1),
        sharedTrackerId: 'tracker-1',
      );

      final copy = t.copyWith(amount: 4);

      expect(copy.id, 'keep-me');
      expect(copy.sharedTrackerId, 'tracker-1');
      expect(copy.amount, 4);
      expect(copy.title, 'Coffee');
    });
  });
}
