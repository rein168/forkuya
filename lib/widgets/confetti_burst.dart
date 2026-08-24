import 'dart:math';
import 'package:flutter/material.dart';
import '../design_tokens.dart';

class ConfettiBurst extends StatelessWidget {
  const ConfettiBurst({super.key, required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        if (t == 0) return const SizedBox.shrink();
        final opacity = (1 - t).clamp(0.0, 1.0);
        // 7 confetti pieces in brand colors, burst outward
        final colors = [
          TyperColors.correct,
          TyperColors.speakBlue,
          const Color(0xFFFFC107),
          TyperColors.phrasesInk,
          TyperColors.correctDeep,
          const Color(0xFFFF6F00),
          TyperColors.speakBlue,
        ];
        return IgnorePointer(
          child: Stack(
            children: List.generate(7, (i) {
              final angle = (i / 7) * 2 * pi - pi / 2;
              final distance = 60 + i * 8;
              final dx = cos(angle) * distance * t;
              final dy = sin(angle) * distance * t - 20 * sin(pi * t);
              final scale = 0.6 + 0.4 * (1 - t);
              return Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Icon(
                          i % 2 == 0 ? Icons.star_rounded : Icons.circle,
                          size: i % 2 == 0 ? 18 : 10,
                          color: colors[i % colors.length],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
