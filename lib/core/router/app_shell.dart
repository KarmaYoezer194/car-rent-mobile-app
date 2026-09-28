import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/booking_model.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../theme/app_text_styles.dart';
import '../widgets/motion/entrance.dart';

/// Bottom-nav scaffold shared by the four main tabs (Section 3).
///
/// Wrapped around a [StatefulShellRoute] branch by [AppRouter], so each tab
/// keeps its own navigation stack and scroll position when switching away
/// and back.
///
/// Obsidian Velocity styling: the active tab's icon and label turn amber
/// with a short amber bar under them. Bookings carries a count badge for
/// booking requests on the user's cars that still need an answer
/// (`pending`) — the one thing in that tab that's waiting on them.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the already-active tab pops it back to its root screen
      // instead of doing nothing.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  static const _tabs = [
    (icon: LucideIcons.car, activeIcon: LucideIcons.car, label: AppStrings.navHome),
    (icon: LucideIcons.circlePlus, activeIcon: LucideIcons.circlePlus, label: AppStrings.navPost),
    (icon: LucideIcons.calendarDays, activeIcon: LucideIcons.calendarDays, label: AppStrings.navBooking),
    (icon: LucideIcons.user, activeIcon: LucideIcons.user, label: AppStrings.navProfile),
  ];

  static const _bookingsTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().currentUser?.uid;
    final bookingService = context.watch<BookingService>();

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 66,
            child: StreamBuilder<List<BookingModel>>(
              stream: uid == null ? const Stream.empty() : bookingService.streamBookingsForOwner(uid),
              builder: (context, snapshot) {
                final pendingRequests = (snapshot.data ?? const [])
                    .where((b) => b.status == BookingStatus.pending)
                    .length;
                return Row(
                  children: List.generate(_tabs.length, (index) {
                    final tab = _tabs[index];
                    return Expanded(
                      child: _NavItem(
                        icon: tab.icon,
                        activeIcon: tab.activeIcon,
                        label: tab.label,
                        selected: index == navigationShell.currentIndex,
                        badgeCount: index == _bookingsTabIndex ? pendingRequests : 0,
                        onTap: () => _onTap(index),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textMuted;
    return PressFeedback(
      scale: 0.9,
      child: Semantics(
        label: badgeCount > 0 ? '$label, $badgeCount waiting' : label,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(selected ? activeIcon : icon, key: ValueKey(selected), color: color, size: 23),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -5,
                      right: -9,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 17),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.surface, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 18 : 0,
                height: 3,
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
