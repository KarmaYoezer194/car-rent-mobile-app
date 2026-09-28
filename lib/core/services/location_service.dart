import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// A single resolved location: coordinates plus a human-readable address.
class ResolvedLocation {
  const ResolvedLocation({required this.latitude, required this.longitude, required this.address});

  final double latitude;
  final double longitude;
  final String address;
}

/// Thrown for every "can't get a location" case so callers can show one
/// consistent, explanatory message (Section 18: explain why location is
/// needed, handle denial, handle disabled services) instead of leaking raw
/// platform exceptions to the UI.
class LocationException implements Exception {
  const LocationException(this.message, {this.canOpenSettings = false});

  final String message;

  /// True when the only way forward is the OS settings screen (permission
  /// permanently denied, or location services turned off system-wide).
  final bool canOpenSettings;

  @override
  String toString() => message;
}

/// Wraps device GPS (geolocator) + reverse geocoding (geocoding) behind one
/// call. Used by Phase 4's pickup-location step now; Phase 7's continuous
/// tracking during an active rental will reuse the permission-handling
/// half of this (not the reverse-geocoding half, which is a one-shot
/// convenience, not something you'd do every GPS update).
class LocationService {
  Future<ResolvedLocation> getCurrentLocation() async {
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

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    String address = '';
    try {
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        address = _formatAddress(placemarks.first);
      }
    } catch (_) {
      // Reverse geocoding is best-effort — the user can still type/edit the
      // address manually if it comes back empty.
    }

    return ResolvedLocation(latitude: position.latitude, longitude: position.longitude, address: address);
  }

  Future<void> openSettings() => Geolocator.openAppSettings();

  String _formatAddress(Placemark placemark) {
    final parts = [
      placemark.street,
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea,
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }
}
