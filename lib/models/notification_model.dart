import 'package:cloud_firestore/cloud_firestore.dart';

/// Values stored in a notification document's `type` field (Section 15).
///
/// `rentalStartingSoon`/`rentalEndingSoon` from the spec's list aren't
/// produced by anything — they're time-based reminders ("3 hours before
/// start"), and without a server-side scheduled job (Cloud Functions,
/// which need the paid Blaze plan — same wall as Storage/Maps) there's no
/// reliable way to fire one when nobody has the app open. Every other type
/// here is triggered by a real client-side event, which this app already
/// has code running for.
class NotificationType {
  NotificationType._();

  static const String bookingRequest = 'booking_request';
  static const String bookingAccepted = 'booking_accepted';
  static const String bookingRejected = 'booking_rejected';
  static const String bookingCancelled = 'booking_cancelled';
  static const String returnRequested = 'return_requested';
  static const String rentalCompleted = 'rental_completed';
  static const String newReview = 'new_review';
}

/// Mirrors a document in the top-level `notifications` collection
/// (Section 24). This app has no push delivery (see README) — a document
/// here *is* the notification; nothing separate gets sent to the device.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedId,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? relatedId;
  final bool read;
  final DateTime createdAt;

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      type: map['type'] as String? ?? '',
      relatedId: map['relatedId'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory NotificationModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    return NotificationModel.fromMap(snapshot.data() ?? const {}, snapshot.id);
  }
}
