import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/player_profile.dart';
import '../theme/app_theme.dart';

/// Determines the bookworm stage from a word count or ReadingLevel.
enum BookwormStage {
  wordSprout(0, 20, 'Word Sprout', Color(0xFF10B981)),
  wordExplorer(21, 60, 'Word Explorer', Color(0xFF06B6D4)),
  wordWizard(61, 120, 'Word Wizard', Color(0xFF8B5CF6)),
  wordChampion(121, 180, 'Word Champion', Color(0xFF00D4FF)),
  readingSuperstar(181, 269, 'Reading Superstar', Color(0xFFFFD700));

  final int minWords;
  final int maxWords;
  final String title;
  final Color primaryColor;

  const BookwormStage(this.minWords, this.maxWords, this.title, this.primaryColor);

  static BookwormStage fromWordCount(int count) {
    for (final stage in values.reversed) {
      if (count >= stage.minWords) return stage;
    }
    return wordSprout;
  }

  static BookwormStage fromReadingLevel(ReadingLevel level) {
    return values[level.index];
  }

  bool get isCaterpillar => index <= 2;
  bool get isButterfly => index >= 3;
}

/// Animated bookworm companion widget that evolves through 5 stages.
///
/// Renders well at multiple sizes (small for profile cards, medium for hero).
/// Includes idle bobbing animation and tap-to-wiggle interaction.
class BookwormCompanion extends StatefulWidget {
  final int wordCount;
  final double size;
  final VoidCallback? onTap;
  final bool showLabel;

  const BookwormCompanion({
    super.key,
    required this.wordCount,
    this.size = 120,
    this.onTap,
    this.showLabel = false,
  });

  @override
  State<BookwormCompanion> createState() => _BookwormCompanionState();
}

