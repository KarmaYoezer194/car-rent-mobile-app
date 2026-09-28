import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors a document in the top-level `reviews` collection (Section 24,
/// extended here for Phase 8).
///
/// A review is left by the renter about the car (and, by extension, the
/// owner) once a booking has completed — this app has no separate
/// owner-reviews-renter direction, matching the spec's "My Reviews" (Section
/// 21) being written from the renter's point of view.
///
/// The document id **is the booking id**, not an auto-id — same one-per-key
/// pattern as `favorites/{userId}`. That makes "has this booking already
/// been reviewed?" a single doc read instead of a query, and lets Firestore
/// rules block a second review for the same booking for free: `allow
/// create` only ever fires when the document doesn't exist yet, so a resubmit
/// hits `allow update: if false` instead of silently double-counting the
/// rating aggregate.
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.carId,
    required this.ownerId,
    required this.renterId,
    required this.carTitle,
    required this.carImage,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String bookingId;
  final String carId;
  final String ownerId;
  final String renterId;
  final String carTitle;
  final String carImage;
  final double rating;
  final String comment;
  final DateTime createdAt;

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      bookingId: map['bookingId'] as String? ?? id,
      carId: map['carId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      renterId: map['renterId'] as String? ?? '',
      carTitle: map['carTitle'] as String? ?? '',
      carImage: map['carImage'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      comment: map['comment'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory ReviewModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return ReviewModel.fromMap(snapshot.data() ?? const {}, snapshot.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'carId': carId,
      'ownerId': ownerId,
      'renterId': renterId,
      'carTitle': carTitle,
      'carImage': carImage,
      'rating': rating,
      'comment': comment,
    };
  }
}
