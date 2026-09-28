import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `bookingLocations/{bookingId}` — the renter's **latest** reported
/// position during an active rental. One document per booking, keyed by the
/// booking id and overwritten on every update, so no location history is
/// ever kept. It's deleted in the same batch that moves the booking out of
/// `active` (see BookingService.requestReturn/completeRental).
///
/// `ownerId`/`renterId` are copied from the booking so the owner's live
/// listener can be matched to them; the security rules still authorize
/// every read/write against the booking document itself.
class BookingLocationModel {
  const BookingLocationModel({
    required this.bookingId,
    required this.ownerId,
    required this.renterId,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.updatedAt,
  });

  final String bookingId;
  final String ownerId;
  final String renterId;
  final double lat;
  final double lng;

  /// GPS accuracy radius in meters — drawn as an "about here" circle.
  final double accuracyM;
  final DateTime updatedAt;

  factory BookingLocationModel.fromMap(Map<String, dynamic> map, String bookingId) {
    return BookingLocationModel(
      bookingId: bookingId,
      ownerId: map['ownerId'] as String? ?? '',
      renterId: map['renterId'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      accuracyM: (map['accuracyM'] as num?)?.toDouble() ?? 0,
      // Null only on the writer's own device for the instant between the
      // local write and the server stamping it.
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory BookingLocationModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return BookingLocationModel.fromMap(snapshot.data() ?? const {}, snapshot.id);
  }
}
