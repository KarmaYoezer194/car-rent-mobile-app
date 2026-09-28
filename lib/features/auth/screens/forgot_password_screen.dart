import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../widgets/brand_accents.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';

/// "Forgot password?" from the login screen: sends a Firebase password
/// reset email. The link in it opens Firebase's hosted reset page, where
/// the user picks a new password; on web that page then offers a
/// "Continue" button back to this app's login (see
/// AuthService.sendPasswordResetEmail).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendCooldown = 60;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _sent = false;

  /// Seconds until "Resend" is allowed again — Firebase rate-limits reset
  /// emails, and hammering the button only earns a too-many-requests error.
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send({bool isResend = false}) async {
    if (!isResend && !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = context.read<AuthService>();
    try {
      await authService.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() => _sent = true);
      _startCooldown();
      if (isResend) AppSnackbar.show(context, 'Sent again.');
    } catch (e) {
      if (mounted) AppSnackbar.show(context, authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) timer.cancel();
    });
  }

  void _useDifferentEmail() {
    _cooldownTimer?.cancel();
    setState(() {
      _sent = false;
      _cooldown = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _sent
              ? _SentConfirmation(
                  email: _emailController.text.trim(),
                  cooldown: _cooldown,
                  isResending: _isLoading,
                  onResend: () => _send(isResend: true),
                  onUseDifferentEmail: _useDifferentEmail,
                )
              : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
              ),
              child: Icon(LucideIcons.rotateCcwKey, color: AppColors.onPrimary, size: 28),
            ),
          ).animate().scaleXY(begin: 0.6, end: 1, duration: 420.ms, curve: Curves.easeOutBack).fadeIn(duration: 280.ms),
          const SizedBox(height: AppSpacing.lg),
          const Entrance(delay: Duration(milliseconds: 80), child: TwoToneHeadline(lead: 'Forgot your ', highlight: 'password?')),
          const SizedBox(height: AppSpacing.sm),
          Entrance(
            delay: 120.ms,
            child: Text(
              "Enter the email you log in with and we'll send you a link to reset your password.",
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Entrance(
            delay: 180.ms,
            child: CustomTextField(
              label: 'Email',
              hint: 'you@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _send(),
              prefixIcon: LucideIcons.mail,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email';
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Entrance(delay: 240.ms, child: CustomButton(label: 'Send Reset Link', isLoading: _isLoading, onPressed: _send)),
          const SizedBox(height: AppSpacing.lg),
          Entrance(
            delay: 280.ms,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.info, size: 16, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Signed up with Google, Apple or Facebook? Your account has no CarRent password — use the matching "Continue with…" button on the login screen.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({
    required this.email,
    required this.cooldown,
    required this.isResending,
    required this.onResend,
    required this.onUseDifferentEmail,
  });

  final String email;
  final int cooldown;
  final bool isResending;
  final VoidCallback onResend;
  final VoidCallback onUseDifferentEmail;

  @override
  Widget build(BuildContext context) {
    // Firebase sends reset emails from noreply@<project>.firebaseapp.com —
    // naming it helps people find it (or whitelist it) in spam.
    final sender = 'noreply@${Firebase.app().options.projectId}.firebaseapp.com';

    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
          child: Icon(LucideIcons.mailCheck, color: AppColors.success, size: 44),
        ).animate().scaleXY(begin: 0.4, end: 1, duration: 500.ms, curve: Curves.easeOutBack).fadeIn(duration: 300.ms),
        const SizedBox(height: AppSpacing.lg),
        Entrance(delay: 150.ms, child: Text('Check your email', style: AppTextStyles.h2, textAlign: TextAlign.center)),
        const SizedBox(height: AppSpacing.sm),
        Entrance(
          delay: 200.ms,
          child: Text(
            // Worded as "if" on purpose: Firebase doesn't reveal whether an
            // account exists, so an unregistered address gets no email.
            'If an account exists for $email, a link to reset its password is on its way.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Entrance(
          delay: 240.ms,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Tip(icon: LucideIcons.user, text: 'It comes from $sender.'),
                const _Tip(icon: LucideIcons.mailWarning, text: "Not there after a few minutes? Check your spam or junk folder."),
                const _Tip(icon: LucideIcons.link, text: 'Open the link, choose a new password, then log in with it.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Entrance(
          delay: 280.ms,
          child: CustomButton(label: 'Back to Log In', onPressed: () => Navigator.of(context).pop()),
        ),
        const SizedBox(height: AppSpacing.sm),
        Entrance(
          delay: 300.ms,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: cooldown > 0 || isResending ? null : onResend,
                child: Text(cooldown > 0 ? 'Resend in ${cooldown}s' : (isResending ? 'Sending…' : 'Resend email')),
              ),
              Text('·', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
              TextButton(onPressed: isResending ? null : onUseDifferentEmail, child: const Text('Use a different email')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}
