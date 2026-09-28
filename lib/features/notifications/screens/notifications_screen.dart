import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/motion/entrance.dart';
import '../../../models/notification_model.dart';
import '../../../widgets/loading_widget.dart';

/// Profile → Notifications (Section 15): the app's notification history.
/// There's no push delivery in this app (see README) — every row here is
/// the actual record of something that happened, not a copy of a push.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final notificationService = context.watch<NotificationService>();
    final uid = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => notificationService.markAllAsRead(uid),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: uid == null
          ? const EmptyStateWidget(icon: LucideIcons.bell, message: AppStrings.noNotifications)
          : StreamBuilder<List<NotificationModel>>(
              stream: notificationService.streamForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget();
                }
                if (snapshot.hasError) {
                  return const ErrorStateWidget(message: AppStrings.genericError);
                }
                final notifications = snapshot.data ?? const [];
                if (notifications.isEmpty) {
                  return const EmptyStateWidget(
                    icon: LucideIcons.bell,
                    message: AppStrings.noNotifications,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Entrance(
                      delay: Entrance.staggerDelay(index),
                      child: _NotificationTile(
                        notification: notification,
                        onTap: () {
                          if (!notification.read) notificationService.markAsRead(notification.id);
                          _openNotification(context, notification);
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// Routes to wherever a notification is actually about, so tapping one does
/// more than just mark it read. Every type here carries a booking id as
/// `relatedId` (see the `send()` call sites in `BookingService`/
/// `ReviewService`), so the Booking hub is the destination for all of
/// them — just on whichever tab the recipient would check:
/// - `bookingRequest`/`bookingCancelled`/`returnRequested` land on an
///   owner, who reviews requests and handovers against their own cars
///   under "My Cars" (tab 1).
/// - `bookingAccepted`/`bookingRejected`/`rentalCompleted` land on the
///   renter who made the request, tracked under "Renting" (tab 0).
/// - `newReview` lands on the owner whose car got reviewed; there's no
///   "reviews I received" screen, so "My Cars" is the closest match.
void _openNotification(BuildContext context, NotificationModel notification) {
  if (notification.relatedId == null) return;

  final ownerFacing = {
    NotificationType.bookingRequest,
    NotificationType.bookingCancelled,
    NotificationType.returnRequested,
    NotificationType.newReview,
  };
  final tabIndex = ownerFacing.contains(notification.type) ? 1 : 0;
  context.go('/booking', extra: tabIndex);
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationModel notification;
  final VoidCallback onTap;

  static final _dateFormat = DateFormat('MMM d, h:mm a');

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.bookingRequest:
        return LucideIcons.fileText;
      case NotificationType.bookingAccepted:
        return LucideIcons.circleCheck;
      case NotificationType.bookingRejected:
      case NotificationType.bookingCancelled:
        return LucideIcons.circleX;
      case NotificationType.returnRequested:
        return LucideIcons.undo2;
      case NotificationType.rentalCompleted:
        return LucideIcons.flag;
      case NotificationType.newReview:
        return LucideIcons.star;
      default:
        return LucideIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.read ? AppColors.surface : AppColors.infoBg.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                child: Icon(_icon, color: AppColors.accent, size: 19),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: AppTextStyles.titleMedium.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(notification.message, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 5),
                    Text(_dateFormat.format(notification.createdAt), style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (!notification.read)
                Container(
                  margin: const EdgeInsets.only(top: 6, left: AppSpacing.sm),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.85, end: 1.25, duration: 900.ms, curve: Curves.easeInOut),
            ],
          ),
        ),
      ),
    );
  }
}
