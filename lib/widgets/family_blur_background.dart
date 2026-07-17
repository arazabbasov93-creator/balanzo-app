import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// Animated blur backdrop for the "no family yet" empty state.
class FamilyBlurBackground extends StatelessWidget {
  final Animation<double> animation;

  const FamilyBlurBackground({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Color.alphaBlend(Colors.black.withValues(alpha: 0.55), bg),
        ),
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            return Stack(
              children: [
                _floatingShape(t, 0, top: 80, left: 24, width: 140, height: 90),
                _floatingShape(t, 0.25, top: 180, right: 20, width: 180, height: 110),
                _floatingShape(t, 0.5, top: 320, left: 40, width: 200, height: 120),
                _floatingShape(t, 0.75, top: 460, right: 32, width: 160, height: 100),
              ],
            );
          },
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }

  Widget _floatingShape(
    double t,
    double phase, {
    double? top,
    double? left,
    double? right,
    required double width,
    required double height,
  }) {
    final dy = sin((t + phase) * 2 * pi) * 14;
    return Positioned(
      top: top != null ? top + dy : null,
      left: left,
      right: right,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.primaryGreenDark.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
