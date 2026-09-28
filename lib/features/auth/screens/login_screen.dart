import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../widgets/brand_accents.dart';
import '../../../widgets/brand_header.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/custom_text_field.dart';
import '../widgets/auth_form_card.dart';
import '../widgets/social_login_buttons.dart';

/// Log in — Obsidian Velocity layout: brand bar, a photo hero, the
/// two-tone headline, the email/password form on a card, the glowing
/// amber CTA, then social sign-in and a link to Register.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // The source photo is portrait; this asks Unsplash for a 16:9 crop
  // centred on the car (focal point 60% down) so the whole car fits the
  // landscape banner instead of being cut in half.
  static const _heroImage =
      'https://images.unsplash.com/photo-1614200187524-dc4b892acf16'
      '?auto=format&fit=crop&w=1200&h=675&crop=focalpoint&fp-x=0.5&fp-y=0.6&q=85';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    try {
      await authService.signInWithEmail(email: _emailController.text.trim(), password: _passwordController.text);
      // No explicit navigation here: the router's redirect (driven by
      // authStateChanges) takes over as soon as sign-in succeeds.
    } catch (e) {
      if (mounted) AppSnackbar.show(context, authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const BrandHeader(subtitle: 'Welcome back', showAccountActions: false),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(imageUrl: _heroImage)
                          .animate()
                          .fadeIn(duration: 420.ms)
                          .scaleXY(begin: 0.96, end: 1, duration: 420.ms, curve: Curves.easeOutCubic),
                      const SizedBox(height: AppSpacing.xl),
                      const Entrance(
                        delay: Duration(milliseconds: 80),
                        child: TwoToneHeadline(lead: 'Welcome ', highlight: 'back.'),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Entrance(
                        delay: 120.ms,
                        child: Text(
                          'Log in to continue to ${AppStrings.appName}.',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        delay: 180.ms,
                        child: AuthFormCard(
                          children: [
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
                              label: 'Password',
                              hint: 'Enter your password',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              prefixIcon: LucideIcons.lock,
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                icon: Icon(
                                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.push('/forgot-password'),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Entrance(
                        delay: 240.ms,
                        child: GlowButton(label: 'Log In', isLoading: _isLoading, onPressed: _submit),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Entrance(
                        delay: 300.ms,
                        child: SocialLoginButtons(enabled: !_isLoading),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () => context.push('/register'),
                            child: Text(
                              'Register',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 340.ms, duration: 300.ms),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    // Same 16:9 shape as the image at every width, so it's never cropped
    // further (a fixed height cut the car off on wide windows).
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedImage(url: imageUrl, iconSize: 48),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Just a soft edge — the tag sits at the top with its own
                // backdrop, so the car itself stays un-darkened.
                stops: const [0.7, 1],
                  colors: [Colors.transparent, AppColors.navy.withValues(alpha: 0.45)],
                ),
              ),
            ),
            // Top-left, over the garage wall — bottom-left sat on the car.
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.overlayAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.keyRound, size: 14, color: AppColors.overlayAccent),
                    const SizedBox(width: 6),
                    Text(
                      'Rent nearby · List your own',
                      style: AppTextStyles.caption.copyWith(color: AppColors.overlayText, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
