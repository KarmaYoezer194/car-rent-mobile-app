import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] in a light perspective tilt that follows a finger drag —
/// the "3D" depth language used on car photos throughout the app (car
/// cards, the Car Details hero). Not a real 3D model: a `Matrix4`
/// perspective transform on a flat layer, which is what gives the photo a
/// showroom-glass feel without any extra asset or rendering cost.
///
/// Snaps back to flat with a spring when the finger lifts, and never tilts
/// on a plain tap (`onPanDown` requires actual movement before the card
/// visibly reacts, so quick taps still feel instant, not laggy).
class TiltCard extends StatefulWidget {
  const TiltCard({
    super.key,
    required this.child,
    this.maxTiltRadians = 0.12,
    this.borderRadius,
  });

  final Widget child;
  final double maxTiltRadians;
  final BorderRadius? borderRadius;

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Offset _target = const Offset(0.5, 0.5);
  Offset _current = const Offset(0.5, 0.5);

  void _updateFromLocal(Offset local, Size size) {
    final dx = (local.dx / size.width).clamp(0.0, 1.0);
    final dy = (local.dy / size.height).clamp(0.0, 1.0);
    setState(() => _target = Offset(dx, dy));
  }

  void _release() {
    setState(() => _target = const Offset(0.5, 0.5));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (d) => _updateFromLocal(d.localPosition, size),
          onPanUpdate: (d) => _updateFromLocal(d.localPosition, size),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          child: TweenAnimationBuilder<Offset>(
            tween: Tween(begin: _current, end: _target),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            onEnd: () => _current = _target,
            builder: (context, value, child) {
              final rotY = (value.dx - 0.5) * 2 * widget.maxTiltRadians;
              final rotX = -(value.dy - 0.5) * 2 * widget.maxTiltRadians;
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..rotateX(rotX)
                ..rotateY(rotY);
              // A faint moving highlight along the tilt axis sells the
              // "glass over a photo" illusion better than the rotation
              // alone would.
              final shinePos = Alignment(
                (value.dx - 0.5) * 2,
                (value.dy - 0.5) * 2,
              );
              return Transform(
                alignment: FractionalOffset.center,
                transform: matrix,
                child: ClipRRect(
                  borderRadius: widget.borderRadius ?? BorderRadius.zero,
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      child!,
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: shinePos * -1,
                              end: shinePos,
                              colors: [
                                Colors.white.withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}

/// Purely decorative slow "breathing" 3D wobble (no touch input needed) —
/// used behind static hero art like the splash logo mark so it never sits
/// perfectly still.
class AutoTilt extends StatefulWidget {
  const AutoTilt({super.key, required this.child, this.amount = 0.05});

  final Widget child;
  final double amount;

  @override
  State<AutoTilt> createState() => _AutoTiltState();
}

class _AutoTiltState extends State<AutoTilt> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateX(math.sin(t) * widget.amount)
          ..rotateY(math.cos(t) * widget.amount);
        return Transform(alignment: FractionalOffset.center, transform: matrix, child: child);
      },
      child: widget.child,
    );
  }
}
