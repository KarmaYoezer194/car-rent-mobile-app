import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors a document in the top-level `users` collection (Section 24).
///
/// Every registered user is represented by exactly one of these — there is
/// no separate owner/renter type, since any user can list a car or rent one.
class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage,
    this.rating = 0,
    this.reviewCount = 0,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? profileImage;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      profileImage: map['profileImage'] as String?,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return UserModel.fromMap(snapshot.data() ?? const {}, snapshot.id);
  }

  /// Data payload for creating/updating this user's document. `createdAt` is
  /// intentionally excluded — callers set it once with
  /// `FieldValue.serverTimestamp()` at creation time instead of trusting the
  /// client clock.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? profileImage,
    double? rating,
    int? reviewCount,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt,
    );
  }
}
