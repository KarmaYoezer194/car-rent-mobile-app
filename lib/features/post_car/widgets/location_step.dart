import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/osm_map_view.dart';
import '../models/car_draft.dart';

/// Default map center before a location has been picked (Bangkok) — just a
/// starting viewport, not a claim about where the car actually is.
const _defaultLatitude = 13.7563;
const _defaultLongitude = 100.5018;

/// Step 4 — Pickup Location (Section 9): "Open map, move/select a marker,
/// save latitude/longitude/address." The map is OpenStreetMap, not Google
/// Maps (see README) — tapping it moves the pin, which is this app's
/// equivalent of "select a marker" (flutter_map has no built-in drag
/// gesture for markers, and tap-to-place is just as fast here). "Use
/// Current Location" is still the fastest path for the common case of
/// listing a car from where you're standing; the map lets you fine-tune
/// from there, or place a pin without GPS at all.
class LocationStep extends StatefulWidget {
  const LocationStep({super.key, required this.draft, required this.onChanged});

  final CarDraft draft;
  final VoidCallback onChanged;

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  final _locationService = LocationService();
  late final _addressController = TextEditingController(text: widget.draft.address);
  bool _isLocating = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final resolved = await _locationService.getCurrentLocation();
      setState(() {
        widget.draft.latitude = resolved.latitude;
        widget.draft.longitude = resolved.longitude;
        if (resolved.address.isNotEmpty) {
          widget.draft.address = resolved.address;
          _addressController.text = resolved.address;
        }
      });
      widget.onChanged();
    } on LocationException catch (e) {
      if (!mounted) return;
      if (e.canOpenSettings) {
        _showSettingsDialog(e.message);
      } else {
        AppSnackbar.show(context, e.message);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, "Couldn't get your location. Please try again.");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showSettingsDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location needed'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _locationService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _onMapTap(double latitude, double longitude) {
    setState(() {
      widget.draft.latitude = latitude;
      widget.draft.longitude = longitude;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = widget.draft.latitude != null && widget.draft.longitude != null;
    final latitude = widget.draft.latitude ?? _defaultLatitude;
    final longitude = widget.draft.longitude ?? _defaultLongitude;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where can renters pick up the car?', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Use your current location, or tap the map to place the pin yourself.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SizedBox(
              // A fresh key whenever the pin moves recenters the map on it —
              // flutter_map doesn't animate to a new center on rebuild
              // otherwise since MapOptions.initialCenter only applies once.
              key: ValueKey('$latitude,$longitude'),
              height: 220,
              // Non-interactive: this map sits inside the form's
              // SingleChildScrollView, and pinch/pan there would fight
              // page scrolling the same way it did on Car Details before
              // that got reported and fixed. Tapping to place the pin
              // still works — flutter_map's tap detection runs
              // independently of the pan/zoom interaction flags.
              child: OsmMapView(
                center: MapPins.pickup(latitude, longitude),
                onTap: _onMapTap,
                interactive: false,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CustomButton(
            label: hasCoordinates ? 'Update Current Location' : 'Use Current Location',
            icon: LucideIcons.locateFixed,
            isLoading: _isLocating,
            isOutlined: true,
            onPressed: _useCurrentLocation,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (hasCoordinates)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.circleCheck, color: AppColors.accent, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Pin set at (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)})',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          CustomTextField(
            label: 'Pickup address',
            hint: 'Street, area, city',
            controller: _addressController,
            maxLines: 2,
            inputFormatters: [CapitalizeWordsFormatter()],
            onChanged: (value) {
              widget.draft.address = value;
              widget.onChanged();
            },
          ),
        ],
      ),
    );
  }
}
