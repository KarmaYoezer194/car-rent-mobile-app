import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';
import 'web_crop_dialog.dart';

/// `image_cropper` only ships plugin implementations for Android, iOS and
/// web — there's no Windows/macOS/Linux desktop implementation. Calling
/// [ImageCropper.cropImage] there throws a [MissingPluginException], which
/// upstream callers were catching and misreporting as an upload failure.
bool get imageCropperSupported => kIsWeb || io.Platform.isAndroid || io.Platform.isIOS;

/// Bytes + a filename for an image the user picked (and, via the functions
/// below, cropped) — the shape every picker in the app hands off to its
/// upload/save call, regardless of platform (`XFile`/`CroppedFile` aren't
/// usable directly on Flutter Web, but raw bytes are).
class PickedImage {
  const PickedImage(this.bytes, this.filename, {this.path});

  final Uint8List bytes;
  final String filename;

  /// Where [bytes] live on disk (or a blob URL on web), when known — lets
  /// the image editor hand the same pixels back to the cropper for a
  /// second crop without writing them out again.
  final String? path;
}

/// Opens the native crop UI (uCrop on Android, TOCropViewController on iOS)
/// on an already-picked [file]. Shared by [pickAndCropImage] (single-image
/// pickers) and the car-listing multi-image picker, which crops each file
/// in a loop after `pickMultiImage` returns.
///
/// [context] is only used to host the crop dialog on web (`WebUiSettings`
/// requires one — `image_cropper` throws "must provide WebUiSettings to run
/// on Web" without it); it's unused on Android/iOS. Call this before any
/// `await` that might unmount the caller, or guard with `mounted` first.
///
/// [circleCrop] locks the crop to a 1:1 circular mask (profile photos);
/// leave it false for a free-form rectangular crop (car photos). Returns
/// null if the user cancels the cropper — callers treat that as "skip this
/// photo" rather than falling back to the uncropped original.
Future<PickedImage?> cropPickedFile(
  XFile file, {
  required BuildContext context,
  bool circleCrop = false,
  String title = 'Crop Photo',
}) async {
  if (!imageCropperSupported) {
    // No cropper UI available on this platform — use the picked image as-is
    // rather than throwing.
    return PickedImage(await file.readAsBytes(), file.name, path: file.path);
  }
  return cropImageAtPath(file.path, filename: file.name, context: context, circleCrop: circleCrop, title: title);
}

/// The cropper call behind [cropPickedFile], for callers that already have
/// a path rather than an [XFile] — the image editor re-crops its current
/// image this way. Only call when [imageCropperSupported].
///
/// [compressQuality] is the JPEG quality of the cropped output; the editor
/// passes a high value since it compresses once more itself before upload,
/// and stacking two 85% passes visibly softens the photo.
Future<PickedImage?> cropImageAtPath(
  String path, {
  required String filename,
  required BuildContext context,
  bool circleCrop = false,
  String title = 'Crop Photo',
  int compressQuality = 85,
}) async {
  // Web crop area: up to 520x520, shrunk to leave room for the dialog's
  // padding, title and buttons on small windows.
  final screen = MediaQuery.sizeOf(context);
  final webCropSize = Size(
    (screen.width - 96).clamp(160, 520).toDouble(),
    (screen.height - 240).clamp(160, 520).toDouble(),
  );

  final cropped = await ImageCropper().cropImage(
    sourcePath: path,
    compressQuality: compressQuality,
    aspectRatio: circleCrop ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: title,
        toolbarColor: AppColors.primary,
        toolbarWidgetColor: AppColors.onPrimary,
        activeControlsWidgetColor: AppColors.accent,
        cropStyle: circleCrop ? CropStyle.circle : CropStyle.rectangle,
        lockAspectRatio: circleCrop,
      ),
      IOSUiSettings(
        title: title,
        cropStyle: circleCrop ? CropStyle.circle : CropStyle.rectangle,
        aspectRatioLockEnabled: circleCrop,
        resetAspectRatioEnabled: !circleCrop,
      ),
      WebUiSettings(
        context: context,
        presentStyle: WebPresentStyle.dialog,
        // Cropper.js's default (mode 0) lets the crop box extend past the
        // photo's edges; the overflow comes back filled white, so the photo
        // looks shrunk inside its frame and the output can be enormous.
        // Mode 1 keeps the crop box inside the image.
        viewwMode: WebViewMode.mode_1,
        size: CropperSize(width: webCropSize.width.round(), height: webCropSize.height.round()),
        // The package's built-in dialog breaks layout on current Flutter —
        // see WebCropDialog.
        customDialogBuilder: (cropper, initCropper, crop, rotate, scale) => WebCropDialog(
          cropper: cropper,
          initCropper: initCropper,
          crop: crop,
          rotate: rotate,
          scale: scale,
          width: webCropSize.width,
          height: webCropSize.height,
          title: title,
        ),
      ),
    ],
  );
  if (cropped == null) return null;

  final bytes = await cropped.readAsBytes();
  return PickedImage(bytes, filename, path: cropped.path);
}

/// Picks a single image from [source] and immediately crops it — the flow
/// behind every single-photo picker in the app (profile photo on register
/// and edit-profile). Returns null if the user cancels either step.
Future<PickedImage?> pickAndCropImage({
  required BuildContext context,
  required ImageSource source,
  bool circleCrop = false,
  String title = 'Crop Photo',
}) async {
  final picked = await ImagePicker().pickImage(source: source, maxWidth: 4096, maxHeight: 4096, imageQuality: 95);
  if (picked == null || !context.mounted) return null;
  if (!imageCropperSupported) return PickedImage(await picked.readAsBytes(), picked.name, path: picked.path);
  return cropImageAtPath(
    picked.path,
    filename: picked.name,
    context: context,
    circleCrop: circleCrop,
    title: title,
    // High quality here — the upload path compresses once more itself (see
    // AuthService._uploadProfileImage), and two 85% passes visibly soften.
    compressQuality: 95,
  );
}
