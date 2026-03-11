import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/letter_paths.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../utils/stroke_evaluator.dart';

/// An interactive letter-tracing canvas for children.
///
/// Shows a faded letter glyph as background context, a dotted guide path for
/// the current stroke, a pulsing start dot, and the child's drawn path with
/// glow effects. Completed strokes render in gold/green.
class LetterTracingCanvas extends StatefulWidget {
  final String letter;
  final VoidCallback onComplete;
  final VoidCallback? onFail;
  final Color traceColor;
  final Color guideColor;

  const LetterTracingCanvas({
    super.key,
    required this.letter,
    required this.onComplete,
    this.onFail,
    this.traceColor = const Color(0xFF4FC3F7),
    this.guideColor = const Color(0x4DFFFFFF),
  });

  @override
  State<LetterTracingCanvas> createState() => _LetterTracingCanvasState();
}

class _LetterTracingCanvasState extends State<LetterTracingCanvas>
    with TickerProviderStateMixin {
  /// All strokes for this letter in normalized coordinates.
  late List<List<Offset>> _templateStrokes;

  /// Index of the stroke the child is currently tracing.
  int _currentStrokeIndex = 0;

  /// Points the child has drawn for the current stroke (in widget-local px).
  List<Offset> _currentPoints = [];

  /// Completed user strokes (widget-local px) — one per finished template stroke.
  final List<List<Offset>> _completedStrokes = [];

  /// Whether we're showing the sparkle completion animation.
  bool _complete = false;

  /// Whether we're shaking after a failed trace attempt.
  bool _shaking = false;

  /// Number of consecutive failures on the current stroke (to increase tolerance).
  int _failCount = 0;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _templateStrokes = LetterPaths.getPath(widget.letter);

    // Pulsing guide dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Shake on failed trace
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
        if (mounted) setState(() => _shaking = false);
      }
    });

    // Sparkle on completion
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _sparkleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  /// Convert widget-local pixel offset to normalized 0–1 coordinates.
  Offset _toNormalized(Offset pixel, Size canvasSize) {
    const pad = 20.0;
    final w = canvasSize.width - pad * 2;
    final h = canvasSize.height - pad * 2;
    return Offset(
      ((pixel.dx - pad) / w).clamp(0.0, 1.0),
      ((pixel.dy - pad) / h).clamp(0.0, 1.0),
    );
  }

  void _onPanStart(DragStartDetails details) {
    if (_complete || _shaking) return;
    setState(() {
      _currentPoints = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_complete || _shaking) return;
    setState(() {
      _currentPoints.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_complete || _shaking) return;
    if (_currentStrokeIndex >= _templateStrokes.length) return;
    if (_currentPoints.length < 3) {
      setState(() => _currentPoints = []);
      return;
    }

    // Get the canvas size from context
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final canvasSize = box.size;

    // Convert user points to normalized space for comparison
    final userNormalized =
        _currentPoints.map((p) => _toNormalized(p, canvasSize)).toList();

    // Progressive tolerance: starts generous, gets more generous with failures
    final tolerance = (0.22 + _failCount * 0.06).clamp(0.22, 0.45);
    final score = StrokeEvaluator.evaluate(
      userNormalized,
      _templateStrokes[_currentStrokeIndex],
      toleranceRadius: tolerance,
    );

    if (score >= 0.35) {
      // Accept this stroke
      Haptics.correct();
      _failCount = 0;
      setState(() {
        _completedStrokes.add(List<Offset>.from(_currentPoints));
        _currentPoints = [];
        _currentStrokeIndex++;
      });

      // Check if all strokes are done
      if (_currentStrokeIndex >= _templateStrokes.length) {
        Haptics.success();
        setState(() => _complete = true);
        _sparkleController.forward();
      }
    } else {
      // Failed — shake and let them try again
      Haptics.wrong();
      _failCount++;
      setState(() {
        _shaking = true;
        _currentPoints = [];
      });
      _shakeController.forward();
      if (_failCount >= 4) {
        // After 4 failures on same stroke, auto-accept to avoid frustration
        Haptics.correct();
        _failCount = 0;
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          setState(() {
            _completedStrokes.add([]); // placeholder
            _currentStrokeIndex++;
            _shaking = false;
          });
          if (_currentStrokeIndex >= _templateStrokes.length) {
            Haptics.success();
            setState(() => _complete = true);
            _sparkleController.forward();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Square canvas, fitting within constraints
        final side = min(constraints.maxWidth, constraints.maxHeight)
            .clamp(0.0, 280.0);
        final canvasSize = Size(side, side);

        Widget canvas = GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _shakeAnimation,
              _sparkleController,
            ]),
            builder: (context, _) {
              double offsetX = 0;
              if (_shaking) {
                offsetX = sin(_shakeAnimation.value * pi * 4) * 10;
              }
              return Transform.translate(
                offset: Offset(offsetX, 0),
                child: Container(
                  width: canvasSize.width,
                  height: canvasSize.height,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _complete
                          ? AppColors.success.withValues(alpha: 0.5)
                          : widget.traceColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_complete
                                ? AppColors.success
                                : widget.traceColor)
                            .withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CustomPaint(
                      size: canvasSize,
                      painter: _TracingPainter(
                        letter: widget.letter,
                        templateStrokes: _templateStrokes,
                        currentStrokeIndex: _currentStrokeIndex,
                        currentPoints: _currentPoints,
                        completedStrokes: _completedStrokes,
                        traceColor: widget.traceColor,
                        guideColor: widget.guideColor,
                        pulseValue: _pulseController.value,
                        sparkleValue: _sparkleController.value,
                        isComplete: _complete,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );

        // Stroke progress dots below the canvas
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Trace the letter" label
            Text(
              _complete ? 'Great job!' : 'Trace: ${widget.letter}',
              style: AppFonts.fredoka(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _complete ? AppColors.success : AppColors.primaryText,
              ),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            canvas,
            const SizedBox(height: 10),
            // Stroke progress indicator
            if (_templateStrokes.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_templateStrokes.length, (i) {
                  final done = i < _currentStrokeIndex;
                  final active = i == _currentStrokeIndex && !_complete;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 18 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: done
                          ? AppColors.success
                          : active
                              ? widget.traceColor
                              : AppColors.surface,
                      border: Border.all(
                        color: done
                            ? AppColors.success.withValues(alpha: 0.5)
                            : active
                                ? widget.traceColor.withValues(alpha: 0.5)
                                : AppColors.border.withValues(alpha: 0.3),
                      ),
                      boxShadow: done
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.success.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }
}

/// Custom painter that draws the letter tracing UI.
class _TracingPainter extends CustomPainter {
  final String letter;
  final List<List<Offset>> templateStrokes;
  final int currentStrokeIndex;
  final List<Offset> currentPoints;
  final List<List<Offset>> completedStrokes;
  final Color traceColor;
  final Color guideColor;
  final double pulseValue;
  final double sparkleValue;
  final bool isComplete;

  _TracingPainter({
    required this.letter,
    required this.templateStrokes,
    required this.currentStrokeIndex,
    required this.currentPoints,
    required this.completedStrokes,
    required this.traceColor,
    required this.guideColor,
    required this.pulseValue,
    required this.sparkleValue,
    required this.isComplete,
  });

  Offset _toPixel(Offset normalized, Size size) {
    const pad = 20.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    return Offset(pad + normalized.dx * w, pad + normalized.dy * h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Faded letter glyph as background context
    _drawLetterGlyph(canvas, size);

    // 2. Draw completed guide strokes (faded out)
    for (int i = 0; i < currentStrokeIndex && i < templateStrokes.length; i++) {
      _drawGuideStroke(canvas, size, templateStrokes[i], completed: true);
    }

    // 3. Draw current guide stroke (dotted)
    if (currentStrokeIndex < templateStrokes.length) {
      _drawGuideStroke(
          canvas, size, templateStrokes[currentStrokeIndex],
          completed: false);

      // 4. Pulsing start dot
      if (currentPoints.isEmpty) {
        _drawStartDot(canvas, size, templateStrokes[currentStrokeIndex].first);
      }
    }

    // 5. Draw completed user strokes in gold/green
    for (final stroke in completedStrokes) {
      if (stroke.isNotEmpty) {
        _drawUserStroke(canvas, stroke, completed: true);
      }
    }

    // 6. Draw current user stroke in bright color with glow
    if (currentPoints.isNotEmpty) {
      _drawUserStroke(canvas, currentPoints, completed: false);
    }

    // 7. Sparkle completion effect
    if (isComplete && sparkleValue > 0) {
      _drawSparkles(canvas, size);
    }
  }

  void _drawLetterGlyph(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter.toLowerCase(),
        style: TextStyle(
          fontFamily: 'Fredoka',
          fontSize: size.width * 0.75,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  void _drawGuideStroke(
      Canvas canvas, Size size, List<Offset> stroke,
      {required bool completed}) {
    if (stroke.length < 2) return;

    final paint = Paint()
      ..color = completed
          ? AppColors.success.withValues(alpha: 0.15)
          : guideColor.withValues(alpha: 0.3)
      ..strokeWidth = completed ? 4.0 : 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw as dashed line for incomplete, solid for completed
    final path = Path();
    final pixelPoints = stroke.map((p) => _toPixel(p, size)).toList();
    path.moveTo(pixelPoints.first.dx, pixelPoints.first.dy);
    for (int i = 1; i < pixelPoints.length; i++) {
      path.lineTo(pixelPoints[i].dx, pixelPoints[i].dy);
    }

    if (completed) {
      canvas.drawPath(path, paint);
    } else {
      // Draw dashed
      _drawDashedPath(canvas, path, paint, dashLength: 8, gapLength: 6);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLength = 8, double gapLength = 6}) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  void _drawStartDot(Canvas canvas, Size size, Offset normalizedPos) {
    final center = _toPixel(normalizedPos, size);
    const baseRadius = 8.0;
    final pulseRadius = baseRadius + pulseValue * 6;

    // Outer glow ring
    final glowPaint = Paint()
      ..color = traceColor.withValues(alpha: 0.15 + pulseValue * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, pulseRadius + 4, glowPaint);

    // Middle ring
    final ringPaint = Paint()
      ..color = traceColor.withValues(alpha: 0.3 + pulseValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, pulseRadius, ringPaint);

    // Inner filled dot
    final dotPaint = Paint()
      ..color = traceColor.withValues(alpha: 0.8 + pulseValue * 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius, dotPaint);
  }

  void _drawUserStroke(Canvas canvas, List<Offset> points,
      {required bool completed}) {
    if (points.length < 2) return;

    final color = completed ? AppColors.starGold : traceColor;

    // Glow layer
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = completed ? 14.0 : 12.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    // Use quadratic bezier for smoothness
    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    if (points.length >= 2) {
      path.lineTo(points.last.dx, points.last.dy);
    }

    canvas.drawPath(path, glowPaint);

    // Main stroke layer
    final mainPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = completed ? 6.0 : 5.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, mainPaint);

    // Bright core for non-completed (active drawing feedback)
    if (!completed) {
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, corePaint);
    }
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final random = Random(42); // Fixed seed for consistent sparkle positions
    const sparkleCount = 12;
    const maxRadius = 4.0;

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (i / sparkleCount) * 2 * pi;
      final dist = 20 + random.nextDouble() * (size.width * 0.35);
      final center = Offset(size.width / 2, size.height / 2);

      // Sparkles expand outward during animation
      final expandFactor = sparkleValue;
      final x = center.dx + cos(angle) * dist * expandFactor;
      final y = center.dy + sin(angle) * dist * expandFactor;

      // Fade in then out
      final alpha = sparkleValue < 0.5
          ? sparkleValue * 2
          : (1.0 - sparkleValue) * 2;

      final radius = maxRadius * (0.5 + random.nextDouble() * 0.5);

      // Star-shaped sparkle
      final sparklePaint = Paint()
        ..color = AppColors.starGold.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), radius, sparklePaint);

      // Cross lines for sparkle effect
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: (alpha * 0.7).clamp(0.0, 1.0))
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      final lineLen = radius * 2;
      canvas.drawLine(
        Offset(x - lineLen, y),
        Offset(x + lineLen, y),
        linePaint,
      );
      canvas.drawLine(
        Offset(x, y - lineLen),
        Offset(x, y + lineLen),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) {
    return oldDelegate.currentStrokeIndex != currentStrokeIndex ||
        oldDelegate.currentPoints.length != currentPoints.length ||
        oldDelegate.completedStrokes.length != completedStrokes.length ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.sparkleValue != sparkleValue ||
        oldDelegate.isComplete != isComplete;
  }
}
