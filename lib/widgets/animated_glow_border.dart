import 'dart:math';
import 'package:flutter/material.dart';

enum GlowState { idle, listening, correct, error, celebrate }

class AnimatedGlowBorder extends StatefulWidget {
  final Widget child;
  final GlowState state;
  final double borderRadius;
  final double strokeWidth;
  final double glowRadius;

  const AnimatedGlowBorder({
    super.key,
    required this.child,
    this.state = GlowState.idle,
    this.borderRadius = 20,
    this.strokeWidth = 2.0,
    this.glowRadius = 12.0,
  });

  @override
  State<AnimatedGlowBorder> createState() => _AnimatedGlowBorderState();
}

class _AnimatedGlowBorderState extends State<AnimatedGlowBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _stateColors = <GlowState, List<Color>>{
    GlowState.idle: [
      Color(0xFF00D4FF),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
      Color(0xFF00D4FF),
    ],
    GlowState.listening: [
      Color(0xFF00D4FF),
      Color(0xFF8B5CF6),
      Color(0xFF6366F1),
      Color(0xFF00D4FF),
    ],
    GlowState.correct: [
      Color(0xFF00E68A),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
      Color(0xFF00E68A),
    ],
    GlowState.error: [
      Color(0xFFFF4757),
      Color(0xFFFF6B6B),
      Color(0xFFFF4757),
    ],
    GlowState.celebrate: [
      Color(0xFF00D4FF),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFFFD700),
      Color(0xFF00E68A),
      Color(0xFF06B6D4),
      Color(0xFF00D4FF),
    ],
  };

  static const _speedMultiplier = <GlowState, double>{
    GlowState.idle: 1.0,
    GlowState.listening: 1.5,
    GlowState.correct: 2.5,
    GlowState.error: 3.0,
    GlowState.celebrate: 2.0,
  };

  static const _glowMultiplier = <GlowState, double>{
    GlowState.idle: 0.6,
    GlowState.listening: 0.85,
    GlowState.correct: 1.0,
    GlowState.error: 1.0,
    GlowState.celebrate: 1.2,
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

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
        final speed = _speedMultiplier[widget.state] ?? 1.0;
        final rotationValue = (_controller.value * speed) % 1.0;
        final glowMult = _glowMultiplier[widget.state] ?? 0.6;
        final breathing = 0.85 + 0.15 * sin(_controller.value * 2 * pi * 1.3);
        final effectiveGlow = widget.glowRadius * glowMult * breathing;

        return CustomPaint(
          foregroundPainter: _GlowBorderPainter(
            rotation: rotationValue,
            colors: _stateColors[widget.state] ?? _stateColors[GlowState.idle]!,
            borderRadius: widget.borderRadius,
            strokeWidth: widget.strokeWidth,
            glowRadius: effectiveGlow,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  final double rotation;
  final List<Color> colors;
  final double borderRadius;
  final double strokeWidth;
  final double glowRadius;

  _GlowBorderPainter({
    required this.rotation,
    required this.colors,
    required this.borderRadius,
    required this.strokeWidth,
    required this.glowRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final gradient = SweepGradient(
      colors: colors,
      transform: GradientRotation(rotation * 2 * pi),
    );

    // Glow layer (blurred)
    final glowPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + glowRadius
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);

    canvas.drawRRect(rrect, glowPaint);

    // Crisp border on top
    final borderPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(_GlowBorderPainter oldDelegate) =>
      rotation != oldDelegate.rotation ||
      glowRadius != oldDelegate.glowRadius;
}
