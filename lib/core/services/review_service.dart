import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/booking_model.dart';
import '../../models/notification_model.dart';
import '../../models/review_model.dart';
import 'notification_service.dart';

/// Thrown by [ReviewService.submitReview] for a review that shouldn't be
/// written, so the UI can show a specific message instead of the generic
/// error state.
class ReviewException implements Exception {
  ReviewException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All `reviews` collection access, plus the `cars`/`users` rating-aggregate
/// bump that comes with writing one — mirrors [CarService]/[BookingService]'s
/// role for their collections.
class ReviewService {
  ReviewService({FirebaseFirestore? firestore, NotificationService? notificationService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _reviewsRef => _firestore.collection('reviews');

  /// Reviews left on a car, newest first — backs Car Details' Reviews
  /// section (Section 8).
  Stream<List<ReviewModel>> streamReviewsForCar(String carId) {
    return _reviewsRef
        .where('carId', isEqualTo: carId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ReviewModel.fromSnapshot).toList());
  }

  /// Reviews this user has written, newest first — backs Profile's "My
  /// Reviews" (Section 21).
  Stream<List<ReviewModel>> streamReviewsByRenter(String renterId) {
    return _reviewsRef
        .where('renterId', isEqualTo: renterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ReviewModel.fromSnapshot).toList());
  }

  /// The review for one booking, if it's been written yet — since the
  /// review's document id *is* the booking id, this is a single doc read.
  /// Used to decide whether a completed booking still shows a "Write a
  /// Review" action.
  Stream<ReviewModel?> streamReviewForBooking(String bookingId) {
    return _reviewsRef.doc(bookingId).snapshots().map(
          (doc) => doc.exists ? ReviewModel.fromSnapshot(doc) : null,
        );
  }

  /// Writes a review for a completed [booking] and rolls the rating into
  /// both the car's and the owner's denormalized `rating`/`reviewCount`
  /// aggregates, atomically.
  ///
  /// A transaction (not the read-then-write pattern [BookingService] uses
  /// for overlap checks) is the right tool here: all three documents are
  /// known upfront by id, so there's no arbitrary query involved and
  /// Firestore can retry the whole thing safely if two writes race.
  Future<void> submitReview({
    required BookingModel booking,
    required double rating,
    required String comment,
  }) async {
    if (booking.status != BookingStatus.completed) {
      throw ReviewException('Only completed rentals can be reviewed.');
    }
    if (rating < 1 || rating > 5) {
      throw ReviewException('Pick a rating between 1 and 5 stars.');
    }

    final reviewRef = _reviewsRef.doc(booking.id);
    final carRef = _firestore.collection('cars').doc(booking.carId);
    final ownerRef = _firestore.collection('users').doc(booking.ownerId);

    await _firestore.runTransaction((transaction) async {
      final existingReview = await transaction.get(reviewRef);
      if (existingReview.exists) {
        throw ReviewException('You already reviewed this rental.');
      }
      final carSnapshot = await transaction.get(carRef);
      final ownerSnapshot = await transaction.get(ownerRef);

      final review = ReviewModel(
        id: booking.id,
        bookingId: booking.id,
        carId: booking.carId,
        ownerId: booking.ownerId,
        renterId: booking.renterId,
        carTitle: booking.carTitle,
        carImage: booking.carImage,
        rating: rating,
        comment: comment.trim(),
        createdAt: DateTime.now(),
      );
      transaction.set(reviewRef, {
        ...review.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // The car listing (or, in principle, the owner's account) can be gone
      // by the time a completed rental gets reviewed — e.g. the owner
      // deleted the listing afterward. `transaction.update()` throws
      // NOT_FOUND against a document that no longer exists, which was
      // failing the *entire* review submission over an aggregate that
      // simply has nothing left to bump. Skip it instead; the review itself
      // still gets written either way.
      if (carSnapshot.exists) {
        _bumpRatingAggregate(transaction, carRef, carSnapshot.data(), rating);
      }
      if (ownerSnapshot.exists) {
        _bumpRatingAggregate(transaction, ownerRef, ownerSnapshot.data(), rating);
      }
    });

    // Outside the transaction: a notification isn't part of the rating
    // aggregate's atomicity requirement, and Firestore transactions retry
    // on contention — retrying a `send()` too would risk duplicate
    // notifications for one review.
    await _notificationService.send(
      userId: booking.ownerId,
      title: 'New review',
      message: 'You received a ${rating.toStringAsFixed(1)}-star review for ${booking.carTitle}.',
      type: NotificationType.newReview,
      relatedId: booking.id,
    );
  }

  /// Recomputes a running average in place: `newAvg = (oldAvg*oldCount +
  /// rating) / (oldCount+1)`. Used identically for both `cars` and `users`
  /// docs, which is why it takes a bare [ref]/[data] pair instead of a typed
  /// model — the two collections don't share a model class.
  void _bumpRatingAggregate(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic>? data,
    double rating,
  ) {
    final oldRating = (data?['rating'] as num?)?.toDouble() ?? 0;
    final oldCount = (data?['reviewCount'] as num?)?.toInt() ?? 0;
    final newCount = oldCount + 1;
    final newRating = ((oldRating * oldCount) + rating) / newCount;
    transaction.update(ref, {'rating': newRating, 'reviewCount': newCount});
  }
}
