import 'package:cloud_firestore/cloud_firestore.dart';

/// Values stored in a booking document's `status` field (Section 13).
///
/// `active`/`completed` are deliberately not produced by anything yet —
/// Phase 6 (rental management) is what transitions a confirmed booking into
/// an active rental and then completes it. Phase 5 only ever writes
/// pending/confirmed/rejected/cancelled.
class BookingStatus {
  BookingStatus._();

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String active = 'active';

  /// The renter has told the owner they're handing the car back (Section
  /// 20's handover); the car isn't available again until the owner
  /// actually confirms it via [completeRental] — this status just closes
  /// the gap between "renter is done" and "owner has looked at it".
  static const String returnRequested = 'return_requested';
  static const String completed = 'completed';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';

  /// Statuses that still hold a car's dates — an overlap check must treat
  /// these (and only these) as blocking a new request.
  static const List<String> blocking = [pending, confirmed, active, returnRequested];
}

/// Values stored in a booking's `locationConsent` field — the renter's
/// answer to "share your location with the owner for this rental?". Absent
/// until they answer. Written once per booking with a server timestamp
/// (`locationConsentAt`); Firestore rules refuse location writes for a
/// booking unless this is [granted].
class LocationConsent {
  LocationConsent._();

  static const String granted = 'granted';
  static const String declined = 'declined';
}

/// Mirrors a document in the top-level `bookings` collection (Section 24).
///
/// `carTitle`/`carImage`/`pricePerDay` are denormalized from the car at
/// booking time — same reasoning as `CarModel.rating`/`reviewCount`: the
/// Booking screen lists many bookings at once and shouldn't need a `cars`
/// read per row (and a listing's price/photos can change after a booking
/// is made without rewriting history).
class BookingModel {
  const BookingModel({
    required this.id,
    required this.carId,
    required this.ownerId,
    required this.renterId,
    required this.carTitle,
    required this.carImage,
    required this.pricePerDay,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.hiddenForRenter = false,
    this.hiddenForOwner = false,
    this.locationConsent,
    this.locationConsentAt,
    this.commissionAmount,
    this.ownerPayout,
  });

  final String id;
  final String carId;
  final String ownerId;
  final String renterId;
  final String carTitle;
  final String carImage;
  final double pricePerDay;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final double totalPrice;
  final String status;
  final DateTime createdAt;

  /// Set when the renter/owner swipes a settled booking away from their own
  /// "Renting"/"My Cars" list (Section 13). One booking document is shared
  /// between both parties, so this is two independent flags rather than a
  /// single delete — swiping it away on one side doesn't touch what the
  /// other party sees.
  final bool hiddenForRenter;
  final bool hiddenForOwner;

  /// [LocationConsent.granted]/[LocationConsent.declined], or null if the
  /// renter hasn't answered yet. Only ever set while the booking is active.
  final String? locationConsent;
  final DateTime? locationConsentAt;

  /// Platform commission and the owner's share of [totalPrice], computed
  /// once at booking time (see PlatformPricing) and stored as amounts, not
  /// a rate. Null on bookings made before commission existed — those
  /// carried no fee, so the owner's share is the full total
  /// ([payoutForOwner]).
  final double? commissionAmount;
  final double? ownerPayout;

  /// What the owner receives — shown on every owner-facing screen instead
  /// of [totalPrice] (renters only ever see [totalPrice]).
  double get payoutForOwner => ownerPayout ?? totalPrice;

  bool get hasLocationConsent => locationConsent == LocationConsent.granted;

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    return BookingModel(
      id: id,
      carId: map['carId'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      renterId: map['renterId'] as String? ?? '',
      carTitle: map['carTitle'] as String? ?? '',
      carImage: map['carImage'] as String? ?? '',
      pricePerDay: (map['pricePerDay'] as num?)?.toDouble() ?? 0,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalDays: (map['totalDays'] as num?)?.toInt() ?? 0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? BookingStatus.pending,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hiddenForRenter: map['hiddenForRenter'] as bool? ?? false,
      hiddenForOwner: map['hiddenForOwner'] as bool? ?? false,
      locationConsent: map['locationConsent'] as String?,
      locationConsentAt: (map['locationConsentAt'] as Timestamp?)?.toDate(),
      commissionAmount: (map['commissionAmount'] as num?)?.toDouble(),
      ownerPayout: (map['ownerPayout'] as num?)?.toDouble(),
    );
  }

  factory BookingModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return BookingModel.fromMap(snapshot.data() ?? const {}, snapshot.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'carId': carId,
      'ownerId': ownerId,
      'renterId': renterId,
      'carTitle': carTitle,
      'carImage': carImage,
      'pricePerDay': pricePerDay,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'totalPrice': totalPrice,
      'status': status,
      if (commissionAmount != null) 'commissionAmount': commissionAmount,
      if (ownerPayout != null) 'ownerPayout': ownerPayout,
    };
  }
}
