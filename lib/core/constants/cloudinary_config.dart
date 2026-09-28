/// Cloudinary account details used by [CloudinaryImageUploadService].
///
/// Both values come from your free Cloudinary dashboard:
/// - [cloudName]: shown on the Dashboard home page.
/// - [unsignedUploadPreset]: Settings → Upload → Upload presets → an entry
///   with Signing Mode = "Unsigned". Unsigned presets are safe to ship in
///   the app (that's the point of "unsigned" — no secret key involved),
///   unlike your Cloudinary API secret, which must never appear in
///   client code.
///
class CloudinaryConfig {
  CloudinaryConfig._();

  static const String cloudName = 'hcrar4ku';
  static const String unsignedUploadPreset = 'carrent_unsigned';
}
