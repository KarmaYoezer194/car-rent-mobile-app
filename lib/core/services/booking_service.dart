import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/booking_model.dart';
import '../../models/car_model.dart';
import '../../models/notification_model.dart';
import '../constants/car_options.dart';
import '../constants/pricing.dart';
import 'notification_service.dart';

/// Thrown by [BookingService.createBooking] when the requested date range
/// can't be booked, so the UI can show a specific message instead of the
/// generic error state.
class BookingUnavailableException implements Exception {
  BookingUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// All `bookings` collection access goes through here — mirrors
/// [CarService]'s role for `cars`.
class BookingService {
  BookingService({FirebaseFirestore? firestore, NotificationService? notificationService})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _bookingsRef => _firestore.collection('bookings');

  /// This user's own booking requests ("Renting" tab), newest first.
  /// Filters `hiddenForRenter` client-side rather than adding it to the
  /// query — same reasoning as [NotificationService.streamUnreadCount]:
  /// one more `where` here would need a composite index, for a list that's
  /// already small enough to filter in memory.
  Stream<List<BookingModel>> streamBookingsForRenter(String renterId) {
    return _bookingsRef
        .where('renterId', isEqualTo: renterId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(BookingModel.fromSnapshot).where((b) => !b.hiddenForRenter).toList());
  }

  /// Requests received against cars this user owns ("My Cars" tab), newest
  /// first.
  Stream<List<BookingModel>> streamBookingsForOwner(String ownerId) {
    return _bookingsRef
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(BookingModel.fromSnapshot).where((b) => !b.hiddenForOwner).toList());
  }

  /// Swipes a settled booking out of the renter's own "Renting" list. Only
  /// touches this party's flag — see [BookingModel.hiddenForRenter].
  Future<void> hideForRenter(String bookingId, {bool hidden = true}) {
    return _bookingsRef.doc(bookingId).update({'hiddenForRenter': hidden});
  }

  /// Same as [hideForRenter], for the owner's "My Cars" list.
  Future<void> hideForOwner(String bookingId, {bool hidden = true}) {
    return _bookingsRef.doc(bookingId).update({'hiddenForOwner': hidden});
  }

  /// Live view of a single booking — used by the Active Rental screen so it
  /// reflects a status change (e.g. the owner confirming return) while it's
  /// open, instead of only showing the snapshot it was opened with.
  Stream<BookingModel?> streamBooking(String bookingId) {
    return _bookingsRef.doc(bookingId).snapshots().map(
          (doc) => doc.exists ? BookingModel.fromSnapshot(doc) : null,
        );
  }

