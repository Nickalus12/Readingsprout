import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player_profile.dart';
import '../data/avatar_options.dart';
import '../theme/app_theme.dart';

/// Reusable avatar rendering widget.
///
/// Renders the player's avatar at any size (32, 80, 120, etc.)
/// using [AvatarConfig] to drive face shape, skin tone, hair,
/// eyes, mouth, accessories, background, and optional effects.
class AvatarWidget extends StatelessWidget {
  final AvatarConfig config;
  final double size;
  final bool showBackground;
  final bool animateEffects;

  const AvatarWidget({
    super.key,
    required this.config,
    this.size = 80,
    this.showBackground = true,
    this.animateEffects = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.avatarBgColors[config.bgColor.clamp(0, 7)];

    Widget avatar = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background circle
          if (showBackground)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),

          // Golden glow ring (unlockable)
          if (config.hasGoldenGlow)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.starGold.withValues(alpha: 0.7),
                    width: size * 0.04,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.starGold.withValues(alpha: 0.4),
                      blurRadius: size * 0.15,
                      spreadRadius: size * 0.02,
                    ),
                  ],
                ),
              ),
            ),

          // Face area — inset from background
          Positioned(
            left: size * 0.15,
            top: size * 0.18,
            child: _buildFace(),
          ),

          // Hair — drawn above/around the face
          Positioned.fill(
            child: CustomPaint(
              painter: _HairPainter(
                style: config.hairStyle,
                color: _hairColor,
              ),
            ),
          ),

          // Eyes
          Positioned(
            left: size * 0.28,
            top: size * 0.42,
            child: CustomPaint(
              size: Size(size * 0.44, size * 0.14),
              painter: _EyesPainter(style: config.eyeStyle),
            ),
          ),

          // Mouth
          Positioned(
            left: size * 0.35,
            top: size * 0.62,
            child: CustomPaint(
              size: Size(size * 0.30, size * 0.12),
              painter: _MouthPainter(style: config.mouthStyle),
            ),
          ),

          // Accessory
          if (config.accessory > 0)
            _buildAccessory(),

          // Sparkle effect (unlockable)
          if (config.hasSparkle || config.hasRainbowSparkle)
            Positioned.fill(
              child: CustomPaint(
                painter: _SparklePainter(
                  rainbow: config.hasRainbowSparkle,
                ),
              ),
            ),
        ],
      ),
    );

    return avatar;
  }

  Color get _hairColor {
    final idx = config.hairColor.clamp(0, hairColorOptions.length - 1);
    return hairColorOptions[idx].color;
  }

  Color get _skinColor {
    final idx = config.skinTone.clamp(0, AppColors.skinTones.length - 1);
    return AppColors.skinTones[idx];
  }

  Widget _buildFace() {
    final faceW = size * 0.70;
    final faceH = _faceHeight;
    final shape = faceShapeOptions[config.faceShape.clamp(0, 2)];
    final radius = shape.borderRadius * faceW;

    return Container(
      width: faceW,
      height: faceH,
      decoration: BoxDecoration(
        color: _skinColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  double get _faceHeight {
    // Oval is taller, circle and square are equal w/h
    switch (config.faceShape) {
      case 2:
        return size * 0.68; // oval
      default:
        return size * 0.60;
    }
  }

  Widget _buildAccessory() {
    switch (config.accessory) {
      case 1: // Glasses
        return Positioned(
          left: size * 0.22,
          top: size * 0.38,
          child: CustomPaint(
            size: Size(size * 0.56, size * 0.18),
            painter: _GlassesPainter(),
          ),
        );
      case 2: // Crown
        return Positioned(
          left: size * 0.25,
          top: size * 0.02,
          child: CustomPaint(
            size: Size(size * 0.50, size * 0.20),
            painter: _CrownPainter(color: AppColors.starGold),
          ),
        );
      case 3: // Flower
        return Positioned(
          right: size * 0.05,
          top: size * 0.12,
          child: _FlowerAccessory(size: size * 0.22),
        );
      case 4: // Bow
        return Positioned(
          left: size * 0.30,
          top: size * 0.08,
          child: CustomPaint(
            size: Size(size * 0.24, size * 0.16),
            painter: _BowPainter(),
          ),
        );
      case 5: // Cap
        return Positioned(
          left: size * 0.10,
          top: size * 0.04,
          child: CustomPaint(
            size: Size(size * 0.70, size * 0.28),
            painter: _CapPainter(),
          ),
        );
      case 6: // Wizard Hat
        return Positioned(
          left: size * 0.18,
          top: -size * 0.15,
          child: CustomPaint(
            size: Size(size * 0.64, size * 0.45),
            painter: _WizardHatPainter(),
          ),
        );
      case 7: // Wings
        return Positioned(
          left: -size * 0.15,
          top: size * 0.25,
          child: CustomPaint(
            size: Size(size * 1.30, size * 0.55),
            painter: _WingsPainter(),
          ),
        );
      case 8: // Royal Crown
        return Positioned(
          left: size * 0.20,
          top: -size * 0.02,
          child: CustomPaint(
            size: Size(size * 0.60, size * 0.25),
            painter: _CrownPainter(
              color: AppColors.starGold,
              jewels: true,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Hair Painter ──────────────────────────────────────────────────────

class _HairPainter extends CustomPainter {
  final int style;
  final Color color;

  _HairPainter({required this.style, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    switch (style) {
      case 0: // Short — flat top hair
        final path = Path()
          ..moveTo(w * 0.18, h * 0.35)
          ..quadraticBezierTo(w * 0.18, h * 0.12, w * 0.35, h * 0.10)
          ..quadraticBezierTo(w * 0.50, h * 0.06, w * 0.65, h * 0.10)
          ..quadraticBezierTo(w * 0.82, h * 0.12, w * 0.82, h * 0.35)
          ..lineTo(w * 0.82, h * 0.28)
          ..quadraticBezierTo(w * 0.80, h * 0.15, w * 0.65, h * 0.15)
          ..quadraticBezierTo(w * 0.50, h * 0.13, w * 0.35, h * 0.15)
          ..quadraticBezierTo(w * 0.20, h * 0.15, w * 0.18, h * 0.28)
          ..close();
        canvas.drawPath(path, paint);

      case 1: // Long — flowing down sides
        final path = Path()
          ..moveTo(w * 0.15, h * 0.30)
          ..quadraticBezierTo(w * 0.15, h * 0.08, w * 0.50, h * 0.06)
          ..quadraticBezierTo(w * 0.85, h * 0.08, w * 0.85, h * 0.30)
          ..lineTo(w * 0.88, h * 0.75)
          ..quadraticBezierTo(w * 0.86, h * 0.82, w * 0.80, h * 0.78)
          ..lineTo(w * 0.78, h * 0.30)
          ..quadraticBezierTo(w * 0.76, h * 0.15, w * 0.50, h * 0.14)
          ..quadraticBezierTo(w * 0.24, h * 0.15, w * 0.22, h * 0.30)
          ..lineTo(w * 0.20, h * 0.78)
          ..quadraticBezierTo(w * 0.14, h * 0.82, w * 0.12, h * 0.75)
          ..close();
        canvas.drawPath(path, paint);

      case 2: // Curly — bumpy silhouette
        final path = Path()
          ..moveTo(w * 0.14, h * 0.38);
        // Left side curls
        path.quadraticBezierTo(w * 0.08, h * 0.28, w * 0.12, h * 0.20);
        path.quadraticBezierTo(w * 0.14, h * 0.10, w * 0.25, h * 0.08);
        // Top curls
        path.quadraticBezierTo(w * 0.32, h * 0.02, w * 0.42, h * 0.05);
        path.quadraticBezierTo(w * 0.50, h * 0.01, w * 0.58, h * 0.05);
        path.quadraticBezierTo(w * 0.68, h * 0.02, w * 0.75, h * 0.08);
        // Right side curls
        path.quadraticBezierTo(w * 0.86, h * 0.10, w * 0.88, h * 0.20);
        path.quadraticBezierTo(w * 0.92, h * 0.28, w * 0.86, h * 0.38);
        // Bottom right curl
        path.quadraticBezierTo(w * 0.90, h * 0.50, w * 0.84, h * 0.55);
        // Inner right
        path.lineTo(w * 0.80, h * 0.32);
        path.quadraticBezierTo(w * 0.78, h * 0.16, w * 0.50, h * 0.14);
        path.quadraticBezierTo(w * 0.22, h * 0.16, w * 0.20, h * 0.32);
        path.lineTo(w * 0.16, h * 0.55);
        path.quadraticBezierTo(w * 0.10, h * 0.50, w * 0.14, h * 0.38);
        path.close();
        canvas.drawPath(path, paint);

      case 3: // Braids — two hanging braids
        // Top hair
        final top = Path()
          ..moveTo(w * 0.18, h * 0.32)
          ..quadraticBezierTo(w * 0.18, h * 0.10, w * 0.50, h * 0.08)
          ..quadraticBezierTo(w * 0.82, h * 0.10, w * 0.82, h * 0.32)
          ..lineTo(w * 0.78, h * 0.28)
          ..quadraticBezierTo(w * 0.76, h * 0.16, w * 0.50, h * 0.15)
          ..quadraticBezierTo(w * 0.24, h * 0.16, w * 0.22, h * 0.28)
          ..close();
        canvas.drawPath(top, paint);
        // Left braid
        _drawBraid(canvas, paint, Offset(w * 0.18, h * 0.32), w * 0.06, h * 0.08, 4);
        // Right braid
        _drawBraid(canvas, paint, Offset(w * 0.76, h * 0.32), w * 0.06, h * 0.08, 4);

      case 4: // Ponytail — top hair + side ponytail
        final top = Path()
          ..moveTo(w * 0.18, h * 0.32)
          ..quadraticBezierTo(w * 0.18, h * 0.10, w * 0.50, h * 0.08)
          ..quadraticBezierTo(w * 0.82, h * 0.10, w * 0.82, h * 0.32)
          ..lineTo(w * 0.78, h * 0.28)
          ..quadraticBezierTo(w * 0.76, h * 0.16, w * 0.50, h * 0.15)
          ..quadraticBezierTo(w * 0.24, h * 0.16, w * 0.22, h * 0.28)
          ..close();
        canvas.drawPath(top, paint);
        // Ponytail going right
        final tail = Path()
          ..moveTo(w * 0.78, h * 0.22)
          ..quadraticBezierTo(w * 0.92, h * 0.20, w * 0.94, h * 0.35)
          ..quadraticBezierTo(w * 0.95, h * 0.55, w * 0.88, h * 0.65)
          ..quadraticBezierTo(w * 0.82, h * 0.58, w * 0.84, h * 0.40)
          ..quadraticBezierTo(w * 0.85, h * 0.28, w * 0.78, h * 0.26)
          ..close();
        canvas.drawPath(tail, paint);

      case 5: // Buzz — very short stubble
        final path = Path()
          ..moveTo(w * 0.20, h * 0.30)
          ..quadraticBezierTo(w * 0.20, h * 0.14, w * 0.50, h * 0.12)
          ..quadraticBezierTo(w * 0.80, h * 0.14, w * 0.80, h * 0.30)
          ..lineTo(w * 0.78, h * 0.26)
          ..quadraticBezierTo(w * 0.76, h * 0.17, w * 0.50, h * 0.16)
          ..quadraticBezierTo(w * 0.24, h * 0.17, w * 0.22, h * 0.26)
          ..close();
        canvas.drawPath(path, paint);

      case 6: // Afro — big round shape
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.25),
            width: w * 0.80,
            height: h * 0.42,
          ),
          paint,
        );

      case 7: // Bun — top hair + bun on top
        final top = Path()
          ..moveTo(w * 0.18, h * 0.32)
          ..quadraticBezierTo(w * 0.18, h * 0.12, w * 0.50, h * 0.10)
          ..quadraticBezierTo(w * 0.82, h * 0.12, w * 0.82, h * 0.32)
          ..lineTo(w * 0.78, h * 0.28)
          ..quadraticBezierTo(w * 0.76, h * 0.16, w * 0.50, h * 0.15)
          ..quadraticBezierTo(w * 0.24, h * 0.16, w * 0.22, h * 0.28)
          ..close();
        canvas.drawPath(top, paint);
        // Bun
        canvas.drawCircle(Offset(w * 0.50, h * 0.06), w * 0.14, paint);
    }
  }

  void _drawBraid(Canvas canvas, Paint paint, Offset start, double w, double h, int segments) {
    for (int i = 0; i < segments; i++) {
      final y = start.dy + i * h * 0.9;
      final xOff = (i.isEven) ? -w * 0.2 : w * 0.2;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(start.dx + w / 2 + xOff, y + h / 2),
          width: w,
          height: h,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HairPainter old) =>
      old.style != style || old.color != color;
}

// ── Eyes Painter ──────────────────────────────────────────────────────

class _EyesPainter extends CustomPainter {
  final int style;

  _EyesPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final leftCenter = Offset(w * 0.25, h * 0.5);
    final rightCenter = Offset(w * 0.75, h * 0.5);
    final eyeRadius = w * 0.12;

    switch (style) {
      case 0: // Round
        _drawRoundEyes(canvas, leftCenter, rightCenter, eyeRadius);

      case 1: // Star
        _drawStarEyes(canvas, leftCenter, rightCenter, eyeRadius);

      case 2: // Hearts
        _drawHeartEyes(canvas, leftCenter, rightCenter, eyeRadius);

      case 3: // Happy Crescents
        _drawCrescentEyes(canvas, w, h, leftCenter, rightCenter, eyeRadius);

      case 4: // Big Sparkle
        _drawSparkleEyes(canvas, leftCenter, rightCenter, eyeRadius);
    }
  }

  void _drawRoundEyes(Canvas canvas, Offset left, Offset right, double r) {
    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF1A1A2E);

    canvas.drawCircle(left, r, whitePaint);
    canvas.drawCircle(right, r, whitePaint);
    canvas.drawCircle(left.translate(r * 0.2, 0), r * 0.55, pupilPaint);
    canvas.drawCircle(right.translate(r * 0.2, 0), r * 0.55, pupilPaint);
    // Highlight
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(left.translate(r * 0.35, -r * 0.25), r * 0.2, highlightPaint);
    canvas.drawCircle(right.translate(r * 0.35, -r * 0.25), r * 0.2, highlightPaint);
  }

  void _drawStarEyes(Canvas canvas, Offset left, Offset right, double r) {
    final paint = Paint()..color = AppColors.starGold;
    _drawStar(canvas, left, r, paint);
    _drawStar(canvas, right, r, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      final outerX = center.dx + r * cos(outerAngle);
      final outerY = center.dy + r * sin(outerAngle);
      final innerX = center.dx + r * 0.4 * cos(innerAngle);
      final innerY = center.dy + r * 0.4 * sin(innerAngle);

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeartEyes(Canvas canvas, Offset left, Offset right, double r) {
    final paint = Paint()..color = const Color(0xFFFF4D6A);
    _drawHeart(canvas, left, r, paint);
    _drawHeart(canvas, right, r, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    final x = center.dx;
    final y = center.dy;
    path.moveTo(x, y + r * 0.5);
    path.cubicTo(x - r * 1.2, y - r * 0.3, x - r * 0.5, y - r * 1.0, x, y - r * 0.3);
    path.cubicTo(x + r * 0.5, y - r * 1.0, x + r * 1.2, y - r * 0.3, x, y + r * 0.5);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCrescentEyes(Canvas canvas, double w, double h, Offset left, Offset right, double r) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.5
      ..strokeCap = StrokeCap.round;

    // Happy upside-down U shapes
    canvas.drawArc(
      Rect.fromCenter(center: left, width: r * 2, height: r * 1.5),
      pi * 0.1,
      pi * 0.8,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: right, width: r * 2, height: r * 1.5),
      pi * 0.1,
      pi * 0.8,
      false,
      paint,
    );
  }

  void _drawSparkleEyes(Canvas canvas, Offset left, Offset right, double r) {
    // Big eyes with large highlights
    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF6366F1);
    final bigR = r * 1.3;

    canvas.drawCircle(left, bigR, whitePaint);
    canvas.drawCircle(right, bigR, whitePaint);
    canvas.drawCircle(left, bigR * 0.65, pupilPaint);
    canvas.drawCircle(right, bigR * 0.65, pupilPaint);
    // Large sparkle highlights
    final hlPaint = Paint()..color = Colors.white;
    canvas.drawCircle(left.translate(bigR * 0.3, -bigR * 0.2), bigR * 0.28, hlPaint);
    canvas.drawCircle(right.translate(bigR * 0.3, -bigR * 0.2), bigR * 0.28, hlPaint);
    canvas.drawCircle(left.translate(-bigR * 0.2, bigR * 0.25), bigR * 0.14, hlPaint);
    canvas.drawCircle(right.translate(-bigR * 0.2, bigR * 0.25), bigR * 0.14, hlPaint);
  }

  @override
  bool shouldRepaint(_EyesPainter old) => old.style != style;
}

// ── Mouth Painter ────────────────────────────────────────────────────

class _MouthPainter extends CustomPainter {
  final int style;

  _MouthPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (style) {
      case 0: // Smile
        final paint = Paint()
          ..color = const Color(0xFF1A1A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.08
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromLTWH(w * 0.1, -h * 0.2, w * 0.8, h * 1.0),
          0.2,
          pi * 0.6,
          false,
          paint,
        );

      case 1: // Big Grin
        final path = Path()
          ..moveTo(w * 0.05, h * 0.2)
          ..quadraticBezierTo(w * 0.5, h * 1.2, w * 0.95, h * 0.2)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF1A1A2E));
        // Teeth
        canvas.drawRect(
          Rect.fromLTWH(w * 0.25, h * 0.2, w * 0.5, h * 0.2),
          Paint()..color = Colors.white,
        );

      case 2: // Tongue Out
        final path = Path()
          ..moveTo(w * 0.10, h * 0.15)
          ..quadraticBezierTo(w * 0.5, h * 1.0, w * 0.90, h * 0.15)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF1A1A2E));
        // Tongue
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.65),
            width: w * 0.35,
            height: h * 0.55,
          ),
          Paint()..color = const Color(0xFFFF6B8A),
        );

      case 3: // Surprised O
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.45),
            width: w * 0.45,
            height: h * 0.80,
          ),
          Paint()..color = const Color(0xFF1A1A2E),
        );
        // Inner highlight
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.45),
            width: w * 0.30,
            height: h * 0.55,
          ),
          Paint()..color = const Color(0xFF2D2D4E),
        );
    }
  }

  @override
  bool shouldRepaint(_MouthPainter old) => old.style != style;
}

