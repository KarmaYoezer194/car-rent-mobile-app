import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/motion/entrance.dart';

/// "or continue with" divider plus one button per [SocialProvider], shared
/// by Login and Register — a first social sign-in *is* registration, since
/// [AuthService.signInWithSocial] creates the profile itself.
///
/// No navigation on success: the router's redirect (driven by
/// authStateChanges) takes over, same as email login.
class SocialLoginButtons extends StatefulWidget {
  const SocialLoginButtons({super.key, this.enabled = true});

  /// False while the surrounding email form is submitting.
  final bool enabled;

  @override
  State<SocialLoginButtons> createState() => _SocialLoginButtonsState();
}

class _SocialLoginButtonsState extends State<SocialLoginButtons> {
  SocialProvider? _loading;

  Future<void> _signIn(SocialProvider provider) async {
    setState(() => _loading = provider);
    final authService = context.read<AuthService>();
    try {
      await authService.signInWithSocial(provider);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text('or continue with', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // One compact row — three full-width buttons pushed the rest of
        // the auth form below the fold on small phones.
        Row(
          children: [
            for (final provider in SocialProvider.values) ...[
              if (provider != SocialProvider.values.first) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SocialButton(
                  provider: provider,
                  isLoading: _loading == provider,
                  onPressed: widget.enabled && _loading == null ? () => _signIn(provider) : null,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.provider, required this.isLoading, required this.onPressed});

  final SocialProvider provider;
  final bool isLoading;
  final VoidCallback? onPressed;

  Widget _logo() {
    switch (provider) {
      case SocialProvider.google:
        // Material Icons has no Google "G"; a bold G in Google blue reads
        // as the mark without bundling a brand asset.
        return Text(
          'G',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.googleBlue, height: 1),
        );
      case SocialProvider.apple:
        return Icon(Icons.apple, size: 22, color: AppColors.textPrimary);
      case SocialProvider.facebook:
        return Icon(Icons.facebook, size: 22, color: AppColors.facebookBlue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      scale: 0.96,
      child: Tooltip(
        message: 'Continue with ${provider.label}',
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            backgroundColor: AppColors.surface,
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 22, child: Center(child: _logo())),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        provider.label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