  /// The single active booking for a car, if any — lets My Cars link a
  /// "Currently Rented" listing straight to its Active Rental screen
  /// (Section 10's "[ View Rental ]").
  Stream<BookingModel?> streamActiveBookingForCar(String carId) {
    return _bookingsRef
        .where('carId', isEqualTo: carId)
        .where('status', isEqualTo: BookingStatus.active)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty ? null : BookingModel.fromSnapshot(snapshot.docs.first));
  }

  /// Section 9: "The system must prevent users from booking unavailable
  /// dates." Reads every pending/confirmed/active booking for [car] and
  /// rejects [start]-[end] if it falls outside the car's availability
  /// window or overlaps an existing one, then writes the new request.
  ///
  /// This is a read-then-write check rather than a transaction — Firestore
  /// transactions can't run an arbitrary `where` query internally, and a
  /// small race window between two people booking the exact same moment is
  /// an acceptable trade-off at this project's scale (no Cloud Functions in
  /// the stack). A duplicate that slips through still needs the owner to
  /// accept both, and accepting the second one is the same "oops, already
  /// booked" case an owner has to handle manually either way.
  Future<String> createBooking({
    required CarModel car,
    required String renterId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (renterId == car.ownerId) {
      throw BookingUnavailableException("You can't book your own car.");
    }
    if (!end.isAfter(start)) {
      throw BookingUnavailableException('End date must be after the start date.');
    }
    if (car.availableFrom != null && start.isBefore(car.availableFrom!)) {
      throw BookingUnavailableException('This car is only available from ${_fmt(car.availableFrom!)}.');
    }
    if (car.availableUntil != null && end.isAfter(car.availableUntil!)) {
      throw BookingUnavailableException('This car is only available until ${_fmt(car.availableUntil!)}.');
    }

    final existing = await _bookingsRef
        .where('carId', isEqualTo: car.id)
        .where('status', whereIn: BookingStatus.blocking)
        .get();
    final overlaps = existing.docs.any((doc) {
      final booking = BookingModel.fromSnapshot(doc);
      return start.isBefore(booking.endDate) && booking.startDate.isBefore(end);
    });
    if (overlaps) {
      throw BookingUnavailableException('These dates are already booked. Try a different range.');
    }

    final totalDays = end.difference(start).inDays;
    final totalPrice = totalDays * car.pricePerDay;
    // Platform commission, computed here — the one place bookings are
    // created — and stored as amounts alongside the total.
    final split = PlatformPricing.split(totalPrice);
    final booking = BookingModel(
      id: '',
      carId: car.id,
      ownerId: car.ownerId,
      renterId: renterId,
      carTitle: car.title,
      carImage: car.coverImage,
      pricePerDay: car.pricePerDay,
      startDate: start,
      endDate: end,
      totalDays: totalDays,
      totalPrice: totalPrice,
      commissionAmount: split.commission,
      ownerPayout: split.payout,
      status: BookingStatus.pending,
      createdAt: DateTime.now(),
    );

    final doc = await _bookingsRef.add({
      ...booking.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _notificationService.send(
      userId: car.ownerId,
      title: 'New booking request',
      message: 'You have a new request for your ${car.title}.',
      type: NotificationType.bookingRequest,
      relatedId: doc.id,
    );

    return doc.id;
  }

  /// Owner accepts or declines a pending request (Section 13).
  Future<void> respondToBooking(BookingModel booking, {required bool accept}) async {
    await _bookingsRef.doc(booking.id).update({
      'status': accept ? BookingStatus.confirmed : BookingStatus.rejected,
    });
    await _notificationService.send(
      userId: booking.renterId,
      title: accept ? 'Booking accepted' : 'Booking rejected',
      message: accept
          ? 'Your request for ${booking.carTitle} has been accepted.'
          : 'Your request for ${booking.carTitle} was rejected.',
      type: accept ? NotificationType.bookingAccepted : NotificationType.bookingRejected,
      relatedId: booking.id,
    );
  }

  /// Renter withdraws a request that hasn't started yet — pending or
  /// already-confirmed (Section 12's alternate "CONFIRMED → User cancels →
  /// CANCELLED" path), enforced by the same rule as the write itself.
  Future<void> cancelBooking(BookingModel booking) async {
    await _bookingsRef.doc(booking.id).update({'status': BookingStatus.cancelled});
    await _notificationService.send(
      userId: booking.ownerId,
      title: 'Booking cancelled',
      message: 'The renter cancelled their request for ${booking.carTitle}.',
      type: NotificationType.bookingCancelled,
      relatedId: booking.id,
    );
  }

  /// Owner marks a confirmed booking as started (Section 13's "Rental
  /// starts" step). Also flips the car to `rented` in the same batch so My
  /// Cars' "Currently Rented" state and the edit/delete guard stay in sync
  /// with reality — a single write either fully lands or fully doesn't.
  Future<void> startRental(BookingModel booking) {
    final batch = _firestore.batch();
    batch.update(_bookingsRef.doc(booking.id), {'status': BookingStatus.active});
    batch.update(_firestore.collection('cars').doc(booking.carId), {'status': CarStatus.rented});
    return batch.commit();
  }

  /// Renter's side of the handover (Section 20): marks the car as handed
  /// back and notifies the owner to go check it, without touching the
  /// car's `rented` status itself — only the owner's [completeRental] does
  /// that, so a renter can't free up their own car's dates unilaterally.
  ///
  /// Leaving `active` ends location sharing, so the booking's stored
  /// location is deleted in the same batch — the status change and the
  /// deletion land together or not at all (see [_deleteLocation]).
  Future<void> requestReturn(BookingModel booking) async {
    final batch = _firestore.batch();
    batch.update(_bookingsRef.doc(booking.id), {'status': BookingStatus.returnRequested});
    _deleteLocation(batch, booking.id);
    await batch.commit();
    await _notificationService.send(
      userId: booking.ownerId,
      title: 'Car returned',
      message: 'The renter marked ${booking.carTitle} as returned. Confirm once you\'ve checked it.',
      type: NotificationType.returnRequested,
      relatedId: booking.id,
    );
  }

  /// Owner confirms the car was returned (Section 20) — whether the renter
  /// already flagged it via [requestReturn] or not; a rental active for a
  /// while can be confirmed straight from `active` too, since the owner
  /// physically having the car back is what actually matters, not whether
  /// the renter tapped a button first. Flips the car back to `available` in
  /// the same batch — there's no separate "returned" status in the schema,
  /// so the real-world handoff is just the cue for the owner to tap this,
  /// not a persisted state of its own.
  Future<void> completeRental(BookingModel booking) async {
    final batch = _firestore.batch();
    batch.update(_bookingsRef.doc(booking.id), {'status': BookingStatus.completed});
    batch.update(_firestore.collection('cars').doc(booking.carId), {'status': CarStatus.available});
    // Already gone if the renter requested the return first; deleting a
    // missing doc is a harmless no-op, and completing straight from
    // `active` needs it.
    _deleteLocation(batch, booking.id);
    await batch.commit();

    await _notificationService.send(
      userId: booking.renterId,
      title: 'Rental completed',
      message: 'Your rental of ${booking.carTitle} is complete. Leave a review!',
      type: NotificationType.rentalCompleted,
      relatedId: booking.id,
    );
  }

  /// Records the renter's answer to the location-sharing consent prompt,
  /// stamped with server time. Rules allow this only for the booking's
  /// renter, only while it's `active`, and only these two fields.
  Future<void> recordLocationConsent(BookingModel booking, {required bool granted}) {
    return _bookingsRef.doc(booking.id).update({
      'locationConsent': granted ? LocationConsent.granted : LocationConsent.declined,
      'locationConsentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Every path out of `active` must call this in the same batch as its
  /// status change: once a booking isn't active its location must not be
  /// kept. Rules permit the delete only when the batch's resulting status
  /// isn't `active` (via `getAfter`).
  void _deleteLocation(WriteBatch batch, String bookingId) {
    batch.delete(_firestore.collection('bookingLocations').doc(bookingId));
  }

  String _fmt(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
