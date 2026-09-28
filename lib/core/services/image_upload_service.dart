import 'dart:typed_data';

/// Abstraction over "upload these image bytes, get back a public URL".
///
/// Takes raw bytes rather than a `dart:io File` deliberately — `File` isn't
/// supported on Flutter Web (image_picker's `XFile` there wraps a Blob, not
/// a real filesystem path), so every caller reads bytes via
/// `XFile.readAsBytes()` first. That works identically on web, mobile, and
/// desktop.
///
/// The app is on the Firebase Spark (free) plan, and Firebase Storage now
/// requires the paid Blaze plan even for the free-tier quota — so uploads
/// go to Cloudinary instead (see [CloudinaryImageUploadService]). Every
/// feature that uploads an image (profile photos in Phase 2, car photos in
/// Phase 4) should depend on this interface, not on a specific provider, so
/// switching to Firebase Storage later — if the project ever moves to
/// Blaze — is a one-file change: implement this interface and swap what's
/// provided in `main.dart`.
/// Reports upload progress as a fraction from 0 to 1.
typedef UploadProgressCallback = void Function(double progress);

abstract class ImageUploadService {
  /// Uploads [bytes] and returns the public download URL. [filename] is
  /// used for content-type/extension hints; [folder] groups uploads the
  /// way Storage paths would have (e.g. `profile_images`, `car_images`) —
  /// providers that support folders use it for organization, otherwise
  /// it's safe to ignore.
  ///
  /// [onProgress], if given, is called as bytes are sent. Implementations
  /// that can't observe progress may simply call it once with 1.0.
  Future<String> uploadImage(
    Uint8List bytes, {
    required String filename,
    required String folder,
    UploadProgressCallback? onProgress,
  });
}
