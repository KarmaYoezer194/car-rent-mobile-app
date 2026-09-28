import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/car_options.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/car_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/post_service.dart';
import '../../../core/services/review_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/booking_model.dart';
import '../../../models/car_model.dart';
import '../../../models/review_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/brand_header.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/user_avatar.dart';
import '../../reviews/screens/my_reviews_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_photo_viewer_screen.dart';
import '../../../core/widgets/motion/entrance.dart';

/// Profile tab (Section 23) in the Obsidian Velocity layout: a profile
/// card, three stats, then grouped menu sections. Every number shown comes
/// from the user's own data (listings, bookings, favorites, reviews,
/// posts, notifications).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to log in again to continue."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Log Out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().signOut();
      // Router redirect (driven by authStateChanges) takes it from here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firebaseUser = authService.currentUser;
    final uid = firebaseUser?.uid;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const BrandHeader(subtitle: 'User Profile'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xs, AppSpacing.screen, AppSpacing.xl),
                children: [
                  if (uid == null)
                    const _GuestCard()
                  else
                    StreamBuilder<UserModel?>(
                      stream: authService.userDoc(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(height: 220, child: LoadingWidget());
                        }
                        final user = snapshot.data;
                        if (user == null) return const _GuestCard();
                        return _ProfileSummary(user: user, emailVerified: firebaseUser?.emailVerified ?? false)
                            .animate()
                            .fadeIn(duration: 380.ms)
                            .moveY(begin: -10, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
                      },
                    ),
                  if (uid != null) ...[
                    const _SectionLabel('Vehicle management'),
                    _MenuGroup(
                      children: [
                        _MenuRow(
                          icon: LucideIcons.car,
                          label: 'My Cars',
                          trailing: StreamBuilder<List<CarModel>>(
                            stream: context.watch<CarService>().streamCarsByOwner(uid),
                            builder: (context, snapshot) {
                              final active = (snapshot.data ?? const [])
                                  .where((c) => c.status == CarStatus.available)
                                  .length;
                              return _Pill(text: '$active active', color: AppColors.secondary);
                            },
                          ),
                          onTap: () => context.push('/my-cars'),
                        ),
                        _MenuRow(
                          icon: LucideIcons.images,
                          label: 'Photo Feed',
                          trailing: _CountText(
                            stream: context.watch<PostService>().streamPostCountByAuthor(uid),
                            format: (n) => '$n ${n == 1 ? 'photo' : 'photos'}',
                          ),
                          onTap: () => context.push('/feed'),
                        ),
                      ],
                    ),
                    const _SectionLabel('Activity & community'),
                    _MenuGroup(
                      children: [
                        _MenuRow(
                          icon: LucideIcons.heart,
                          label: 'Favorites',
                          trailing: _CountText(
                            stream: context.watch<CarService>().favoriteCarIds(uid).map((ids) => ids.length),
                            format: (n) => '$n saved',
                          ),
                          onTap: () => context.push('/favorites'),
                        ),
                        _MenuRow(
                          icon: LucideIcons.star,
                          label: 'My Reviews',
                          trailing: _CountText(
                            stream: context
                                .watch<ReviewService>()
                                .streamReviewsByRenter(uid)
                                .map((List<ReviewModel> r) => r.length),
                            format: (n) => '$n written',
                          ),
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyReviewsScreen())),
                        ),
                      ],
                    ),
                  ],
                  const _SectionLabel('Preferences & support'),
                  _MenuGroup(
                    children: [
                      _MenuRow(
                        icon: LucideIcons.bell,
                        label: 'Notifications',
                        subtitle: 'Trip updates and requests',
                        trailing: uid == null
                            ? null
                            : StreamBuilder<int>(
                                stream: context.watch<NotificationService>().streamUnreadCount(uid),
                                builder: (context, snapshot) {
                                  final unread = snapshot.data ?? 0;
                                  return unread == 0
                                      ? const SizedBox.shrink()
                                      : _Pill(text: '$unread new', color: AppColors.accent);
                                },
                              ),
                        onTap: () => context.push('/notifications'),
                      ),
                      _MenuRow(
                        icon: LucideIcons.settings,
                        label: 'Settings',
                        trailing: Text('Appearance & security', style: AppTextStyles.caption),
                        onTap: () => context.push('/settings'),
                      ),
                      _MenuRow(
                        icon: LucideIcons.headset,
                        label: 'Help & Support',
                        trailing: _Pill(text: 'FAQ & contact', color: AppColors.success),
                        onTap: () => context.push('/help-support'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MenuGroup(
                    children: [
                      _MenuRow(
                        icon: LucideIcons.logOut,
                        label: 'Logout',
                        danger: true,
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile card + stats.
class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.user, required this.emailVerified});

  final UserModel user;
  final bool emailVerified;

  @override
  Widget build(BuildContext context) {
    final carService = context.watch<CarService>();
    final bookingService = context.watch<BookingService>();

    return StreamBuilder<List<CarModel>>(
      stream: carService.streamCarsByOwner(user.uid),
      builder: (context, carsSnapshot) {
        final cars = carsSnapshot.data ?? const <CarModel>[];
        final available = cars.where((c) => c.status == CarStatus.available).length;

        // Role badge from real data: anyone with a listing is a host; a
        // host with a strong rating (4.5+ from 3+ reviews) is a premier host.
        final String role;
        if (cars.isEmpty) {
          role = 'Renter';
        } else if (user.reviewCount >= 3 && user.rating >= 4.5) {
          role = 'Premier Host';
        } else {
          role = 'Host';
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surfaceElevated, AppColors.surface],
                ),
              ),
              child: Row(
                children: [
                  _AvatarWithRing(user: user),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name.isEmpty ? 'CarRent user' : user.name,
                                style: AppTextStyles.h3.copyWith(fontSize: 19, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (emailVerified) ...[
                              const SizedBox(width: 5),
                              Tooltip(
                                message: 'Email verified',
                                child: Icon(LucideIcons.badgeCheck, size: 17, color: AppColors.secondary),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (user.reviewCount > 0) ...[
                              Icon(LucideIcons.star, size: 14, color: AppColors.star),
                              const SizedBox(width: 2),
                              Text(
                                user.rating.toStringAsFixed(1),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text('  ·  ', style: AppTextStyles.caption),
                            ],
                            Expanded(
                              child: Text(
                                user.email,
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppColors.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProfileScreen(user: user))),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(LucideIcons.pencil, size: 18, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<BookingModel>>(
                    stream: bookingService.streamBookingsForRenter(user.uid),
                    builder: (context, snapshot) {
                      final completed = (snapshot.data ?? const [])
                          .where((b) => b.status == BookingStatus.completed)
                          .length;
                      return _StatTile(
                        value: '$completed',
                        label: 'Completed rentals',
                        footnote: 'As renter',
                        footIcon: LucideIcons.clock,
                        footColor: AppColors.textMuted,
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatTile(
                    value: '${cars.length}',
                    label: 'Cars listed',
                    footnote: '$available available',
                    footIcon: LucideIcons.trendingUp,
                    footColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatTile(
                    value: user.reviewCount > 0 ? user.rating.toStringAsFixed(1) : '—',
                    valueIcon: user.reviewCount > 0 ? LucideIcons.star : null,
                    label: 'Host rating',
                    footnote: user.reviewCount > 0
                        ? '${user.reviewCount} ${user.reviewCount == 1 ? 'review' : 'reviews'}'
                        : 'No reviews yet',
                    footIcon: LucideIcons.messageSquareText,
                    footColor: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Profile photo in an amber ring with a green "signed in" dot. Tapping it
/// (when there's a photo) opens [ProfilePhotoViewerScreen] full-screen,
/// sharing a Hero tag for a grow-into-place transition.
class _AvatarWithRing extends StatelessWidget {
  const _AvatarWithRing({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final heroTag = 'profile_avatar_${user.uid}';
    final avatar = Stack(
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
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
            child: Hero(
              tag: heroTag,
              child: UserAvatar(name: user.name, photoUrl: user.profileImage, size: 60),
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
          ),
        ),
      ],
    );

    final photo = user.profileImage;
    if (photo == null || photo.isEmpty) return avatar;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfilePhotoViewerScreen(imageUrl: photo, heroTag: heroTag, name: user.name),
        ),
      ),
      child: avatar,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.footnote,
    required this.footIcon,
    required this.footColor,
    this.valueIcon,
  });

  final String value;
  final IconData? valueIcon;
  final String label;
  final String footnote;
  final IconData footIcon;
  final Color footColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: AppTextStyles.h3.copyWith(fontSize: 21, fontWeight: FontWeight.w800)),
              if (valueIcon != null) ...[const SizedBox(width: 2), Icon(valueIcon, size: 17, color: AppColors.star)],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(footIcon, size: 11, color: footColor),
                const SizedBox(width: 3),
                Text(
                  footnote,
                  style: AppTextStyles.caption.copyWith(color: footColor, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.xl, 4, AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 62, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.textPrimary;
    return PressFeedback(
      scale: 0.98,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: danger ? AppColors.dangerBg : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: danger ? AppColors.danger : AppColors.textPrimary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.bodyMedium.copyWith(color: fg, fontWeight: FontWeight.w700),
                      ),
                      if (subtitle != null) Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}

/// Muted trailing count ("12 saved") fed by a live count stream.
class _CountText extends StatelessWidget {
  const _CountText({required this.stream, required this.format});

  final Stream<int> stream;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) => snapshot.hasData
          ? Text(format(snapshot.data!), style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))
          : const SizedBox.shrink(),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surfaceElevated, shape: BoxShape.circle),
            child: Icon(LucideIcons.user, color: AppColors.textSecondary, size: 30),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guest user', style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.xs),
                Text('Sign in to see your profile', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
