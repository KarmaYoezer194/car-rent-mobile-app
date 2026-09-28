import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/notification_model.dart';

/// All `notifications` collection access — mirrors [CarService]/
/// [BookingService]'s role for their collections.
///
/// There is no push delivery in this app (see README's "Notifications:
/// in-app only" section) — `send()` just writes the Firestore document
/// that *is* the notification. `BookingService` and `ReviewService` call
/// it right after the event they're announcing actually happens.
class NotificationService {
  NotificationService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsRef => _firestore.collection('notifications');

  Future<void> send({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedId,
  }) {
    return _notificationsRef.add({
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'relatedId': relatedId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// This user's notification history, newest first (Section 15: "stored
  /// in Firestore so users can view notification history").
  Stream<List<NotificationModel>> streamForUser(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(NotificationModel.fromSnapshot).toList());
  }

  /// Unread count for a badge (Home's bell icon) — derived from the same
  /// list query rather than a second listener/composite index.
  Stream<int> streamUnreadCount(String userId) {
    return streamForUser(userId).map((list) => list.where((n) => !n.read).length);
  }

  Future<void> markAsRead(String notificationId) {
    return _notificationsRef.doc(notificationId).update({'read': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final unread = await _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
