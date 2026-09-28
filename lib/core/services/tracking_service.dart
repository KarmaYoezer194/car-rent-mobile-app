import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/booking_location_model.dart';
import '../constants/tracking_config.dart';
import 'location_service.dart';

/// Live location sharing for an active rental: the renter's device writes
/// its latest position, the car's owner watches it.
///
/// Backed by a single `bookingLocations/{bookingId}` document that's
/// overwritten on every update — only the latest position exists, never a
/// history. Firestore rules are the real gatekeeper: writes need the booking
/// to be `active` with `locationConsent == 'granted'` and come from its
/// renter; reads need the booking to be `active` and come from its owner.
///
/// Foreground-only: sharing runs while the renter has the Active Rental
/// screen open. Background tracking (Android foreground service, iOS
/// background-location entitlement) is out of scope; the owner's map shows
/// the location as stale when updates stop arriving.
class TrackingService {
  TrackingService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  StreamSubscription<Position>? _positionSub;
  Timer? _heartbeat;
  Position? _latest;

  DocumentReference<Map<String, dynamic>> _locationRef(String bookingId) =>
      _firestore.collection('bookingLocations').doc(bookingId);

  bool get isTracking => _heartbeat != null;

  /// Starts sending this device's position for [bookingId] every
  /// [TrackingConfig.heartbeatInterval]. Requests location permission first
  /// and throws [LocationException] on denial/disabled services rather than
  /// tracking silently or crashing.
  ///
  /// [onStopped] is called if the backend starts refusing writes — i.e. the
  /// booking left `active` (or consent is missing) while this was running —
  /// after tracking has already been stopped locally.
  Future<void> startTracking({
    required String bookingId,
    required String renterId,
    required String ownerId,
    void Function()? onStopped,
  }) async {
    await stopTracking();

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        'Location services are turned off. Enable them in your device settings.',
        canOpenSettings: true,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it in app settings.',
        canOpenSettings: true,
      );
    }

    Future<void> send() async {
      final position = _latest;
      if (position == null) return;
      try {
        await _locationRef(bookingId).set({
          'ownerId': ownerId,
          'renterId': renterId,
          'lat': position.latitude,
          'lng': position.longitude,
          'accuracyM': position.accuracy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        // Rules only refuse once the booking is no longer active (or
        // consent is gone) — nothing to retry, so stop for good.
        if (e.code == 'permission-denied') {
          await stopTracking();
          onStopped?.call();
        }
        // Anything else (e.g. offline) is transient: the next heartbeat
        // tries again with a fresher position.
      }
    }

    // The stream keeps [_latest] fresh; the heartbeat decides when to send.
    // Keeping those separate is what makes updates arrive on a steady
    // cadence even while the car is parked and the GPS reports nothing new.
    _positionSub = Geolocator.getPositionStream(
      // 10 m filter: a parked car stops producing callbacks (battery), and
      // the heartbeat simply re-sends the last fix with a fresh timestamp.
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((position) {
      final isFirstFix = _latest == null;
      _latest = position;
      // Don't make the owner wait a full interval for the first point.
      if (isFirstFix) send();
    });
    _heartbeat = Timer.periodic(TrackingConfig.heartbeatInterval, (_) => send());
  }

  /// Pauses sending. Doesn't touch the stored location or the consent
  /// record — the owner's map just shows the last point going stale.
  Future<void> stopTracking() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _latest = null;
  }

  /// The car's current location for the owner, live. Emits null until the
  /// renter's first update arrives. Errors with permission-denied if the
  /// booking isn't active or the caller isn't its owner.
  Stream<BookingLocationModel?> watchLocation(String bookingId) {
    return _locationRef(bookingId).snapshots().map(
          (doc) => doc.exists ? BookingLocationModel.fromSnapshot(doc) : null,
        );
  }
}
