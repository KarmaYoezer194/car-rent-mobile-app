import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../core/constants/app_colors.dart';

/// A single marker to place on an [OsmMapView].
class MapPin {
  const MapPin({required this.latitude, required this.longitude, required this.color, required this.icon});

  final double latitude;
  final double longitude;
  final Color color;
  final IconData icon;
}

/// Shared OpenStreetMap view used everywhere the spec calls for "Google
/// Maps" (Section 19) — Car Details' pickup pin, Post Car's location
/// picker, and the Active Rental live car-location map. OSM's tiles are
/// free with no API key/billing, unlike Google Maps Platform (see README).
///
/// Attribution is required by OpenStreetMap's license (ODbL) — the
/// [RichAttributionWidget] below isn't decorative, don't remove it.
class OsmMapView extends StatelessWidget {
  const OsmMapView({
    super.key,
    required this.center,
    this.pins = const [],
    this.zoom = 15,
    this.interactive = true,
    this.onTap,
  });

  final MapPin center;
  final List<MapPin> pins;
  final double zoom;
  final bool interactive;
  final void Function(double latitude, double longitude)? onTap;

  @override
  Widget build(BuildContext context) {
    final allPins = [center, ...pins];

    return FlutterMap(
      options: MapOptions(
        initialCenter: latlong.LatLng(center.latitude, center.longitude),
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (_, point) => onTap!(point.latitude, point.longitude),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rentalcar.app',
        ),
        MarkerLayer(
          markers: allPins
              .map(
                (pin) => Marker(
                  point: latlong.LatLng(pin.latitude, pin.longitude),
                  width: 40,
                  height: 40,
                  child: Icon(pin.icon, color: pin.color, size: 36),
                ),
              )
              .toList(),
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors', prependCopyright: true),
          ],
        ),
      ],
    );
  }
}

/// Standard pin styles so every screen's map markers look consistent.
class MapPins {
  MapPins._();

  // `navy`, not the theme-flipping `primary`: OSM tiles stay light in dark
  // mode, so a near-white pin would vanish into the map.
  static MapPin pickup(double lat, double lng) =>
      MapPin(latitude: lat, longitude: lng, color: AppColors.navy, icon: Icons.location_on_rounded);

  static MapPin car(double lat, double lng) =>
      MapPin(latitude: lat, longitude: lng, color: AppColors.success, icon: Icons.directions_car_rounded);
}
