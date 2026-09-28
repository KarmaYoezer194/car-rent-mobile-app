import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';

/// Settings › Change password, for a signed-in user who knows their
/// current password. (Forgotten it? The link at the bottom emails a reset
/// link to the account's address, same as the login screen's flow.)
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _isSaving = false;
  bool _isSendingReset = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    final authService = context.read<AuthService>();
    try {
      await authService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      AppSnackbar.show(context, 'Password updated. Use your new password next time you log in.');
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Re-authentication failing means the *current* password is wrong —
      // the generic "incorrect email or password" copy would mislead here.
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Your current password is incorrect.',
        'weak-password' => 'Choose a stronger new password (at least 6 characters).',
        _ => authService.friendlyError(e),
      };
      AppSnackbar.show(context, message);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendResetEmail() async {
    final authService = context.read<AuthService>();
    final email = authService.currentUser?.email;
    if (email == null) return;
    setState(() => _isSendingReset = true);
    try {
      await authService.sendPasswordResetEmail(email);
      if (mounted) AppSnackbar.show(context, 'Reset link sent to $email. Check your spam folder if it doesn\'t arrive.');
    } catch (e) {
      if (mounted) AppSnackbar.show(context, authService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Widget _visibilityToggle() => IconButton(
        icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff, color: AppColors.textMuted, size: 20),
        tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
        onPressed: () => setState(() => _obscure = !_obscure),
      );

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthService>().currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'For your security, enter your current password before choosing a new one.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('Account: $email', style: AppTextStyles.caption),
                ],
                const SizedBox(height: AppSpacing.xl),
                CustomTextField(
                  label: 'Current password',
                  hint: 'Enter your current password',
                  controller: _currentController,
                  obscureText: _obscure,
                  prefixIcon: LucideIcons.lock,
                  suffixIcon: _visibilityToggle(),
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.isEmpty) ? 'Enter your current password' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                CustomTextField(
                  label: 'New password',
                  hint: 'At least 6 characters',
                  controller: _newController,
                  obscureText: _obscure,
                  prefixIcon: LucideIcons.rotateCcwKey,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.length < 6) return 'Use at least 6 characters';
                    if (value == _currentController.text) return 'Choose a password different from your current one';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                CustomTextField(
                  label: 'Confirm new password',
                  hint: 'Type it again',
                  controller: _confirmController,
                  obscureText: _obscure,
                  prefixIcon: LucideIcons.rotateCcwKey,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  validator: (value) => value != _newController.text ? "Passwords don't match" : null,
                ),
                const SizedBox(height: AppSpacing.xxl),
                CustomButton(label: 'Update Password', isLoading: _isSaving, onPressed: _save),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: _isSendingReset || _isSaving ? null : _sendResetEmail,
                    child: Text(_isSendingReset ? 'Sending…' : 'Forgot your current password? Email me a reset link'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
