import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ConsultationEntranceAnimator delivers a restrained, healthcare-appropriate
/// entrance transition for consultation list items.
///
/// Specification:
/// - Duration: 220 ms
/// - Curve: Curves.easeOutCubic
/// - Horizontal slide: 18 px from right -> 0 px
/// - Opacity: 0.0 -> 1.0
/// - Stagger: 30 ms per list index, capped at 300 ms
/// - Reduced Motion: Immediate static rendering when [disableAnimations] is active
/// - Lifecycle: Driven by Flutter Ticker/Interval without unmanaged Future.delayed timers
class ConsultationEntranceAnimator extends StatefulWidget {
  final Widget child;
  final int index;
  final bool shouldAnimate;
  final VoidCallback? onAnimationStarted;

  const ConsultationEntranceAnimator({
    super.key,
    required this.child,
    this.index = 0,
    this.shouldAnimate = true,
    this.onAnimationStarted,
  });

  @override
  State<ConsultationEntranceAnimator> createState() =>
      _ConsultationEntranceAnimatorState();
}

class _ConsultationEntranceAnimatorState
    extends State<ConsultationEntranceAnimator>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacityAnimation;
  Animation<Offset>? _offsetAnimation;
  bool _isAnimationActive = false;

  @override
  void initState() {
    super.initState();
    if (widget.shouldAnimate) {
      widget.onAnimationStarted?.call();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (widget.shouldAnimate &&
        !disableAnimations &&
        !_isAnimationActive &&
        _controller == null) {
      _isAnimationActive = true;

      final staggerDelayMs = math.min(widget.index * 30, 300);
      const animationDurationMs = 220;
      final totalDurationMs = staggerDelayMs + animationDurationMs;

      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: totalDurationMs),
      );

      final delayFraction = totalDurationMs > 0
          ? staggerDelayMs / totalDurationMs
          : 0.0;

      final curve = CurvedAnimation(
        parent: _controller!,
        curve: Interval(delayFraction, 1.0, curve: Curves.easeOutCubic),
      );

      _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
      _offsetAnimation = Tween<Offset>(
        begin: const Offset(18.0, 0.0),
        end: Offset.zero,
      ).animate(curve);

      _controller!.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldAnimate ||
        MediaQuery.of(context).disableAnimations ||
        _controller == null ||
        _opacityAnimation == null ||
        _offsetAnimation == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation!.value,
          child: Transform.translate(
            offset: _offsetAnimation!.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
