import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/image_crop.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/user_model.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';

/// Lets the signed-in user update their name, phone, and profile photo
/// (Section 23's profile-header edit icon). Email is read-only here —
/// changing it needs re-authentication, which is out of scope for now.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _phoneController = TextEditingController(text: widget.user.phone);

  // Only set once the user picks a new photo; null means "keep the existing
  // one" rather than "no photo", so we don't accidentally overwrite it.
  Uint8List? _newImageBytes;
  String _newImageFilename = 'profile.jpg';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    try {
      final picked = await pickAndCropImage(
        context: context,
        source: source,
        circleCrop: true,
        title: 'Crop Profile Photo',
      );
      if (picked == null) return;
      setState(() {
        _newImageBytes = picked.bytes;
        _newImageFilename = picked.filename;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          source == ImageSource.camera ? "Couldn't open the camera." : "Couldn't open your photo library.",
        );
      }
    }
  }

  /// Bottom sheet letting the user pick a new profile photo from the camera
  /// or their gallery, rather than always defaulting to one or the other.
  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Update profile photo', style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
            _ImageSourceTile(
              icon: LucideIcons.camera,
              label: 'Take a photo',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            _ImageSourceTile(
              icon: LucideIcons.images,
              label: 'Choose from gallery',
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final authService = context.read<AuthService>();
    try {
      await authService.updateProfile(
        uid: widget.user.uid,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        profileImageBytes: _newImageBytes,
        profileImageFilename: _newImageFilename,
      );
      if (mounted) {
        AppSnackbar.show(context, 'Profile updated.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Profile update failed: $e');
      if (mounted) AppSnackbar.show(context, authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: _ProfileImagePicker(
                    newImageBytes: _newImageBytes,
                    existingImageUrl: widget.user.profileImage,
                    fallbackLetter: widget.user.name.isNotEmpty ? widget.user.name.substring(0, 1).toUpperCase() : '?',
                    onTap: _pickImage,
                  ).animate().scaleXY(begin: 0.7, end: 1, duration: 420.ms, curve: Curves.easeOutBack).fadeIn(duration: 280.ms),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Entrance(
                  delay: 60.ms,
                  child: CustomTextField(
                    label: 'Full name',
                    hint: 'Jane Doe',
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    prefixIcon: LucideIcons.user,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [CapitalizeWordsFormatter()],
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter your full name' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Entrance(
                  delay: 100.ms,
                  child: CustomTextField(
                    label: 'Email',
                    controller: TextEditingController(text: widget.user.email),
                    enabled: false,
                    prefixIcon: LucideIcons.mail,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Entrance(
                  delay: 140.ms,
                  child: CustomTextField(
                    label: 'Phone number',
                    hint: '08X-XXX-XXXX',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    prefixIcon: LucideIcons.phone,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Enter your phone number' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Entrance(delay: 180.ms, child: CustomButton(label: 'Save Changes', isLoading: _isSaving, onPressed: _save)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageSourceTile extends StatelessWidget {
  const _ImageSourceTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileImagePicker extends StatelessWidget {
  const _ProfileImagePicker({
    required this.newImageBytes,
    required this.existingImageUrl,
    required this.fallbackLetter,
    required this.onTap,
  });

  // Twice the old CircleAvatar radius (44) as a diameter, so this reads
  // identically on screen.
  static const double _diameter = 88;

  final Uint8List? newImageBytes;
  final String? existingImageUrl;
  final String fallbackLetter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Built with ClipOval + Image/CachedNetworkImage directly rather than
    // CircleAvatar's backgroundImage — CircleAvatar has no filterQuality
    // knob, so it always samples at FilterQuality.low, which visibly
    // softened/pixelated the photo at this display size (Section 23 bug
    // report). `high` uses bicubic sampling instead, which is the
    // difference between "clean edges" and "blocky" when this 88px circle
    // is scaled up to a 2-3x device pixel ratio.
    Widget content;
    if (newImageBytes != null) {
      content = Image.memory(
        newImageBytes!,
        width: _diameter,
        height: _diameter,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    } else if (existingImageUrl != null) {
      content = CachedNetworkImage(
        imageUrl: existingImageUrl!,
        width: _diameter,
        height: _diameter,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        // Decode at (roughly) the pixels this circle actually needs on
        // this device rather than the source's full resolution — keeps
        // memory use sane without capping how sharp the image can look.
        memCacheWidth: (_diameter * MediaQuery.of(context).devicePixelRatio).round(),
        placeholder: (context, url) => const ColoredBox(color: Colors.transparent),
        errorWidget: (context, url, error) => _FallbackAvatar(letter: fallbackLetter),
      );
    } else {
      content = _FallbackAvatar(letter: fallbackLetter);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            ClipOval(
              child: ColoredBox(
                color: AppColors.primaryLight,
                child: SizedBox(width: _diameter, height: _diameter, child: content),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Icon(LucideIcons.camera, color: AppColors.onPrimary, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(letter, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.accent)),
    );
  }
}
