import 'package:flutter/material.dart';

import 'page_transitions.dart';

/// Holds the bottom-nav tabs' navigators (from `StatefulShellRoute`) and
/// animates between them when the tab changes instead of snapping like a
/// plain IndexedStack: a directional slide + fade. Tabs to the right of the
/// current one wait just off to the right, tabs to the left wait off to the
/// left — so Post → Bookings slides the new tab in from the right and
/// going back reverses it. Home keeps a gentle fade + rise instead.
///
/// Like an IndexedStack, every tab stays mounted, so each keeps its scroll
/// position and navigation stack. Hidden tabs ignore touches, are excluded
/// from accessibility, and have their animations paused.
class AnimatedBranchContainer extends StatelessWidget {
  const AnimatedBranchContainer({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.reduceMotion(context) ? Duration.zero : AppMotion.tabSwitch;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          _Branch(
            active: i == currentIndex,
            // Resting offset for inactive tabs: which side of the current
            // tab they sit on. Home (index 0) is the exception — it keeps
            // the original gentle fade + rise rather than a sideways slide.
            restOffset: i == 0 ? const Offset(0, 0.015) : Offset(i < currentIndex ? -0.08 : 0.08, 0),
            duration: duration,
            child: children[i],
          ),
      ],
    );
  }
}

class _Branch extends StatelessWidget {
  const _Branch({required this.active, required this.restOffset, required this.duration, required this.child});

  final bool active;
  final Offset restOffset;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeSemantics(
        excluding: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          curve: AppMotion.enter,
          child: AnimatedSlide(
            offset: active ? Offset.zero : restOffset,
            duration: duration,
            curve: AppMotion.enter,
            // Inside the fade, so the fade itself still animates while
            // the hidden tab's own animations are paused.
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
