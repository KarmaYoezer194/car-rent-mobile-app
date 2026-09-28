import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/theme_controller.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_snackbar.dart';
import 'change_password_screen.dart';
import '../../../core/widgets/motion/entrance.dart';

/// App-wide settings — appearance and account security (Section 23's
/// "Settings" menu tile). Kept as its own screen rather than a dialog so there's a
/// natural home for future preferences (units, language, etc.).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Appearance', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Choose how CarRent looks on this device.', style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
              boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(
              children: [
                _ThemeOptionTile(
                  icon: LucideIcons.sun,
                  label: 'Light',
                  selected: themeController.mode == ThemeMode.light,
                  onTap: () => themeController.setMode(ThemeMode.light),
                ),
                Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg, color: AppColors.divider),
                _ThemeOptionTile(
                  icon: LucideIcons.moon,
                  label: 'Dark',
                  selected: themeController.mode == ThemeMode.dark,
                  onTap: () => themeController.setMode(ThemeMode.dark),
                ),
                Divider(height: 1, indent: AppSpacing.lg, endIndent: AppSpacing.lg, color: AppColors.divider),
                _ThemeOptionTile(
                  icon: LucideIcons.sunMoon,
                  label: 'System default',
                  selected: themeController.mode == ThemeMode.system,
                  onTap: () => themeController.setMode(ThemeMode.system),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 340.ms).moveY(begin: 14, end: 0, duration: 340.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: AppSpacing.xl),
          Text('Account', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xxl),
                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, 4))],
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openChangePassword(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(LucideIcons.rectangleEllipsis, size: 20, color: AppColors.textSecondary),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Change password',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, color: AppColors.border),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 80.ms, duration: 340.ms)
              .moveY(begin: 14, end: 0, delay: 80.ms, duration: 340.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  void _openChangePassword(BuildContext context) {
    // Accounts created only with Google/Apple/Facebook have
    // no CarRent password to change — say so instead of showing a form
    // that could never succeed.
    if (!context.read<AuthService>().hasPasswordLogin) {
      AppSnackbar.show(
        context,
        "You sign in with Google, Apple or Facebook, so there's no CarRent password to change.",
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressFeedback(
      scale: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryLight.withValues(alpha: 0.5) : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? AppColors.accent : AppColors.textSecondary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                    child: child,
                  ),
                  child: selected
                      ? Icon(LucideIcons.circleCheck, size: 20, color: AppColors.accent, key: const ValueKey(true))
                      : const SizedBox(width: 20, height: 20, key: ValueKey(false)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
