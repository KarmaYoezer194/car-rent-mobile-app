import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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
import '../../../widgets/brand_accents.dart';
import '../../../widgets/brand_header.dart';
import '../../../widgets/custom_text_field.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/social_login_buttons.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Read once at pick time (via XFile.readAsBytes(), which works on web,
  // mobile, and desktop alike) rather than keeping a `dart:io File` around —
  // File isn't supported on Flutter Web.
  Uint8List? _profileImageBytes;
  String _profileImageFilename = 'profile.jpg';
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final picked = await pickAndCropImage(
        context: context,
        source: ImageSource.gallery,
        circleCrop: true,
        title: 'Crop Profile Photo',
      );
      if (picked == null) return;
      setState(() {
        _profileImageBytes = picked.bytes;
        _profileImageFilename = picked.filename;
      });
    } catch (e) {
      if (mounted) AppSnackbar.show(context, "Couldn't open your photo library.");
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    try {
      await authService.registerWithEmail(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        profileImageBytes: _profileImageBytes,
        profileImageFilename: _profileImageFilename,
      );
      // Router redirect (driven by authStateChanges) takes it from here.
    } catch (e) {
      if (mounted) AppSnackbar.show(context, authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Back to Log In. Register is usually pushed on top of Login, but
  /// onboarding's "Get Started" opens it as the first page — with nothing
  /// underneath, a plain pop() would throw, so go to /login instead.
  void _toLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            BrandHeader(
              subtitle: 'Create account',
              showAccountActions: false,
              leading: IconButton(
                tooltip: 'Back to log in',
                onPressed: _toLogin,
                icon: Icon(LucideIcons.chevronLeft, size: 18, color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Entrance(
                        delay: Duration(milliseconds: 40),
                        child: TwoToneHeadline(lead: 'Create your ', highlight: 'account.'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Entrance(
                        delay: 80.ms,
                        child: Text(
                          'Rent cars nearby or list your own — it only takes a minute.',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        delay: 120.ms,
                        child: Row(
                          children: [
                            _ProfileImagePicker(imageBytes: _profileImageBytes, onTap: _pickProfileImage),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profileImageBytes == null ? 'Add a profile photo' : 'Looking good!',
                                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _profileImageBytes == null
                                        ? 'Optional — helps hosts and renters recognise you.'
                                        : 'Tap the photo to change it.',
                                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        delay: 160.ms,
                        child: AuthFormCard(
                          children: [
                            CustomTextField(
                              label: 'Full name',
                              hint: 'Jane Doe',
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              prefixIcon: LucideIcons.user,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [CapitalizeWordsFormatter()],
                              validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your full name' : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CustomTextField(
                              label: 'Email',
                              hint: 'you@example.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              prefixIcon: LucideIcons.mail,
                              enableSpellCheck: false,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) return 'Enter your email';
                                if (!value.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CustomTextField(
                              label: 'Phone number',
                              hint: '08X-XXX-XXXX',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              prefixIcon: LucideIcons.phone,
                              validator: (value) => (value == null || value.trim().isEmpty) ? 'Enter your phone number' : null,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CustomTextField(
                              label: 'Password',
                              hint: 'At least 6 characters',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              prefixIcon: LucideIcons.lock,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword ? 'Show passwords' : 'Hide passwords',
                                icon: Icon(
                                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Enter a password';
                                if (value.length < 6) return 'At least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CustomTextField(
                              label: 'Confirm password',
                              hint: 'Re-enter your password',
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              prefixIcon: LucideIcons.lock,
                              validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        delay: 220.ms,
                        child: GlowButton(label: 'Create Account', isLoading: _isLoading, onPressed: _submit),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Entrance(delay: 260.ms, child: SocialLoginButtons(enabled: !_isLoading)),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                          TextButton(
                            onPressed: _toLogin,
                            child: Text(
                              'Log In',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile photo picker in an amber ring, with a camera badge.
class _ProfileImagePicker extends StatelessWidget {
  const _ProfileImagePicker({required this.imageBytes, required this.onTap});

  final Uint8List? imageBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: imageBytes == null ? 'Add profile photo' : 'Change profile photo',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.secondary, AppColors.primary]),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.surfaceElevated,
                  backgroundImage: imageBytes != null ? MemoryImage(imageBytes!) : null,
                  child: imageBytes == null ? Icon(LucideIcons.user, color: AppColors.textSecondary, size: 34) : null,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.background, width: 2),
                ),
                child: Icon(LucideIcons.camera, color: AppColors.onPrimary, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
