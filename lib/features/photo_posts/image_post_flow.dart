import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/image/image_source_picker.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/utils/image_crop.dart';
import 'screens/image_editor_screen.dart';

/// The whole "Add Image" / "Post Image" flow from one call: source sheet →
/// camera/gallery → editor → preview → upload. Returns true once a photo
/// has been posted, false if the user backed out at any step.
///
/// Anything with an "add image" button can call this; nothing here is tied
/// to the feed screen.
Future<bool> startImagePostFlow(BuildContext context) async {
  final authorId = context.read<AuthService>().currentUser?.uid;
  if (authorId == null) return false;

  final source = await showImageSourceSheet(context, title: 'Post an image');
  if (source == null || !context.mounted) return false;

  final file = await pickImageFromSource(context, source);
  if (file == null || !context.mounted) return false;

  final PickedImage image;
  try {
    image = PickedImage(await file.readAsBytes(), file.name, path: file.path);
  } catch (_) {
    if (context.mounted) AppSnackbar.show(context, "Couldn't read that image. Please try another one.");
    return false;
  }
  if (!context.mounted) return false;

  // Root navigator so the full-screen editor covers the bottom nav too.
  final posted = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ImageEditorScreen(image: image, authorId: authorId),
    ),
  );
  return posted == true;
}
