import 'dart:math';

import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// A lightweight one-shot confetti burst tuned for a child's peak-end
/// moment: warm activity colors, ~40 pieces, easing out over ~1.1s so it
/// never lingers long enough to overstimulate. Purely decorative; wrap
/// with IgnorePointer at the call site.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    required this.controller,
    this.pieceCount = 40,
  });

  final AnimationController controller;
  final int pieceCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> {
  late final List<_Piece> _pieces;

  static const List<Color> _palette = [
    TyperColors.speakBlue,
    TyperColors.wordsBg,
    TyperColors.phrasesBg,
    TyperColors.freeTypingBg,
    TyperColors.celebrateStar,
    TyperColors.correct,
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _pieces = List.generate(widget.pieceCount, (i) {
      // Fire in a fountain from bottom-center: angles cluster upward, with
      // a spread wide enough to fill the frame at peak.
      final angle = -pi / 2 + (rng.nextDouble() - 0.5) * 1.4;
      final speed = 0.55 + rng.nextDouble() * 0.55;
      return _Piece(
        color: _palette[rng.nextInt(_palette.length)],
        startX: 0.35 + rng.nextDouble() * 0.30, // near-center launch band
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        spin: (rng.nextDouble() - 0.5) * 8,
        size: 8 + rng.nextDouble() * 8,
        shape: rng.nextBool() ? _Shape.rect : _Shape.circle,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final t = widget.controller.value;
        if (t == 0 || t == 1) return const SizedBox.expand();
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(pieces: _pieces, t: t),
        );
      },
    );
  }
}

enum _Shape { rect, circle }

class _Piece {
  _Piece({
    required this.color,
    required this.startX,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.shape,
  });
  final Color color;
  final double startX;
  final double vx;
  final double vy;
  final double spin;
  final double size;
  final _Shape shape;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.t});
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Ease-out fade + gravity: pieces rise fast, then arc back down as t→1.
    final eased = Curves.easeOutQuad.transform(t);
    final gravity = 1.4 * t * t;
    final opacity = (1.0 - Curves.easeInCubic.transform(t)).clamp(0.0, 1.0);

    for (final p in pieces) {
      final travelX = p.vx * eased * size.width * 0.75;
      final travelY = (p.vy * eased + gravity) * size.height * 0.85;
      final x = p.startX * size.width + travelX;
      final y = size.height + travelY; // start off the bottom edge
      final angle = p.spin * t;
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      if (p.shape == _Shape.rect) {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.t != t;
}
