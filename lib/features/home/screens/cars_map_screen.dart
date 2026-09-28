import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/car_model.dart';
import '../../../widgets/loading_widget.dart';

/// Home's "Map View": the cars currently shown in the list (same search and
/// filters), each as a price marker at its pickup spot. Tapping a marker
/// opens that car. OpenStreetMap tiles, like every other map in the app.
class CarsMapScreen extends StatelessWidget {
  const CarsMapScreen({super.key, required this.cars});

  final List<CarModel> cars;

  @override
  Widget build(BuildContext context) {
    // Listings without a real pickup location sit at (0, 0) — skip them
    // rather than dropping a pin off the coast of Africa.
    final located = cars.where((c) => c.latitude != 0 || c.longitude != 0).toList();
    final points = located.map((c) => latlong.LatLng(c.latitude, c.longitude)).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${located.length} ${located.length == 1 ? 'car' : 'cars'} on the map')),
      body: located.isEmpty
          ? const EmptyStateWidget(icon: LucideIcons.map, message: 'None of these cars has a pickup location yet.')
          : FlutterMap(
              options: MapOptions(
                // One point has no bounds to fit — center on it instead.
                initialCenter: points.first,
                initialZoom: 14,
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(coordinates: points, padding: const EdgeInsets.all(64))
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rentalcar.app',
                ),
                MarkerLayer(
                  markers: [
                    for (final car in located)
                      Marker(
                        point: latlong.LatLng(car.latitude, car.longitude),
                        width: 96,
                        height: 34,
                        child: _PriceMarker(car: car),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors', prependCopyright: true)],
                ),
              ],
            ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker({required this.car});

  final CarModel car;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: car.title,
        child: GestureDetector(
          onTap: () => context.push('/car/${car.id}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.overlayAccent, width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Text(
              AppFormatters.currency(car.pricePerDay),
              style: AppTextStyles.caption.copyWith(color: AppColors.overlayAccent, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}