class _BookwormCompanionState extends State<BookwormCompanion>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _blinkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _blinkController.reverse();
      }
      if (status == AnimationStatus.dismissed) {
        setState(() => _isBlinking = false);
        _scheduleNextBlink();
      }
    });
    _scheduleNextBlink();

    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _wiggleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.05, end: -0.03), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _wiggleController,
      curve: Curves.easeInOut,
    ));
  }

  void _scheduleNextBlink() {
    final delay = Duration(
      milliseconds: 2000 + Random().nextInt(4000),
    );
    Future.delayed(delay, () {
      if (mounted) {
        setState(() => _isBlinking = true);
        _blinkController.forward();
      }
    });
  }

  void _handleTap() {
    _wiggleController.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = BookwormStage.fromWordCount(widget.wordCount);

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _wiggleAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _wiggleAnimation.value,
            child: child,
          );
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size * (widget.showLabel ? 1.25 : 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: _buildStage(stage),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .slideY(
                    begin: -0.03,
                    end: 0.03,
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  ),
              if (widget.showLabel) ...[
                const SizedBox(height: 4),
                Text(
                  stage.title,
                  style: TextStyle(
                    fontSize: widget.size * 0.11,
                    fontWeight: FontWeight.w600,
                    color: stage.primaryColor,
                    shadows: [
                      Shadow(
                        color: stage.primaryColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BookwormStage stage) {
    switch (stage) {
      case BookwormStage.wordSprout:
        return _CaterpillarStage1(
          size: widget.size,
          color: stage.primaryColor,
          isBlinking: _isBlinking,
        );
      case BookwormStage.wordExplorer:
        return _CaterpillarStage2(
          size: widget.size,
          color: stage.primaryColor,
          isBlinking: _isBlinking,
        );
      case BookwormStage.wordWizard:
        return _CaterpillarStage3(
          size: widget.size,
          color: stage.primaryColor,
          isBlinking: _isBlinking,
        );
      case BookwormStage.wordChampion:
        return _ButterflyStage4(
          size: widget.size,
          color: stage.primaryColor,
          isBlinking: _isBlinking,
        );
      case BookwormStage.readingSuperstar:
        return _ButterflyStage5(
          size: widget.size,
          color: stage.primaryColor,
          isBlinking: _isBlinking,
        );
    }
  }
}

// ────────────────────────────────────────────────────────────────────────
// Stage 1: Tiny green caterpillar with leaf hat
// ────────────────────────────────────────────────────────────────────────
class _CaterpillarStage1 extends StatelessWidget {
  final double size;
  final Color color;
  final bool isBlinking;

  const _CaterpillarStage1({
    required this.size,
    required this.color,
    required this.isBlinking,
  });

  @override
  Widget build(BuildContext context) {
    final segSize = size * 0.22;
    return CustomPaint(
      size: Size(size, size),
      painter: _CaterpillarPainter(
        segmentCount: 3,
        color: color,
        segmentSize: segSize,
        isBlinking: isBlinking,
        accessory: _CaterpillarAccessory.leafHat,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Stage 2: Bigger caterpillar carrying a small book
// ────────────────────────────────────────────────────────────────────────
class _CaterpillarStage2 extends StatelessWidget {
  final double size;
  final Color color;
  final bool isBlinking;

  const _CaterpillarStage2({
    required this.size,
    required this.color,
    required this.isBlinking,
  });

  @override
  Widget build(BuildContext context) {
    final segSize = size * 0.2;
    return CustomPaint(
      size: Size(size, size),
      painter: _CaterpillarPainter(
        segmentCount: 4,
        color: color,
        segmentSize: segSize,
        isBlinking: isBlinking,
        accessory: _CaterpillarAccessory.book,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Stage 3: Caterpillar with wizard hat + sparkles
// ────────────────────────────────────────────────────────────────────────
class _CaterpillarStage3 extends StatelessWidget {
  final double size;
  final Color color;
  final bool isBlinking;

  const _CaterpillarStage3({
    required this.size,
    required this.color,
    required this.isBlinking,
  });

  @override
  Widget build(BuildContext context) {
    final segSize = size * 0.19;
    return Stack(
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _CaterpillarPainter(
            segmentCount: 5,
            color: color,
            segmentSize: segSize,
            isBlinking: isBlinking,
            accessory: _CaterpillarAccessory.wizardHat,
          ),
        ),
        // Sparkles around the wizard
        ..._buildSparkles(size),
      ],
    );
  }

  List<Widget> _buildSparkles(double sz) {
    final positions = [
      Offset(sz * 0.15, sz * 0.15),
      Offset(sz * 0.75, sz * 0.2),
      Offset(sz * 0.85, sz * 0.55),
      Offset(sz * 0.1, sz * 0.6),
    ];
    return positions.asMap().entries.map((e) {
      final i = e.key;
      final pos = e.value;
      final sparkSize = sz * 0.06;
      return Positioned(
        left: pos.dx - sparkSize / 2,
        top: pos.dy - sparkSize / 2,
        child: Icon(
          Icons.auto_awesome,
          size: sparkSize,
          color: AppColors.starGold,
        )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
            )
            .fadeIn(duration: 600.ms, delay: Duration(milliseconds: i * 300))
            .fadeOut(delay: 1200.ms, duration: 600.ms)
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.2, 1.2),
              duration: 1200.ms,
            ),
      );
    }).toList();
  }
}

// ────────────────────────────────────────────────────────────────────────
// Stage 4: Beautiful butterfly with glowing wings
// ────────────────────────────────────────────────────────────────────────
class _ButterflyStage4 extends StatelessWidget {
  final double size;
  final Color color;
  final bool isBlinking;

  const _ButterflyStage4({
    required this.size,
    required this.color,
    required this.isBlinking,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ButterflyPainter(
        color: color,
        isBlinking: isBlinking,
        hasCrown: false,
        hasRainbowTrail: false,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Stage 5: Magnificent butterfly with crown + rainbow trail
// ────────────────────────────────────────────────────────────────────────
class _ButterflyStage5 extends StatelessWidget {
  final double size;
  final Color color;
  final bool isBlinking;

  const _ButterflyStage5({
    required this.size,
    required this.color,
    required this.isBlinking,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Rainbow trail particles
        ..._buildRainbowTrail(size),
        CustomPaint(
          size: Size(size, size),
          painter: _ButterflyPainter(
            color: color,
            isBlinking: isBlinking,
            hasCrown: true,
            hasRainbowTrail: true,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRainbowTrail(double sz) {
    final colors = [
      const Color(0xFFFF4444),
      const Color(0xFFFF8C42),
      const Color(0xFFFFD700),
      const Color(0xFF10B981),
      const Color(0xFF00D4FF),
      const Color(0xFF8B5CF6),
    ];
    return List.generate(6, (i) {
      final y = sz * 0.7 + (i * sz * 0.04);
      final x = sz * 0.45 + sin(i * 0.8) * sz * 0.08;
      final dotSize = sz * (0.04 - i * 0.004);
      return Positioned(
        left: x,
        top: y,
        child: Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors[i].withValues(alpha: 0.7),
            boxShadow: [
              BoxShadow(
                color: colors[i].withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeIn(
              duration: 800.ms,
              delay: Duration(milliseconds: i * 150),
            )
            .slideY(begin: 0, end: 0.3, duration: 1500.ms),
      );
    });
  }
}

// ────────────────────────────────────────────────────────────────────────
// Caterpillar accessories
// ────────────────────────────────────────────────────────────────────────
enum _CaterpillarAccessory { leafHat, book, wizardHat }

// ────────────────────────────────────────────────────────────────────────
// CustomPainter for caterpillar stages (1-3)
// ────────────────────────────────────────────────────────────────────────
class _CaterpillarPainter extends CustomPainter {
  final int segmentCount;
  final Color color;
  final double segmentSize;
  final bool isBlinking;
  final _CaterpillarAccessory accessory;

  _CaterpillarPainter({
    required this.segmentCount,
    required this.color,
    required this.segmentSize,
    required this.isBlinking,
    required this.accessory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw body segments in an arc
    final bodyPaint = Paint()..style = PaintingStyle.fill;
    final darkShade = HSLColor.fromColor(color).withLightness(
      (HSLColor.fromColor(color).lightness - 0.12).clamp(0.0, 1.0),
    ).toColor();

    final segments = <Offset>[];
    for (int i = 0; i < segmentCount; i++) {
      // Arc the segments in a gentle curve
      final progress = i / (segmentCount - 1).clamp(1, segmentCount);
      final xOff = (i - segmentCount / 2) * segmentSize * 0.7;
      final yOff = -sin(progress * pi) * segmentSize * 0.5;
      segments.add(Offset(
        cx + xOff,
        cy + segmentSize * 0.3 + yOff,
      ));
    }

    // Draw segments back-to-front (tail first)
    for (int i = segmentCount - 1; i >= 0; i--) {
      final pos = segments[i];
      final s = i == 0 ? segmentSize * 1.15 : segmentSize; // Head is bigger
      final segColor = i == 0 ? color : Color.lerp(color, darkShade, i * 0.12)!;

      bodyPaint.color = segColor;
      canvas.drawCircle(pos, s / 2, bodyPaint);

      // Belly highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(pos.dx - s * 0.08, pos.dy - s * 0.08),
        s * 0.25,
        highlightPaint,
      );
    }

    // Head is segments[0]
    final head = segments[0];
    final headSize = segmentSize * 1.15;

    // Draw eyes
    _drawEyes(canvas, head, headSize);

    // Draw smile
    _drawSmile(canvas, head, headSize);

    // Draw antennae
    _drawAntennae(canvas, head, headSize);

    // Draw accessory
    switch (accessory) {
      case _CaterpillarAccessory.leafHat:
        _drawLeafHat(canvas, head, headSize);
        break;
      case _CaterpillarAccessory.book:
        _drawBook(canvas, segments.last, segmentSize);
        break;
      case _CaterpillarAccessory.wizardHat:
        _drawWizardHat(canvas, head, headSize);
        break;
    }

    // Tiny feet
    for (int i = 1; i < segmentCount; i++) {
      final pos = segments[i];
      final s = segmentSize;
      final footPaint = Paint()..color = darkShade;
      canvas.drawCircle(
        Offset(pos.dx - s * 0.2, pos.dy + s * 0.42),
        s * 0.1,
        footPaint,
      );
      canvas.drawCircle(
        Offset(pos.dx + s * 0.2, pos.dy + s * 0.42),
        s * 0.1,
        footPaint,
      );
    }
  }

  void _drawEyes(Canvas canvas, Offset head, double headSize) {
    final eyeSpacing = headSize * 0.18;
    final eyeY = head.dy - headSize * 0.05;
    final eyeRadius = headSize * 0.15;
    final pupilRadius = headSize * 0.08;

    // White sclera
    final scleraPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(head.dx - eyeSpacing, eyeY),
      eyeRadius,
      scleraPaint,
    );
    canvas.drawCircle(
      Offset(head.dx + eyeSpacing, eyeY),
      eyeRadius,
      scleraPaint,
    );

    if (!isBlinking) {
      // Black pupils
      final pupilPaint = Paint()..color = const Color(0xFF1A1A2E);
      canvas.drawCircle(
        Offset(head.dx - eyeSpacing, eyeY),
        pupilRadius,
        pupilPaint,
      );
      canvas.drawCircle(
        Offset(head.dx + eyeSpacing, eyeY),
        pupilRadius,
        pupilPaint,
      );

      // Tiny eye shine
      final shinePaint = Paint()..color = Colors.white;
      canvas.drawCircle(
        Offset(head.dx - eyeSpacing - pupilRadius * 0.3, eyeY - pupilRadius * 0.3),
        pupilRadius * 0.35,
        shinePaint,
      );
      canvas.drawCircle(
        Offset(head.dx + eyeSpacing - pupilRadius * 0.3, eyeY - pupilRadius * 0.3),
        pupilRadius * 0.35,
        shinePaint,
      );
    } else {
      // Blink: draw horizontal lines
      final blinkPaint = Paint()
        ..color = const Color(0xFF1A1A2E)
        ..strokeWidth = headSize * 0.04
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(head.dx - eyeSpacing - eyeRadius * 0.6, eyeY),
        Offset(head.dx - eyeSpacing + eyeRadius * 0.6, eyeY),
        blinkPaint,
      );
      canvas.drawLine(
        Offset(head.dx + eyeSpacing - eyeRadius * 0.6, eyeY),
        Offset(head.dx + eyeSpacing + eyeRadius * 0.6, eyeY),
        blinkPaint,
      );
    }
  }

  void _drawSmile(Canvas canvas, Offset head, double headSize) {
    final smilePaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headSize * 0.04
      ..strokeCap = StrokeCap.round;

    final smileRect = Rect.fromCenter(
      center: Offset(head.dx, head.dy + headSize * 0.15),
      width: headSize * 0.3,
      height: headSize * 0.2,
    );
    canvas.drawArc(smileRect, 0.2, pi * 0.6, false, smilePaint);
  }

  void _drawAntennae(Canvas canvas, Offset head, double headSize) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = headSize * 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tipPaint = Paint()..color = color;

    // Left antenna
    final lBase = Offset(head.dx - headSize * 0.15, head.dy - headSize * 0.4);
    final lTip = Offset(head.dx - headSize * 0.3, head.dy - headSize * 0.65);
    canvas.drawLine(lBase, lTip, paint);
    canvas.drawCircle(lTip, headSize * 0.06, tipPaint);

    // Right antenna
    final rBase = Offset(head.dx + headSize * 0.15, head.dy - headSize * 0.4);
    final rTip = Offset(head.dx + headSize * 0.3, head.dy - headSize * 0.65);
    canvas.drawLine(rBase, rTip, paint);
    canvas.drawCircle(rTip, headSize * 0.06, tipPaint);
  }

  void _drawLeafHat(Canvas canvas, Offset head, double headSize) {
    final leafPaint = Paint()
      ..color = const Color(0xFF059669)
      ..style = PaintingStyle.fill;

    final path = Path();
    final top = Offset(head.dx, head.dy - headSize * 0.7);
    final left = Offset(head.dx - headSize * 0.25, head.dy - headSize * 0.35);
    final right = Offset(head.dx + headSize * 0.3, head.dy - headSize * 0.4);

    path.moveTo(top.dx, top.dy);
    path.quadraticBezierTo(left.dx - headSize * 0.1, left.dy - headSize * 0.15, left.dx, left.dy);
    path.quadraticBezierTo(head.dx, head.dy - headSize * 0.45, right.dx, right.dy);
    path.quadraticBezierTo(right.dx + headSize * 0.05, top.dy + headSize * 0.1, top.dx, top.dy);

    canvas.drawPath(path, leafPaint);

    // Leaf vein
    final veinPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = headSize * 0.025
      ..style = PaintingStyle.stroke;
    canvas.drawLine(top, Offset(head.dx, head.dy - headSize * 0.38), veinPaint);
  }

  void _drawBook(Canvas canvas, Offset tail, double segSize) {
    final bookX = tail.dx + segSize * 0.3;
    final bookY = tail.dy - segSize * 0.1;
    final bw = segSize * 0.5;
    final bh = segSize * 0.4;

    // Book cover
    final coverPaint = Paint()..color = const Color(0xFF8B4513);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bookX, bookY), width: bw, height: bh),
        Radius.circular(bw * 0.1),
      ),
      coverPaint,
    );

    // Pages
    final pagesPaint = Paint()..color = const Color(0xFFFFF8E1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bookX + bw * 0.05, bookY),
          width: bw * 0.8,
          height: bh * 0.85,
        ),
        Radius.circular(bw * 0.05),
      ),
      pagesPaint,
    );

    // Spine line
    final spinePaint = Paint()
      ..color = const Color(0xFF6B3410)
      ..strokeWidth = bw * 0.06;
    canvas.drawLine(
      Offset(bookX - bw * 0.35, bookY - bh * 0.45),
      Offset(bookX - bw * 0.35, bookY + bh * 0.45),
      spinePaint,
    );
  }

  void _drawWizardHat(Canvas canvas, Offset head, double headSize) {
    final hatPaint = Paint()
      ..color = const Color(0xFF6B21A8)
      ..style = PaintingStyle.fill;

    final hatPath = Path();
    final tip = Offset(head.dx + headSize * 0.1, head.dy - headSize * 0.85);
    final leftBase = Offset(head.dx - headSize * 0.35, head.dy - headSize * 0.3);
    final rightBase = Offset(head.dx + headSize * 0.4, head.dy - headSize * 0.3);

    hatPath.moveTo(tip.dx, tip.dy);
    hatPath.lineTo(leftBase.dx, leftBase.dy);
    hatPath.lineTo(rightBase.dx, rightBase.dy);
    hatPath.close();

    canvas.drawPath(hatPath, hatPaint);

    // Hat brim
    final brimPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(head.dx + headSize * 0.02, head.dy - headSize * 0.3),
        width: headSize * 0.85,
        height: headSize * 0.18,
      ),
      brimPaint,
    );

    // Star on hat
    final starPaint = Paint()..color = const Color(0xFFFFD700);
    final starCenter = Offset(tip.dx - headSize * 0.02, tip.dy + headSize * 0.25);
    _drawStar(canvas, starCenter, headSize * 0.1, starPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = -pi / 2 + (i * 2 * pi / 5);
      final innerAngle = angle + pi / 5;
      final outerX = center.dx + radius * cos(angle);
      final outerY = center.dy + radius * sin(angle);
      final innerX = center.dx + radius * 0.4 * cos(innerAngle);
      final innerY = center.dy + radius * 0.4 * sin(innerAngle);

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

  @override
  bool shouldRepaint(covariant _CaterpillarPainter oldDelegate) {
    return isBlinking != oldDelegate.isBlinking ||
        color != oldDelegate.color ||
        segmentCount != oldDelegate.segmentCount;
  }
}

// ────────────────────────────────────────────────────────────────────────
// CustomPainter for butterfly stages (4-5)
// ────────────────────────────────────────────────────────────────────────
class _ButterflyPainter extends CustomPainter {
  final Color color;
  final bool isBlinking;
  final bool hasCrown;
  final bool hasRainbowTrail;

  _ButterflyPainter({
    required this.color,
    required this.isBlinking,
    required this.hasCrown,
    required this.hasRainbowTrail,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Wing colors
    final wingColor = color;
    final wingHighlight = Color.lerp(color, Colors.white, 0.3)!;
    final wingDark = HSLColor.fromColor(color)
        .withLightness((HSLColor.fromColor(color).lightness - 0.15).clamp(0.0, 1.0))
        .toColor();

    // Draw wings (two on each side)
    final wingGlow = Paint()
      ..color = wingColor.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // Upper left wing
    _drawWing(canvas, cx, cy, size, isLeft: true, isUpper: true,
        color: wingColor, highlight: wingHighlight, glow: wingGlow);
    // Upper right wing
    _drawWing(canvas, cx, cy, size, isLeft: false, isUpper: true,
        color: wingColor, highlight: wingHighlight, glow: wingGlow);
    // Lower left wing
    _drawWing(canvas, cx, cy, size, isLeft: true, isUpper: false,
        color: wingDark, highlight: wingColor, glow: wingGlow);
    // Lower right wing
    _drawWing(canvas, cx, cy, size, isLeft: false, isUpper: false,
        color: wingDark, highlight: wingColor, glow: wingGlow);

    // Body
    final bodyPaint = Paint()..color = const Color(0xFF1A1A2E);
    final bodyW = size.width * 0.07;
    final bodyH = size.height * 0.35;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + bodyH * 0.15), width: bodyW, height: bodyH),
        Radius.circular(bodyW / 2),
      ),
      bodyPaint,
    );

    // Head
    final headRadius = size.width * 0.065;
    final headCenter = Offset(cx, cy - bodyH * 0.15);
    canvas.drawCircle(headCenter, headRadius, bodyPaint);

    // Eyes on head
    final eyeRadius = headRadius * 0.4;
    final pupilRadius = headRadius * 0.22;
    final eyeSpacing = headRadius * 0.5;
    final eyeY = headCenter.dy;

    final scleraPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(headCenter.dx - eyeSpacing, eyeY), eyeRadius, scleraPaint);
    canvas.drawCircle(Offset(headCenter.dx + eyeSpacing, eyeY), eyeRadius, scleraPaint);

    if (!isBlinking) {
      final pupilPaint = Paint()..color = const Color(0xFF0A0A1A);
      canvas.drawCircle(Offset(headCenter.dx - eyeSpacing, eyeY), pupilRadius, pupilPaint);
      canvas.drawCircle(Offset(headCenter.dx + eyeSpacing, eyeY), pupilRadius, pupilPaint);

      final shinePaint = Paint()..color = Colors.white;
      final shineR = pupilRadius * 0.35;
      canvas.drawCircle(
        Offset(headCenter.dx - eyeSpacing - shineR, eyeY - shineR),
        shineR,
        shinePaint,
      );
      canvas.drawCircle(
        Offset(headCenter.dx + eyeSpacing - shineR, eyeY - shineR),
        shineR,
        shinePaint,
      );
    } else {
      final blinkPaint = Paint()
        ..color = const Color(0xFF0A0A1A)
        ..strokeWidth = headRadius * 0.12
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(headCenter.dx - eyeSpacing - eyeRadius * 0.5, eyeY),
        Offset(headCenter.dx - eyeSpacing + eyeRadius * 0.5, eyeY),
        blinkPaint,
      );
      canvas.drawLine(
        Offset(headCenter.dx + eyeSpacing - eyeRadius * 0.5, eyeY),
        Offset(headCenter.dx + eyeSpacing + eyeRadius * 0.5, eyeY),
        blinkPaint,
      );
    }

    // Antennae
    final antPaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = size.width * 0.015
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final tipPaint = Paint()..color = wingColor;

    final lBase = Offset(headCenter.dx - headRadius * 0.4, headCenter.dy - headRadius * 0.7);
    final lTip = Offset(headCenter.dx - size.width * 0.1, headCenter.dy - size.height * 0.2);
    final rBase = Offset(headCenter.dx + headRadius * 0.4, headCenter.dy - headRadius * 0.7);
    final rTip = Offset(headCenter.dx + size.width * 0.1, headCenter.dy - size.height * 0.2);

    final lPath = Path()
      ..moveTo(lBase.dx, lBase.dy)
      ..quadraticBezierTo(lBase.dx - size.width * 0.05, lTip.dy + size.height * 0.05, lTip.dx, lTip.dy);
    final rPath = Path()
      ..moveTo(rBase.dx, rBase.dy)
      ..quadraticBezierTo(rBase.dx + size.width * 0.05, rTip.dy + size.height * 0.05, rTip.dx, rTip.dy);

    canvas.drawPath(lPath, antPaint);
    canvas.drawPath(rPath, antPaint);
    canvas.drawCircle(lTip, size.width * 0.02, tipPaint);
    canvas.drawCircle(rTip, size.width * 0.02, tipPaint);

    // Crown for stage 5
    if (hasCrown) {
      _drawCrown(canvas, headCenter, headRadius, size);
    }
  }

  void _drawWing(Canvas canvas, double cx, double cy, Size size, {
    required bool isLeft,
    required bool isUpper,
    required Color color,
    required Color highlight,
    required Paint glow,
  }) {
    final wingPath = Path();
    final dir = isLeft ? -1.0 : 1.0;
    final wingW = size.width * 0.38;
    final wingH = isUpper ? size.height * 0.32 : size.height * 0.22;
    final wingCy = isUpper ? cy - wingH * 0.2 : cy + wingH * 0.6;

    final base = Offset(cx, wingCy);
    final tip = Offset(cx + dir * wingW, wingCy - (isUpper ? wingH * 0.6 : -wingH * 0.3));
    final outerCtrl = Offset(
      cx + dir * wingW * 0.9,
      wingCy - (isUpper ? wingH * 1.1 : -wingH * 0.9),
    );
    final innerCtrl = Offset(
      cx + dir * wingW * 0.4,
      wingCy + (isUpper ? wingH * 0.3 : -wingH * 0.1),
    );

    wingPath.moveTo(base.dx, base.dy);
    wingPath.quadraticBezierTo(outerCtrl.dx, outerCtrl.dy, tip.dx, tip.dy);
    wingPath.quadraticBezierTo(innerCtrl.dx, innerCtrl.dy, base.dx, base.dy);

    // Glow behind wing
    canvas.drawPath(wingPath, glow);

    // Wing fill
    final wingPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(dir * 0.3, isUpper ? -0.3 : 0.3),
        radius: 1.2,
        colors: [highlight, color],
      ).createShader(Rect.fromCenter(center: tip, width: wingW * 2, height: wingH * 2));
    canvas.drawPath(wingPath, wingPaint);

    // Wing spot decoration
    final spotCenter = Offset(
      cx + dir * wingW * 0.45,
      wingCy + (isUpper ? -wingH * 0.25 : wingH * 0.15),
    );
    final spotR = (isUpper ? wingW : wingW * 0.7) * 0.2;
    final spotPaint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawCircle(spotCenter, spotR, spotPaint);
  }

  void _drawCrown(Canvas canvas, Offset head, double headRadius, Size size) {
    final crownPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    final crownY = head.dy - headRadius * 1.3;
    final crownW = headRadius * 1.6;
    final crownH = headRadius * 0.8;

    final path = Path();
    path.moveTo(head.dx - crownW / 2, crownY + crownH);
    path.lineTo(head.dx - crownW / 2, crownY + crownH * 0.3);
    path.lineTo(head.dx - crownW * 0.25, crownY + crownH * 0.6);
    path.lineTo(head.dx, crownY);
    path.lineTo(head.dx + crownW * 0.25, crownY + crownH * 0.6);
    path.lineTo(head.dx + crownW / 2, crownY + crownH * 0.3);
    path.lineTo(head.dx + crownW / 2, crownY + crownH);
    path.close();

    canvas.drawPath(path, crownPaint);

    // Jewels on crown tips
    final jewelPaint = Paint()..color = const Color(0xFFFF4444);
    canvas.drawCircle(Offset(head.dx, crownY + crownH * 0.15), headRadius * 0.1, jewelPaint);
    final blueJewel = Paint()..color = const Color(0xFF00D4FF);
    canvas.drawCircle(
      Offset(head.dx - crownW * 0.25, crownY + crownH * 0.55),
      headRadius * 0.07,
      blueJewel,
    );
    canvas.drawCircle(
      Offset(head.dx + crownW * 0.25, crownY + crownH * 0.55),
      headRadius * 0.07,
      blueJewel,
    );
  }

  @override
  bool shouldRepaint(covariant _ButterflyPainter oldDelegate) {
    return isBlinking != oldDelegate.isBlinking ||
        color != oldDelegate.color ||
        hasCrown != oldDelegate.hasCrown;
  }
}
