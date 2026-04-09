import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// ── TrackerMember ─────────────────────────────────────────────────────────────

class TrackerMember {
  final String uid;
  final String displayName;
  final int colorValue; // stored as int for Firestore; use .color getter for Color

  const TrackerMember({
    required this.uid,
    required this.displayName,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'colorValue': colorValue,
  };

  factory TrackerMember.fromMap(Map<String, dynamic> map) => TrackerMember(
    uid: map['uid'] as String? ?? '',
    displayName: map['displayName'] as String? ?? 'Unknown',
    colorValue: map['colorValue'] as int? ?? AppColors.sharedMemberColors[0].toARGB32(),
  );
}

// ── Split ─────────────────────────────────────────────────────────────────────

class Split {
  final String uid;
  final String displayName;
  final double amount;
  // Each member's personal analytics category — independent of the shared
  // transaction's display label. Null means fall back to tx.category.
  final String? myCategory;

  const Split({
    required this.uid,
    required this.displayName,
    required this.amount,
    this.myCategory,
  });

  double percentageOf(double total) =>
      total > 0 ? (amount / total) * 100 : 0;

  Split copyWith({double? amount, String? myCategory}) => Split(
    uid: uid,
    displayName: displayName,
    amount: amount ?? this.amount,
    myCategory: myCategory ?? this.myCategory,
  );

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'displayName': displayName,
      'amount': amount,
    };
    if (myCategory != null) map['myCategory'] = myCategory;
    return map;
  }

  factory Split.fromMap(Map<String, dynamic> map) => Split(
    uid: map['uid'] as String? ?? '',
    displayName: map['displayName'] as String? ?? 'Unknown',
    amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    myCategory: map['myCategory'] as String?,
  );
}

// ── SharedTransaction ─────────────────────────────────────────────────────────

class SharedTransaction {
  final String id;
  final String title;
  final double totalAmount;
  final DateTime date;
  final String? category;
  final String? note;
  final String? tag;
  final List<Split> splits;
  // UID of the member who originally created this transaction.
  // Used by the Cloud Function to exclude the sender from FCM recipients.
  final String? createdByUid;

  SharedTransaction({
    String? id,
    required this.title,
    required this.totalAmount,
    required this.date,
    required this.splits,
    this.category,
    this.note,
    this.tag,
    this.createdByUid,
  }) : id = id ?? const Uuid().v4();

  /// Returns the split for [uid], or null if this user has no split entry.
  Split? splitFor(String uid) {
    try {
      return splits.firstWhere((s) => s.uid == uid);
    } catch (_) {
      return null;
    }
  }

  SharedTransaction copyWith({
    String? title,
    double? totalAmount,
    DateTime? date,
    List<Split>? splits,
    String? category,
    String? note,
    String? tag,
    String? createdByUid,
  }) {
    return SharedTransaction(
      id: id,
      title: title ?? this.title,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      splits: splits ?? this.splits,
      category: category ?? this.category,
      note: note ?? this.note,
      tag: tag ?? this.tag,
      createdByUid: createdByUid ?? this.createdByUid,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'totalAmount': totalAmount,
      'date': Timestamp.fromDate(date),
      'splits': splits.map((s) => s.toMap()).toList(),
    };
    if (category != null) map['category'] = category;
    if (note != null) map['note'] = note;
    if (tag != null) map['tag'] = tag;
    if (createdByUid != null) map['createdByUid'] = createdByUid;
    return map;
  }

  factory SharedTransaction.fromMap(Map<String, dynamic> map) {
    final rawSplits = map['splits'] as List<dynamic>? ?? [];
    return SharedTransaction(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      splits: rawSplits
          .map((s) => Split.fromMap(s as Map<String, dynamic>))
          .toList(),
      category: map['category'] as String?,
      note: map['note'] as String?,
      tag: map['tag'] as String?,
      createdByUid: map['createdByUid'] as String?,
    );
  }
}

// ── SharedTracker ─────────────────────────────────────────────────────────────

class SharedTracker {
  final String id;
  final String name;
  final DateTime createdAt;
  final String createdBy;
  final String inviteCode;
  final List<TrackerMember> members;
  final List<String> memberIds; // flat list for Firestore array-contains queries
  final List<String> categories; // shared vocabulary for all members

  SharedTracker({
    String? id,
    required this.name,
    required this.createdAt,
    required this.createdBy,
    required this.inviteCode,
    required this.members,
    required this.memberIds,
    this.categories = const [],
  }) : id = id ?? const Uuid().v4();

  /// Returns the [TrackerMember] for [uid], or null if not found.
  TrackerMember? memberFor(String uid) {
    try {
      return members.firstWhere((m) => m.uid == uid);
    } catch (_) {
      return null;
    }
  }

  SharedTracker copyWith({
    String? name,
    List<TrackerMember>? members,
    List<String>? memberIds,
    List<String>? categories,
  }) {
    return SharedTracker(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      createdBy: createdBy,
      inviteCode: inviteCode,
      members: members ?? this.members,
      memberIds: memberIds ?? this.memberIds,
      categories: categories ?? this.categories,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'createdAt': Timestamp.fromDate(createdAt),
    'createdBy': createdBy,
    'inviteCode': inviteCode,
    'members': members.map((m) => m.toMap()).toList(),
    'memberIds': memberIds,
    'categories': categories,
  };

  factory SharedTracker.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'] as List<dynamic>? ?? [];
    final rawMemberIds = map['memberIds'] as List<dynamic>? ?? [];
    final rawCategories = map['categories'] as List<dynamic>?;
    return SharedTracker(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      members: rawMembers
          .map((m) => TrackerMember.fromMap(m as Map<String, dynamic>))
          .toList(),
      memberIds: rawMemberIds.cast<String>(),
      // null → old tracker doc without categories → fall back to defaults
      categories: rawCategories?.cast<String>() ?? [],
    );
  }

  factory SharedTracker.fromFirestore(DocumentSnapshot doc) =>
      SharedTracker.fromMap(doc.data() as Map<String, dynamic>);

  /// Generates a random 6-character uppercase alphanumeric invite code.
  static String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = math.Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
