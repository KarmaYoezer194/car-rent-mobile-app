import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shared entrance-motion vocabulary for the whole app, built on
/// [flutter_animate] so every screen fades/slides in the same way instead
/// of each one hand-rolling its own [AnimationController].
///
/// Two building blocks:
///  * [Entrance] — a single widget's "fade up" arrival, with an optional
///    stagger [delay].
///  * [staggerDelay] — the per-index delay a `ListView.builder`/`GridView`
///    item should pass to [Entrance] so a list cascades in top-to-bottom
///    instead of every card popping in at once.
class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 18,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration delay;
  final double offsetY;
  final Duration duration;

  /// Caps the stagger so a long list doesn't leave item #30 waiting nearly
  /// a second to appear — everything past the 8th item arrives together.
  static Duration staggerDelay(int index, {Duration step = const Duration(milliseconds: 45)}) {
    final capped = index.clamp(0, 8);
    return step * capped;
  }

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: Curves.easeOutCubic)
        .moveY(begin: offsetY, end: 0, duration: duration, curve: Curves.easeOutCubic);
  }
}

/// Wraps a tappable child (a card, a button, a chip) so it responds to the
/// pointer: on hover (mouse/trackpad) it lifts a few pixels and grows
/// slightly, with a pointer cursor; on tap-down it presses in; on release it
/// springs back. Applied anywhere a whole surface is tappable, so the app
/// feels responsive everywhere at once.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.hoverScale = 1.015,
    this.hoverLift = 3,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Scale while pressed.
  final double scale;

  /// Scale and upward lift (logical px) while hovered.
  final double hoverScale;
  final double hoverLift;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: _PointerMotion(
          pressed: enabled && _pressed,
          hovered: enabled && _hovered,
          pressScale: widget.scale,
          hoverScale: widget.hoverScale,
          hoverLift: widget.hoverLift,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Same press + hover motion as [Pressable], but observes raw pointer
/// events via [Listener]/[MouseRegion] instead of competing for the tap
/// gesture — for wrapping a child that already handles its own tap (an
/// [ElevatedButton], a chip, an [InkWell]) so the motion and the child's
/// own ripple/callback never fight over the same gesture.
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.hoverScale = 1.02,
    this.hoverLift = 0,
  });

  final Widget child;
  final double scale;
  final double hoverScale;
  final double hoverLift;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: _PointerMotion(
          pressed: _pressed,
          hovered: _hovered,
          pressScale: widget.scale,
          hoverScale: widget.hoverScale,
          hoverLift: widget.hoverLift,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The shared animation behind [Pressable] and [PressFeedback]: pressed
/// wins over hovered; both ease with the same quick curve.
class _PointerMotion extends StatelessWidget {
  const _PointerMotion({
    required this.pressed,
    required this.hovered,
    required this.pressScale,
    required this.hoverScale,
    required this.hoverLift,
    required this.child,
  });

  final bool pressed;
  final bool hovered;
  final double pressScale;
  final double hoverScale;
  final double hoverLift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final scale = pressed ? pressScale : (hovered ? hoverScale : 1.0);
    final lift = hovered && !pressed ? -hoverLift : 0.0;
    return AnimatedContainer(
      duration: Duration(milliseconds: pressed ? 90 : 180),
      curve: Curves.easeOutCubic,
      transformAlignment: Alignment.center,
      transform: Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(0, lift, 0),
      child: child,
    );
  }
}
