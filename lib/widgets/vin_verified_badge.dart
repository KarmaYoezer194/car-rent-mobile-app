import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

/// Small "VIN verified" pill — shown on the listing preview and Car Details
/// instead of the VIN itself, which the app never displays.
class VinVerifiedBadge extends StatelessWidget {
  const VinVerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.success),
          const SizedBox(width: 4),
          Text('VIN verified', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
