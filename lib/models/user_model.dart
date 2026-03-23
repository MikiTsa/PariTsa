import 'package:cloud_firestore/cloud_firestore.dart';

/// User model representing an authenticated user
class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Convert UserModel to Map for Firestore.
  /// displayName is omitted when null so the security rule
  /// type-check on that field never fails.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uid': uid,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (displayName != null) map['displayName'] = displayName;
    return map;
  }

  /// Create UserModel from Firestore document with null-safe fallbacks.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Create UserModel from Firestore DocumentSnapshot
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data);
  }

  /// Create a copy with some modified fields
  UserModel copyWith({String? displayName}) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
    );
  }
}