// ── Accessory Painters ───────────────────────────────────────────────

class _GlassesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04;

    // Left lens
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.28, h * 0.5), width: w * 0.38, height: h * 0.85),
      paint,
    );
    // Right lens
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.72, h * 0.5), width: w * 0.38, height: h * 0.85),
      paint,
    );
    // Bridge
    canvas.drawLine(Offset(w * 0.47, h * 0.45), Offset(w * 0.53, h * 0.45), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrownPainter extends CustomPainter {
  final Color color;
  final bool jewels;

  _CrownPainter({required this.color, this.jewels = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.4)
      ..lineTo(w * 0.15, h * 0.6)
      ..lineTo(w * 0.30, h * 0.1)
      ..lineTo(w * 0.50, h * 0.5)
      ..lineTo(w * 0.70, h * 0.1)
      ..lineTo(w * 0.85, h * 0.6)
      ..lineTo(w, h * 0.4)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(path, paint);

    if (jewels) {
      final jewelPaint = Paint()..color = const Color(0xFFFF4D6A);
      canvas.drawCircle(Offset(w * 0.30, h * 0.45), w * 0.05, jewelPaint);
      canvas.drawCircle(Offset(w * 0.50, h * 0.65), w * 0.05, Paint()..color = AppColors.electricBlue);
      canvas.drawCircle(Offset(w * 0.70, h * 0.45), w * 0.05, Paint()..color = AppColors.emerald);
    }
  }

  @override
  bool shouldRepaint(_CrownPainter old) => old.color != color || old.jewels != jewels;
}

class _FlowerAccessory extends StatelessWidget {
  final double size;
  const _FlowerAccessory({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FlowerPainter()),
    );
  }
}

