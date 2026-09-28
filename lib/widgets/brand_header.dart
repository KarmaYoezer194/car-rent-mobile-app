import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/services/auth_service.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_text_styles.dart';
import '../models/user_model.dart';
import 'user_avatar.dart';
import '../core/widgets/motion/entrance.dart';

/// The top bar shared by the main tabs: amber car mark, "CarRent" with a
/// small amber section label under it ([subtitle], e.g. "EXPLORE"), then
/// the notifications bell (amber dot while anything is unread) and the
/// signed-in user's avatar, which jumps to the Profile tab.
///
/// Auth screens pass `showAccountActions: false` (no bell/avatar while
/// logged out) and optionally a [leading] back button.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.subtitle, this.showAccountActions = true, this.leading});

  final String subtitle;
  final bool showAccountActions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, AppSpacing.sm),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.sm)],
          const BrandMark(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CarRent', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
                Text(
                  subtitle.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (showAccountActions) ...[
            const _NotificationsBell(),
            const SizedBox(width: AppSpacing.sm),
            const _HeaderAvatar(),
          ],
        ],
      ),
    );
  }
}

/// The app's mark: a car glyph in amber on a soft amber tile.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Icon(LucideIcons.car, color: AppColors.accent, size: size * 0.55),
    );
  }
}

class _NotificationsBell extends StatelessWidget {
  const _NotificationsBell();

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;
    final notificationService = context.watch<NotificationService>();

    return PressFeedback(
      scale: 0.9,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Icon(LucideIcons.bell, color: AppColors.textPrimary, size: 22),
          ),
          if (uid != null)
            StreamBuilder<int>(
              stream: notificationService.streamUnreadCount(uid),
              builder: (context, snapshot) {
                if ((snapshot.data ?? 0) == 0) return const SizedBox.shrink();
                return Positioned(
                  top: 11,
                  right: 11,
                  child: IgnorePointer(
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 1.5),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar();

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final uid = authService.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return PressFeedback(
      scale: 0.9,
      child: GestureDetector(
        onTap: () => context.go('/profile'),
        child: StreamBuilder<UserModel?>(
          stream: authService.userDoc(uid),
          builder: (context, snapshot) => Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: UserAvatar(name: snapshot.data?.name ?? '', photoUrl: snapshot.data?.profileImage, size: 32),
          ),
        ),
      ),
    );
  }
}
