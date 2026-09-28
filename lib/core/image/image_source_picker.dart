import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_snackbar.dart';

/// "Take a Photo" / "Choose from Gallery" bottom sheet. Returns null if the
/// user dismisses it.
Future<ImageSource?> showImageSourceSheet(BuildContext context, {String title = 'Add image'}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _SourceCard(
                    icon: LucideIcons.camera,
                    label: 'Take a Photo',
                    onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _SourceCard(
                    icon: LucideIcons.images,
                    label: 'Choose from Gallery',
                    onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Opens the camera or gallery and returns the chosen photo, or null if the
/// user cancelled or it couldn't be picked (in which case the user has
/// already been told why).
///
/// Permissions: this relies on the OS's own just-in-time prompts, which is
/// the platform-recommended flow and needs no extra plugin —
/// - iOS shows the camera prompt (NSCameraUsageDescription) on first camera
///   use. The gallery uses PHPicker, which runs out-of-process and needs no
///   photo-library permission at all as long as full metadata isn't
///   requested (hence `requestFullMetadata: false`).
/// - Android captures via the system camera app and picks via the system
///   Photo Picker, neither of which needs a runtime permission from us.
///
/// If the user has denied access, image_picker throws a [PlatformException]
/// with an `*_access_denied` code; that becomes an explanation dialog with
/// the steps (and, on iOS, a shortcut) to re-enable it in Settings.
Future<XFile?> pickImageFromSource(BuildContext context, ImageSource source) async {
  try {
    return await ImagePicker().pickImage(
      source: source,
      // Caps memory for the editor and forces a JPEG re-encode on iOS, so
      // HEIC originals come back in a format the processor can decode.
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 95,
      requestFullMetadata: false,
    );
  } on PlatformException catch (e) {
    if (!context.mounted) return null;
    switch (e.code) {
      case 'camera_access_denied':
        await _showPermissionDeniedDialog(context, _PermissionKind.camera);
      case 'photo_access_denied':
        await _showPermissionDeniedDialog(context, _PermissionKind.photos);
      case 'no_available_camera':
        AppSnackbar.show(context, "This device doesn't have a camera available.");
      default:
        AppSnackbar.show(
          context,
          source == ImageSource.camera ? "Couldn't open the camera. Please try again." : "Couldn't open your photo library. Please try again.",
        );
    }
    return null;
  } catch (_) {
    if (context.mounted) AppSnackbar.show(context, "Couldn't load that image. Please try another one.");
    return null;
  }
}

enum _PermissionKind { camera, photos }

bool get _isIOS => !kIsWeb && io.Platform.isIOS;

Future<void> _showPermissionDeniedDialog(BuildContext context, _PermissionKind kind) {
  final isCamera = kind == _PermissionKind.camera;
  final what = isCamera ? 'camera' : 'photos';
  final steps = _isIOS
      ? 'Open Settings › CarRent and turn on ${isCamera ? 'Camera' : 'Photos'}.'
      : 'Open Settings › Apps › CarRent › Permissions and allow ${isCamera ? 'Camera' : 'Photos and videos'}.';

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(isCamera ? LucideIcons.cameraOff : LucideIcons.imageOff, color: AppColors.textSecondary),
      title: Text('Allow access to your $what'),
      content: Text(
        'CarRent needs ${isCamera ? 'camera access to take a photo' : 'access to your photos to choose an image'}. '
        'You previously declined, so you\'ll need to turn it on in Settings.\n\n$steps',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Not now')),
        // iOS has a public URL straight to this app's Settings page; Android
        // has no equivalent reachable via url_launcher, so it gets the
        // written steps above only.
        if (_isIOS)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              launchUrl(Uri.parse('app-settings:'));
            },
            child: const Text('Open Settings'),
          ),
      ],
    ),
  );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.sm),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: AppColors.accent),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