class _FlowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final petalR = size.width * 0.28;
    final paint = Paint()..color = const Color(0xFFFF7EB3);

    for (int i = 0; i < 5; i++) {
      final angle = i * 2 * pi / 5 - pi / 2;
      canvas.drawCircle(
        Offset(c.dx + petalR * cos(angle), c.dy + petalR * sin(angle)),
        petalR * 0.55,
        paint,
      );
    }
    canvas.drawCircle(c, petalR * 0.4, Paint()..color = AppColors.starGold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = const Color(0xFFFF7EB3);

    // Left loop
    canvas.drawOval(
      Rect.fromLTWH(0, 0, w * 0.45, h),
      paint,
    );
    // Right loop
    canvas.drawOval(
      Rect.fromLTWH(w * 0.55, 0, w * 0.45, h),
      paint,
    );
    // Center knot
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.1,
      Paint()..color = const Color(0xFFE0559D),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = const Color(0xFF4A90D9);

    // Cap dome
    final dome = Path()
      ..moveTo(w * 0.05, h * 0.85)
      ..quadraticBezierTo(w * 0.05, h * 0.15, w * 0.50, h * 0.12)
      ..quadraticBezierTo(w * 0.95, h * 0.15, w * 0.95, h * 0.85)
      ..close();
    canvas.drawPath(dome, paint);

    // Brim
    final brim = Path()
      ..moveTo(0, h * 0.85)
      ..quadraticBezierTo(w * 0.5, h * 0.95, w, h * 0.85)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(brim, Paint()..color = const Color(0xFF3B7AC7));

    // Button on top
    canvas.drawCircle(Offset(w * 0.50, h * 0.15), w * 0.05, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WizardHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Hat cone
    final hat = Path()
      ..moveTo(w * 0.50, 0)
      ..lineTo(w * 0.05, h * 0.85)
      ..quadraticBezierTo(w * 0.50, h * 0.75, w * 0.95, h * 0.85)
      ..close();
    canvas.drawPath(hat, Paint()..color = AppColors.violet);

    // Brim
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.85), width: w, height: h * 0.30),
      Paint()..color = AppColors.violet,
    );

    // Star on hat
    final starPaint = Paint()..color = AppColors.starGold;
    _drawStar(canvas, Offset(w * 0.48, h * 0.38), w * 0.10, starPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      if (i == 0) {
        path.moveTo(center.dx + r * cos(outerAngle), center.dy + r * sin(outerAngle));
      } else {
        path.lineTo(center.dx + r * cos(outerAngle), center.dy + r * sin(outerAngle));
      }
      path.lineTo(center.dx + r * 0.4 * cos(innerAngle), center.dy + r * 0.4 * sin(innerAngle));
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final wingPaint = Paint()
      ..color = AppColors.electricBlue.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final wingOutline = Paint()
      ..color = AppColors.electricBlue.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008;

    // Left wing
    final leftWing = Path()
      ..moveTo(w * 0.38, h * 0.45)
      ..quadraticBezierTo(w * 0.10, h * 0.10, w * 0.02, h * 0.40)
      ..quadraticBezierTo(w * 0.0, h * 0.70, w * 0.20, h * 0.90)
      ..quadraticBezierTo(w * 0.30, h * 0.75, w * 0.38, h * 0.55)
      ..close();
    canvas.drawPath(leftWing, wingPaint);
    canvas.drawPath(leftWing, wingOutline);

    // Right wing
    final rightWing = Path()
      ..moveTo(w * 0.62, h * 0.45)
      ..quadraticBezierTo(w * 0.90, h * 0.10, w * 0.98, h * 0.40)
      ..quadraticBezierTo(w * 1.0, h * 0.70, w * 0.80, h * 0.90)
      ..quadraticBezierTo(w * 0.70, h * 0.75, w * 0.62, h * 0.55)
      ..close();
    canvas.drawPath(rightWing, wingPaint);
    canvas.drawPath(rightWing, wingOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Sparkle Effect Painter ───────────────────────────────────────────

class _SparklePainter extends CustomPainter {
  final bool rainbow;

  _SparklePainter({required this.rainbow});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42); // deterministic seed for consistent sparkle positions
    const sparkleCount = 6;
    final colors = rainbow
        ? [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple]
        : [AppColors.starGold, Colors.white, AppColors.starGold, Colors.white, AppColors.starGold, Colors.white];

    for (int i = 0; i < sparkleCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = size.width * 0.02 + rng.nextDouble() * size.width * 0.025;
      final paint = Paint()..color = colors[i % colors.length].withValues(alpha: 0.8);

      // 4-pointed sparkle
      final path = Path();
      path.moveTo(x, y - r);
      path.lineTo(x + r * 0.3, y);
      path.lineTo(x, y + r);
      path.lineTo(x - r * 0.3, y);
      path.close();
      path.moveTo(x - r, y);
      path.lineTo(x, y + r * 0.3);
      path.lineTo(x + r, y);
      path.lineTo(x, y - r * 0.3);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.rainbow != rainbow;
}
