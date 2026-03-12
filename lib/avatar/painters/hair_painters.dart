import 'dart:math';
import 'package:flutter/material.dart';
import '../shader_loader.dart';

/// Whether the hair color index is the special rainbow gradient.
bool isRainbowHair(int colorIndex) => colorIndex == 13;

// ── Color helpers ────────────────────────────────────────────────────

/// Derive a warm highlight (mix toward warm yellow-white, not cold white).
Color _warmHighlight(Color base, [double t = 0.25]) =>
    Color.lerp(base, const Color(0xFFFFF8E0), t)!;

/// Derive a cool shadow (shift toward blue-black for realism).
Color _coolShadow(Color base, [double t = 0.25]) =>
    Color.lerp(base, const Color(0xFF1A1A3E), t)!;

/// Mid-tone between highlight and shadow for strand body.
Color _midTone(Color base) =>
    Color.lerp(base, const Color(0xFFE8E0D0), 0.06)!;

// ── Rainbow spectrum for SweepGradient ──────────────────────────────

const List<Color> _rainbowColors = [
  Color(0xFFFF4444),
  Color(0xFFFF8C42),
  Color(0xFFFFD700),
  Color(0xFF00E68A),
  Color(0xFF4A90D9),
  Color(0xFF9B59B6),
  Color(0xFFFF4444),
];

// ── Sway / bounce constants ─────────────────────────────────────────

/// Sway amplitude for the single natural style (medium-length hair).
const double _swayAmplitude = 0.020;

/// Wind sensitivity for medium-length hair.
const double _windSens = 0.08;

/// Bounce sensitivity for medium-length hair.
const double _bounceSens = 0.05;

/// Phase offsets for follow-through delay between strand groups.
const List<double> _phaseOffsets = [0.0, 0.3, 0.6, 0.9, 1.2];

// ── Shared geometry helpers ─────────────────────────────────────────

/// Compute sway offset with follow-through phase, wind, and bounce.
double _computeSway(double swayValue,
    [int phase = 0, double windStrength = 0.0]) {
  final offset = _phaseOffsets[phase.clamp(0, 4)];
  final baseSway = sin(swayValue * pi + offset) * _swayAmplitude;
  final wind = windStrength * _windSens;
  return baseSway + wind;
}

/// Compute vertical bounce offset.
double _computeBounce(double bounceValue, [int phase = 0]) {
  if (bounceValue <= 0.001) return 0.0;
  final offset = _phaseOffsets[phase.clamp(0, 4)];
  return sin(bounceValue * pi * 2 + offset) * _bounceSens * bounceValue;
}

/// Build a hair strand as a filled bezier shape with width tapering
/// from root to tip. Uses computed normals for smooth edges.
Path _buildStrand(List<Offset> points, double baseWidth) {
  if (points.length < 2) return Path();
  final left = <Offset>[];
  final right = <Offset>[];
  for (int i = 0; i < points.length; i++) {
    final t = i / (points.length - 1);
    // Taper: full width at root, 25% at tip
    final w = baseWidth * (1.0 - t * 0.75);
    Offset tangent;
    if (i == 0) {
      tangent = points[1] - points[0];
    } else if (i == points.length - 1) {
      tangent = points[i] - points[i - 1];
    } else {
      tangent = points[i + 1] - points[i - 1];
    }
    final len = tangent.distance;
    if (len < 0.001) {
      left.add(points[i]);
      right.add(points[i]);
      continue;
    }
    final normal = Offset(-tangent.dy / len, tangent.dx / len);
    left.add(points[i] + normal * w);
    right.add(points[i] - normal * w);
  }
  final path = Path();
  path.moveTo(left[0].dx, left[0].dy);
  for (int i = 1; i < left.length; i++) {
    final prev = left[i - 1];
    final curr = left[i];
    path.quadraticBezierTo(
        prev.dx, prev.dy, (prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
  }
  path.lineTo(left.last.dx, left.last.dy);
  path.lineTo(right.last.dx, right.last.dy);
  for (int i = right.length - 2; i >= 0; i--) {
    final prev = right[i + 1];
    final curr = right[i];
    path.quadraticBezierTo(
        prev.dx, prev.dy, (prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
  }
  path.lineTo(right[0].dx, right[0].dy);
  path.close();
  return path;
}

/// Create anisotropic highlight paint — dual specular bands (Marschner R + TT)
/// that shift with sway for a living shimmer effect.
Paint _anisotropicHighlightPaint(
    Color color, bool isRainbow, Rect bounds, double swayValue) {
  final baseC = isRainbow ? const Color(0xFFFFD700) : color;
  final warmHl = _warmHighlight(baseC, 0.35);
  final coolHl = _coolShadow(baseC, 0.10);
  final bandCenter = 0.25 + sin(swayValue * pi) * 0.15;
  // Secondary TT lobe offset by 0.3
  final band2Center = (bandCenter + 0.30).clamp(0.0, 1.0);
  return Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        warmHl.withValues(alpha: 0.0),
        warmHl.withValues(alpha: 0.30),
        warmHl.withValues(alpha: 0.55),
        warmHl.withValues(alpha: 0.30),
        warmHl.withValues(alpha: 0.0),
        coolHl.withValues(alpha: 0.0),
        coolHl.withValues(alpha: 0.18),
        coolHl.withValues(alpha: 0.30),
        coolHl.withValues(alpha: 0.18),
        coolHl.withValues(alpha: 0.0),
      ],
      stops: [
        (bandCenter - 0.20).clamp(0.0, 1.0),
        (bandCenter - 0.08).clamp(0.0, 1.0),
        bandCenter.clamp(0.0, 1.0),
        (bandCenter + 0.08).clamp(0.0, 1.0),
        (bandCenter + 0.20).clamp(0.0, 1.0),
        (band2Center - 0.15).clamp(0.0, 1.0),
        (band2Center - 0.05).clamp(0.0, 1.0),
        band2Center.clamp(0.0, 1.0),
        (band2Center + 0.05).clamp(0.0, 1.0),
        (band2Center + 0.15).clamp(0.0, 1.0),
      ],
    ).createShader(bounds);
}

/// Pre-compute a small palette of tinted strand paints for color variation.
/// Returns a list of paints alternating warm-shifted and cool-shifted.
List<Paint> _buildStrandPaints(Color baseColor, int count) {
  final paints = <Paint>[];
  for (int i = 0; i < count; i++) {
    final Color tinted;
    if (i.isEven) {
      // Even strands: shift 8-12% toward warm highlight (sun-bleached)
      final t = 0.08 + (i % 4) * 0.02;
      tinted = Color.lerp(baseColor, _warmHighlight(baseColor), t)!;
    } else {
      // Odd strands: shift 5-10% toward cool shadow (underlayer)
      final t = 0.05 + ((i - 1) % 4) * 0.025;
      tinted = Color.lerp(baseColor, _coolShadow(baseColor), t)!;
    }
    paints.add(Paint()
      ..color = tinted
      ..style = PaintingStyle.fill);
  }
  return paints;
}

/// Draw a strand group (3-5 strands offset for volume).
/// Each strand gets a unique color tint for visible individuation.
/// [baseColor] is the hair color used to derive per-strand tints.
/// If [baseColor] is null, falls back to uniform [fillPaint] (e.g. rainbow).
void _drawStrandGroup(
  Canvas canvas,
  List<Offset> centerPoints,
  double baseWidth,
  Paint fillPaint,
  Paint? highlightPaint, {
  int strandCount = 4,
  double spreadFactor = 0.3,
  Color? baseColor,
}) {
  // Pre-compute tinted paints (small array, not per-frame-per-strand)
  final List<Paint>? tintedPaints =
      baseColor != null ? _buildStrandPaints(baseColor, strandCount) : null;

  for (int s = 0; s < strandCount; s++) {
    final offset = (s - strandCount / 2) * baseWidth * spreadFactor;
    final strandPoints =
        centerPoints.map((p) => Offset(p.dx + offset, p.dy)).toList();
    final path = _buildStrand(strandPoints, baseWidth * 0.6);
    canvas.drawPath(path, tintedPaints?[s] ?? fillPaint);
  }
  if (highlightPaint != null) {
    final hlPath = _buildStrand(centerPoints, baseWidth * 0.5);
    canvas.drawPath(hlPath, highlightPaint);
  }
}

// ── Face edge data ──────────────────────────────────────────────────

typedef _BackEdge = ({double left, double right, double top});
typedef _FrontEdge = ({
  double oL,
  double oR,
  double oB,
  double iL,
  double iR,
  double iT
});

_BackEdge _backEdge(int faceShape) {
  switch (faceShape) {
    case 1:
      return (left: 0.16, right: 0.84, top: 0.19);
    case 2:
      return (left: 0.22, right: 0.78, top: 0.18);
    case 3:
      return (left: 0.20, right: 0.80, top: 0.19);
    case 4:
      return (left: 0.26, right: 0.74, top: 0.18);
    default:
      return (left: 0.18, right: 0.82, top: 0.19);
  }
}

_FrontEdge _frontEdge(int faceShape) {
  switch (faceShape) {
    case 1:
      return (
        oL: 0.12, oR: 0.88, oB: 0.38, iL: 0.16, iR: 0.84, iT: 0.20
      );
    case 2:
      return (
        oL: 0.14, oR: 0.86, oB: 0.36, iL: 0.22, iR: 0.78, iT: 0.19
      );
    case 3:
      return (
        oL: 0.12, oR: 0.88, oB: 0.37, iL: 0.18, iR: 0.82, iT: 0.20
      );
    case 4:
      return (
        oL: 0.14, oR: 0.86, oB: 0.36, iL: 0.24, iR: 0.76, iT: 0.19
      );
    default:
      return (
        oL: 0.13, oR: 0.87, oB: 0.37, iL: 0.18, iR: 0.82, iT: 0.20
      );
  }
}

// ======================================================================
//  HAIR BACK PAINTER — renders behind face
// ======================================================================

/// Renders the back layer of hair (behind the face).
///
/// Single perfected medium-length natural style with organic bezier curves,
/// strand texture, and sway/wind/bounce animation.
///
/// Parameters:
/// - [swayValue] 0.0-1.0 from idle sway AnimationController
/// - [windStrength] 0.0-1.0 for celebration wind effect (0 = none, 1 = strong)
/// - [bounceValue] 0.0-1.0 for jump/celebrate vertical bounce
class HairBackPainter extends CustomPainter {
  final int style;
  final Color color;
  final bool isRainbow;
  final int faceShape;
  final double swayValue;
  final double windStrength;
  final double bounceValue;

  HairBackPainter({
    required this.style,
    required this.color,
    this.isRainbow = false,
    this.faceShape = 0,
    this.swayValue = 0.0,
    this.windStrength = 0.0,
    this.bounceValue = 0.0,
    super.repaint,
  });

  // Cached paints (allocated once, not per-frame)
  static final Paint _shadowPaint = Paint()
    ..color = const Color(0xFF0A0A1A).withValues(alpha: 0.18)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  Paint _massPaint(Rect bounds) {
    if (isRainbow) {
      return Paint()
        ..shader = const SweepGradient(
          center: Alignment.center,
          colors: _rainbowColors,
        ).createShader(bounds);
    }
    final hi = _warmHighlight(color);
    final mid = _midTone(color);
    final sh = _coolShadow(color);
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [hi, mid, color, sh],
        stops: const [0.0, 0.25, 0.55, 1.0],
      ).createShader(bounds);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ie = _backEdge(faceShape);
    final bounds = Rect.fromLTWH(0, 0, w, h);
    final paint = _massPaint(bounds)..style = PaintingStyle.fill;
    final hlPaint =
        _anisotropicHighlightPaint(color, isRainbow, bounds, swayValue);

    switch (style) {
      case 0: // Short
        _drawShortBack(canvas, w, h, ie, paint, hlPaint);
        break;
      case 1: // Long
      case 3: // Wavy (→ long variant)
        _drawLongBack(canvas, w, h, ie, paint, hlPaint);
        break;
      case 2: // Curly
        _drawCurlyBack(canvas, w, h, ie, paint, hlPaint);
        break;
      case 4: // Ponytail
      case 11: // Braids (→ ponytail variant)
        _drawPonytailBack(canvas, w, h, ie, paint, hlPaint);
        break;
      case 5: // Buzz
        _drawBuzzBack(canvas, w, h, ie, paint, hlPaint);
        break;
      case 6: // Afro
        _drawAfroBack(canvas, w, h, ie, paint, hlPaint);
        break;
      case 8: // Pigtails
        _drawPigtailsBack(canvas, w, h, ie, paint, hlPaint);
        break;
      case 9: // Bob
        _drawBobBack(canvas, w, h, ie, paint, hlPaint);
        break;
      default: // 7, 10, 12-15 — natural medium
        _drawNaturalBack(canvas, w, h, ie, paint, hlPaint);
        break;
    }
  }

  /// Medium-length natural hair — organic dome with flowing side strands.
  void _drawNaturalBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final sway1 = _computeSway(swayValue, 1, windStrength);
    final sway2 = _computeSway(swayValue, 2, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // ── Shadow silhouette ──
    final shadowPath = Path()
      ..moveTo(w * (0.08 + sway0), h * (0.72 + bounce0))
      ..cubicTo(w * 0.06, h * 0.50, w * 0.08, h * 0.18,
          w * 0.50, h * 0.04)
      ..cubicTo(w * 0.92, h * 0.18, w * 0.94, h * 0.50,
          w * (0.92 + sway0), h * (0.72 + bounce0))
      ..close();
    canvas.drawPath(shadowPath, _shadowPaint);

    // ── Multi-tone depth layering ──
    // Layer 1: Deep shadow base — full dome in darkened color for depth
    final deepShadowColor = _coolShadow(color, 0.35);
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = deepShadowColor
          ..style = PaintingStyle.fill);

    final massPath = Path()
      ..moveTo(w * (0.07 + sway0), h * (0.70 + bounce0))
      ..cubicTo(
          w * 0.05, h * 0.48,
          w * 0.07, h * 0.14,
          w * 0.50, h * 0.03)
      ..cubicTo(
          w * 0.93, h * 0.14,
          w * 0.95, h * 0.48,
          w * (0.93 + sway0), h * (0.70 + bounce0))
      ..close();
    canvas.drawPath(massPath, deepPaint);

    // Layer 2: Mid-tone volume — slightly smaller dome (inset ~2%)
    final midPath = Path()
      ..moveTo(w * (0.09 + sway0), h * (0.68 + bounce0))
      ..cubicTo(
          w * 0.07, h * 0.48,
          w * 0.09, h * 0.16,
          w * 0.50, h * 0.05)
      ..cubicTo(
          w * 0.91, h * 0.16,
          w * 0.93, h * 0.48,
          w * (0.91 + sway0), h * (0.68 + bounce0))
      ..close();
    canvas.drawPath(midPath, paint);

    // Layer 3: Crown highlight — radial glow at top 30% for 3D roundness
    if (!isRainbow) {
      final crownHlColor = _warmHighlight(color, 0.30);
      final crownPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.6),
          radius: 0.5,
          colors: [
            crownHlColor.withValues(alpha: 0.15),
            crownHlColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(midPath, crownPaint);
    }

    // ── Soft side flows (left) ──
    // Smooth tapered side panels that merge from the dome, not blocky strands.
    // Each side gets one solid flowing shape + a couple of soft strand accents.
    {
      final sSway = _computeSway(swayValue, 1, windStrength);
      final sBounce = _computeBounce(bounceValue, 1);
      final leftFlow = Path()
        // Start at dome edge, ear level
        ..moveTo(w * 0.10, h * 0.28)
        // Flow outward and down, hugging the head
        ..cubicTo(
            w * 0.06, h * 0.35,
            w * (0.05 + sSway * 0.3), h * 0.50,
            w * (0.08 + sSway * 0.5), h * (0.68 + sBounce * 0.4))
        // Taper inward at the tip
        ..cubicTo(
            w * (0.12 + sSway * 0.3), h * (0.66 + sBounce * 0.3),
            w * 0.14, h * 0.50,
            w * 0.15, h * 0.30)
        ..close();
      canvas.drawPath(leftFlow, paint);
      // Soft accent strands on left
      for (int s = 0; s < 2; s++) {
        final phase = s + 1;
        final asSway = _computeSway(swayValue, phase, windStrength);
        final asBounce = _computeBounce(bounceValue, phase);
        final strand = [
          Offset(w * (0.12 + s * 0.015), h * 0.30),
          Offset(w * (0.09 + s * 0.01 + asSway * 0.3), h * (0.44 + asBounce * 0.2)),
          Offset(w * (0.08 + s * 0.005 + asSway * 0.5), h * (0.58 + asBounce * 0.4)),
        ];
        _drawStrandGroup(canvas, strand, w * 0.025, paint, hlPaint,
            strandCount: 3, spreadFactor: 0.2,
            baseColor: isRainbow ? null : color);
      }
    }

    // ── Soft side flows (right) ──
    {
      final sSway = _computeSway(swayValue, 3, windStrength);
      final sBounce = _computeBounce(bounceValue, 3);
      final rightFlow = Path()
        ..moveTo(w * 0.90, h * 0.28)
        ..cubicTo(
            w * 0.94, h * 0.35,
            w * (0.95 + sSway * 0.3), h * 0.50,
            w * (0.92 + sSway * 0.5), h * (0.68 + sBounce * 0.4))
        ..cubicTo(
            w * (0.88 + sSway * 0.3), h * (0.66 + sBounce * 0.3),
            w * 0.86, h * 0.50,
            w * 0.85, h * 0.30)
        ..close();
      canvas.drawPath(rightFlow, paint);
      for (int s = 0; s < 2; s++) {
        final phase = s + 3;
        final asSway = _computeSway(swayValue, phase, windStrength);
        final asBounce = _computeBounce(bounceValue, phase);
        final strand = [
          Offset(w * (0.88 - s * 0.015), h * 0.30),
          Offset(w * (0.91 - s * 0.01 + asSway * 0.3), h * (0.44 + asBounce * 0.2)),
          Offset(w * (0.92 - s * 0.005 + asSway * 0.5), h * (0.58 + asBounce * 0.4)),
        ];
        _drawStrandGroup(canvas, strand, w * 0.025, paint, hlPaint,
            strandCount: 3, spreadFactor: 0.2,
            baseColor: isRainbow ? null : color);
      }
    }

    // ── Visible wavy texture lines on the dome ──
    // 5 alternating warm/cool lines for strand flow direction.
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final texWarm = Paint()
      ..color = _warmHighlight(baseC).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    final texCool = Paint()
      ..color = _coolShadow(baseC, 0.15).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final xOff = -0.08 + i * 0.04;
      final iSway = _computeSway(swayValue, i.clamp(0, 4), windStrength);
      final wavyLine = Path()
        ..moveTo(w * (0.35 + xOff), h * 0.12)
        ..cubicTo(
            w * (0.38 + xOff + iSway * 0.2), h * 0.22,
            w * (0.32 + xOff + iSway * 0.4), h * 0.35,
            w * (0.30 + xOff + sway1 * 0.5), h * 0.48)
        ..cubicTo(
            w * (0.28 + xOff + sway2 * 0.6), h * 0.56,
            w * (0.26 + xOff + sway2 * 0.7), h * 0.62,
            w * (0.24 + xOff + sway2 * 0.8), h * (0.68 + bounce0 * 0.3));
      canvas.drawPath(wavyLine, i.isEven ? texWarm : texCool);
    }

    // ── Volumetric strand overlay on dome ──
    // 9 filled strand shapes fanning from crown, creating visible hair clumps.
    {
      final strandPaints = isRainbow
          ? null
          : _buildStrandPaints(color, 9);

      // Each strand: (startX, control offsets, endX, endY, width, phase)
      const strandData = <(double, double, double, double, double, int)>[
        // (xStart, xDrift, endY, width, widthMul*1000, phase)
        (0.48, -0.14, 0.65, 0.018, 0, 0),  // center-left
        (0.50, -0.08, 0.62, 0.020, 0, 1),  // center
        (0.52,  0.00, 0.60, 0.022, 0, 0),  // center-right
        (0.46, -0.20, 0.67, 0.016, 0, 2),  // mid-left
        (0.54,  0.08, 0.62, 0.018, 0, 1),  // mid-right
        (0.42, -0.26, 0.68, 0.015, 0, 3),  // far-left
        (0.58,  0.16, 0.65, 0.015, 0, 2),  // far-right
        (0.40, -0.30, 0.66, 0.016, 0, 4),  // outer-left
        (0.60,  0.22, 0.67, 0.016, 0, 3),  // outer-right
      ];

      for (int i = 0; i < strandData.length; i++) {
        final d = strandData[i];
        final sSway = _computeSway(swayValue, d.$6, windStrength);
        final sBounce = _computeBounce(bounceValue, d.$6);
        final points = [
          Offset(w * d.$1, h * 0.06),
          Offset(w * (d.$1 + d.$2 * 0.3 + sSway * 0.15),
              h * (0.20 + sBounce * 0.1)),
          Offset(w * (d.$1 + d.$2 * 0.65 + sSway * 0.30),
              h * (0.38 + sBounce * 0.2)),
          Offset(w * (d.$1 + d.$2 + sSway * 0.50),
              h * (d.$3 + sBounce * 0.3)),
        ];
        final strandPath = _buildStrand(points, w * d.$4);
        canvas.drawPath(
            strandPath, strandPaints?[i] ?? paint);
      }
    }

    // ── Subsurface scattering rim light ──
    // Warm glow around dome silhouette, strongest at sides (backlight effect).
    {
      final rimColor = _warmHighlight(baseC, 0.40);
      final rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4)
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            rimColor.withValues(alpha: 0.22),
            rimColor.withValues(alpha: 0.0),
            rimColor.withValues(alpha: 0.0),
            rimColor.withValues(alpha: 0.22),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      // Reuse dome silhouette path for the rim
      final rimPath = Path()
        ..moveTo(w * (0.07 + sway0), h * (0.70 + bounce0))
        ..cubicTo(
            w * 0.05, h * 0.48,
            w * 0.07, h * 0.14,
            w * 0.50, h * 0.03)
        ..cubicTo(
            w * 0.93, h * 0.14,
            w * 0.95, h * 0.48,
            w * (0.93 + sway0), h * (0.70 + bounce0));
      canvas.drawPath(rimPath, rimPaint);
    }

    // ── Hair-to-neck shadow ──
    // Blurred shadow band at dome bottom suggesting hair mass over neck.
    {
      final neckShadow = Paint()
        ..color = _coolShadow(baseC, 0.30).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.025;
      final neckPath = Path()
        ..moveTo(w * (0.12 + sway0), h * (0.71 + bounce0))
        ..quadraticBezierTo(
            w * 0.50, h * (0.74 + bounce0),
            w * (0.88 + sway0), h * (0.71 + bounce0));
      canvas.drawPath(neckPath, neckShadow);
    }

    // ── Edge flyaway strands beyond dome silhouette ──
    // 10 thin individual hairs for a soft, natural edge.
    final flyawayPaint = Paint()
      ..color = _warmHighlight(baseC, 0.30).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.004
      ..strokeCap = StrokeCap.round;

    // Pre-defined flyaway curves (left side, right side, top)
    const flyawayData = <(double, double, double, double, double, double, double, double, int)>[
      // (startX, startY, cp1X, cp1Y, cp2X, cp2Y, endX, endY, phase)
      (0.08, 0.30, 0.04, 0.38, 0.03, 0.48, 0.05, 0.58, 0),   // left 1
      (0.09, 0.25, 0.05, 0.32, 0.04, 0.42, 0.06, 0.52, 1),   // left 2
      (0.07, 0.35, 0.03, 0.44, 0.02, 0.54, 0.04, 0.62, 2),   // left 3
      (0.10, 0.22, 0.06, 0.28, 0.05, 0.36, 0.07, 0.44, 1),   // left 4
      (0.92, 0.30, 0.96, 0.38, 0.97, 0.48, 0.95, 0.58, 0),   // right 1
      (0.91, 0.25, 0.95, 0.32, 0.96, 0.42, 0.94, 0.52, 1),   // right 2
      (0.93, 0.35, 0.97, 0.44, 0.98, 0.54, 0.96, 0.62, 2),   // right 3
      (0.90, 0.22, 0.94, 0.28, 0.95, 0.36, 0.93, 0.44, 1),   // right 4
      (0.30, 0.06, 0.25, 0.04, 0.20, 0.05, 0.16, 0.10, 0),   // top left
      (0.70, 0.06, 0.75, 0.04, 0.80, 0.05, 0.84, 0.10, 2),   // top right
    ];

    for (final f in flyawayData) {
      final fSway = _computeSway(swayValue, f.$9, windStrength) * 1.5;
      final fBounce = _computeBounce(bounceValue, f.$9);
      final flyaway = Path()
        ..moveTo(w * f.$1, h * (f.$2 + fBounce * 0.2))
        ..cubicTo(
            w * (f.$3 + fSway * 0.3), h * (f.$4 + fBounce * 0.3),
            w * (f.$5 + fSway * 0.5), h * (f.$6 + fBounce * 0.4),
            w * (f.$7 + fSway * 0.6), h * (f.$8 + fBounce * 0.5));
      canvas.drawPath(flyaway, flyawayPaint);
    }

    // ── Part line — subtle lighter line from crown to right ──
    final partPaint = Paint()
      ..color = _warmHighlight(baseC, 0.35).withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.005
      ..strokeCap = StrokeCap.round;
    final partLine = Path()
      ..moveTo(w * 0.50, h * 0.05)
      ..cubicTo(
          w * 0.52, h * 0.08,
          w * 0.54, h * 0.12,
          w * 0.55, h * 0.18);
    canvas.drawPath(partLine, partPaint);
  }

  // ── Short (style 0) — compact dome ending above ears ──

  void _drawShortBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // Shadow
    final shadowPath = Path()
      ..moveTo(w * (0.14 + sway0), h * (0.48 + bounce0))
      ..cubicTo(w * 0.10, h * 0.35, w * 0.12, h * 0.16,
          w * 0.50, h * 0.05)
      ..cubicTo(w * 0.88, h * 0.16, w * 0.90, h * 0.35,
          w * (0.86 + sway0), h * (0.48 + bounce0))
      ..close();
    canvas.drawPath(shadowPath, _shadowPaint);

    // Deep shadow base
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.35)
          ..style = PaintingStyle.fill);
    final massPath = Path()
      ..moveTo(w * (0.13 + sway0), h * (0.46 + bounce0))
      ..cubicTo(w * 0.09, h * 0.34, w * 0.11, h * 0.14,
          w * 0.50, h * 0.04)
      ..cubicTo(w * 0.89, h * 0.14, w * 0.91, h * 0.34,
          w * (0.87 + sway0), h * (0.46 + bounce0))
      ..close();
    canvas.drawPath(massPath, deepPaint);

    // Mid-tone layer
    final midPath = Path()
      ..moveTo(w * (0.15 + sway0), h * (0.44 + bounce0))
      ..cubicTo(w * 0.11, h * 0.34, w * 0.13, h * 0.16,
          w * 0.50, h * 0.06)
      ..cubicTo(w * 0.87, h * 0.16, w * 0.89, h * 0.34,
          w * (0.85 + sway0), h * (0.44 + bounce0))
      ..close();
    canvas.drawPath(midPath, paint);

    // Crown highlight
    if (!isRainbow) {
      final crownPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.6),
          radius: 0.4,
          colors: [
            _warmHighlight(color, 0.30).withValues(alpha: 0.18),
            _warmHighlight(color, 0.30).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(midPath, crownPaint);
    }

    // Subtle texture dots for cropped-sides feel
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final dotPaint = Paint()
      ..color = _warmHighlight(baseC, 0.20).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final rng = Random(42);
    for (int i = 0; i < 20; i++) {
      final dx = w * (0.20 + rng.nextDouble() * 0.60);
      final dy = h * (0.10 + rng.nextDouble() * 0.30);
      canvas.drawCircle(Offset(dx, dy), w * 0.004, dotPaint);
    }
  }

  // ── Long (style 1) — natural dome extending much lower ──

  void _drawLongBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final sway1 = _computeSway(swayValue, 1, windStrength);
    final sway2 = _computeSway(swayValue, 2, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // Shadow
    final shadowPath = Path()
      ..moveTo(w * (0.10 + sway0), h * (0.90 + bounce0))
      ..cubicTo(w * 0.06, h * 0.55, w * 0.08, h * 0.18,
          w * 0.50, h * 0.04)
      ..cubicTo(w * 0.92, h * 0.18, w * 0.94, h * 0.55,
          w * (0.90 + sway0), h * (0.90 + bounce0))
      ..close();
    canvas.drawPath(shadowPath, _shadowPaint);

    // Deep shadow base
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.35)
          ..style = PaintingStyle.fill);
    final massPath = Path()
      ..moveTo(w * (0.09 + sway0), h * (0.88 + bounce0))
      ..cubicTo(w * 0.05, h * 0.52, w * 0.07, h * 0.14,
          w * 0.50, h * 0.03)
      ..cubicTo(w * 0.93, h * 0.14, w * 0.95, h * 0.52,
          w * (0.91 + sway0), h * (0.88 + bounce0))
      ..close();
    canvas.drawPath(massPath, deepPaint);

    // Mid-tone layer
    final midPath = Path()
      ..moveTo(w * (0.11 + sway0), h * (0.86 + bounce0))
      ..cubicTo(w * 0.07, h * 0.50, w * 0.09, h * 0.16,
          w * 0.50, h * 0.05)
      ..cubicTo(w * 0.91, h * 0.16, w * 0.93, h * 0.50,
          w * (0.89 + sway0), h * (0.86 + bounce0))
      ..close();
    canvas.drawPath(midPath, paint);

    // Crown highlight
    if (!isRainbow) {
      final crownPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.6),
          radius: 0.5,
          colors: [
            _warmHighlight(color, 0.30).withValues(alpha: 0.15),
            _warmHighlight(color, 0.30).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(midPath, crownPaint);
    }

    // Long flowing side strands — left
    for (int s = 0; s < 3; s++) {
      final phase = s + 1;
      final sSway = _computeSway(swayValue, phase, windStrength);
      final sBounce = _computeBounce(bounceValue, phase);
      final strand = [
        Offset(w * (0.12 + s * 0.015), h * 0.28),
        Offset(w * (0.09 + s * 0.01 + sSway * 0.3), h * (0.48 + sBounce * 0.2)),
        Offset(w * (0.07 + s * 0.005 + sSway * 0.5), h * (0.68 + sBounce * 0.3)),
        Offset(w * (0.08 + s * 0.005 + sSway * 0.6), h * (0.85 + sBounce * 0.4)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.028, paint, hlPaint,
          strandCount: 4, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Long flowing side strands — right
    for (int s = 0; s < 3; s++) {
      final phase = s + 3;
      final sSway = _computeSway(swayValue, phase.clamp(0, 4), windStrength);
      final sBounce = _computeBounce(bounceValue, phase.clamp(0, 4));
      final strand = [
        Offset(w * (0.88 - s * 0.015), h * 0.28),
        Offset(w * (0.91 - s * 0.01 + sSway * 0.3), h * (0.48 + sBounce * 0.2)),
        Offset(w * (0.93 - s * 0.005 + sSway * 0.5), h * (0.68 + sBounce * 0.3)),
        Offset(w * (0.92 - s * 0.005 + sSway * 0.6), h * (0.85 + sBounce * 0.4)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.028, paint, hlPaint,
          strandCount: 4, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Wavy texture lines on dome
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final texWarm = Paint()
      ..color = _warmHighlight(baseC).withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.010
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final xOff = -0.08 + i * 0.04;
      final iSway = _computeSway(swayValue, i.clamp(0, 4), windStrength);
      final wavyLine = Path()
        ..moveTo(w * (0.35 + xOff), h * 0.12)
        ..cubicTo(
            w * (0.38 + xOff + iSway * 0.2), h * 0.28,
            w * (0.32 + xOff + iSway * 0.4), h * 0.50,
            w * (0.28 + xOff + sway1 * 0.5), h * 0.72)
        ..cubicTo(
            w * (0.26 + xOff + sway2 * 0.6), h * 0.78,
            w * (0.25 + xOff + sway2 * 0.7), h * 0.82,
            w * (0.24 + xOff + sway2 * 0.8), h * (0.88 + bounce0 * 0.3));
      canvas.drawPath(wavyLine, texWarm);
    }

    // Bottom edge hair-to-neck shadow
    final neckShadow = Paint()
      ..color = _coolShadow(baseC, 0.30).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.025;
    final neckPath = Path()
      ..moveTo(w * (0.14 + sway0), h * (0.89 + bounce0))
      ..quadraticBezierTo(
          w * 0.50, h * (0.92 + bounce0),
          w * (0.86 + sway0), h * (0.89 + bounce0));
    canvas.drawPath(neckPath, neckShadow);
  }

  // ── Curly (style 2) — wider, bouncier mass with round bezier outlines ──

  void _drawCurlyBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // Shadow — wider than natural
    final shadowPath = Path()
      ..moveTo(w * (0.03 + sway0), h * (0.78 + bounce0))
      ..cubicTo(w * 0.00, h * 0.50, w * 0.04, h * 0.14,
          w * 0.50, h * 0.02)
      ..cubicTo(w * 0.96, h * 0.14, w * 1.00, h * 0.50,
          w * (0.97 + sway0), h * (0.78 + bounce0))
      ..close();
    canvas.drawPath(shadowPath, _shadowPaint);

    // Deep shadow base — extra wide
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.35)
          ..style = PaintingStyle.fill);
    final massPath = Path()
      ..moveTo(w * (0.02 + sway0), h * (0.76 + bounce0))
      ..cubicTo(w * -0.01, h * 0.48, w * 0.03, h * 0.12,
          w * 0.50, h * 0.01)
      ..cubicTo(w * 0.97, h * 0.12, w * 1.01, h * 0.48,
          w * (0.98 + sway0), h * (0.76 + bounce0))
      ..close();
    canvas.drawPath(massPath, deepPaint);

    // Mid-tone layer
    final midPath = Path()
      ..moveTo(w * (0.04 + sway0), h * (0.74 + bounce0))
      ..cubicTo(w * 0.01, h * 0.48, w * 0.05, h * 0.14,
          w * 0.50, h * 0.03)
      ..cubicTo(w * 0.95, h * 0.14, w * 0.99, h * 0.48,
          w * (0.96 + sway0), h * (0.74 + bounce0))
      ..close();
    canvas.drawPath(midPath, paint);

    // Crown highlight
    if (!isRainbow) {
      final crownPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.5),
          radius: 0.6,
          colors: [
            _warmHighlight(color, 0.30).withValues(alpha: 0.15),
            _warmHighlight(color, 0.30).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(midPath, crownPaint);
    }

    // Curly bumps along the edges — bouncy bezier semicircles
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final curlPaint = Paint()
      ..color = (isRainbow ? baseC : _midTone(color)).withValues(alpha: 0.50)
      ..style = PaintingStyle.fill;
    final curlHighlight = Paint()
      ..color = _warmHighlight(baseC, 0.25).withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    // Left edge curls
    for (int i = 0; i < 6; i++) {
      final phase = i % 5;
      final cSway = _computeSway(swayValue, phase, windStrength);
      final cBounce = _computeBounce(bounceValue, phase);
      final cy = h * (0.22 + i * 0.09 + cBounce * 0.2);
      final cx = w * (0.06 + cSway * 0.3);
      final r = w * (0.045 + (i % 2) * 0.01);
      canvas.drawCircle(Offset(cx, cy), r, curlPaint);
      canvas.drawCircle(Offset(cx + r * 0.2, cy - r * 0.3), r * 0.4, curlHighlight);
    }

    // Right edge curls
    for (int i = 0; i < 6; i++) {
      final phase = (i + 2) % 5;
      final cSway = _computeSway(swayValue, phase, windStrength);
      final cBounce = _computeBounce(bounceValue, phase);
      final cy = h * (0.22 + i * 0.09 + cBounce * 0.2);
      final cx = w * (0.94 + cSway * 0.3);
      final r = w * (0.045 + (i % 2) * 0.01);
      canvas.drawCircle(Offset(cx, cy), r, curlPaint);
      canvas.drawCircle(Offset(cx - r * 0.2, cy - r * 0.3), r * 0.4, curlHighlight);
    }

    // Bottom curls
    for (int i = 0; i < 5; i++) {
      final phase = i % 5;
      final cSway = _computeSway(swayValue, phase, windStrength);
      final cx = w * (0.20 + i * 0.15 + cSway * 0.2);
      final cy = h * (0.73 + bounce0 * 0.2);
      final r = w * (0.04 + (i % 2) * 0.008);
      canvas.drawCircle(Offset(cx, cy), r, curlPaint);
      canvas.drawCircle(Offset(cx, cy - r * 0.3), r * 0.35, curlHighlight);
    }
  }

  // ── Ponytail (style 4) — pulled-back top with tail extending down ──

  void _drawPonytailBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway2 = _computeSway(swayValue, 2, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // Tight dome (pulled-back look)
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.30)
          ..style = PaintingStyle.fill);
    final domePath = Path()
      ..moveTo(w * 0.15, h * 0.40)
      ..cubicTo(w * 0.10, h * 0.28, w * 0.14, h * 0.14,
          w * 0.50, h * 0.04)
      ..cubicTo(w * 0.86, h * 0.14, w * 0.90, h * 0.28,
          w * 0.85, h * 0.40)
      ..close();
    canvas.drawPath(domePath, deepPaint);
    canvas.drawPath(domePath, paint);

    // Ponytail tie — small oval at nape
    final tieY = h * 0.38;
    final tiePaint = Paint()
      ..color = _coolShadow(color, 0.50).withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, tieY),
        width: w * 0.10,
        height: h * 0.04,
      ),
      tiePaint,
    );

    // Ponytail flowing down from tie
    final tailSway = sway2 * 1.5;
    final tailPath = Path()
      ..moveTo(w * 0.45, tieY)
      ..cubicTo(
          w * (0.44 + tailSway * 0.2), h * 0.52,
          w * (0.46 + tailSway * 0.4), h * 0.68,
          w * (0.48 + tailSway * 0.5), h * (0.85 + bounce0 * 0.3))
      ..lineTo(w * (0.52 + tailSway * 0.5), h * (0.85 + bounce0 * 0.3))
      ..cubicTo(
          w * (0.54 + tailSway * 0.4), h * 0.68,
          w * (0.56 + tailSway * 0.2), h * 0.52,
          w * 0.55, tieY)
      ..close();
    canvas.drawPath(tailPath, deepPaint);
    canvas.drawPath(tailPath, paint);

    // Tail strands
    for (int s = 0; s < 5; s++) {
      final phase = s % 5;
      final sSway = _computeSway(swayValue, phase, windStrength) * 1.5;
      final sBounce = _computeBounce(bounceValue, phase);
      final xOff = (s - 2) * w * 0.012;
      final strand = [
        Offset(w * 0.50 + xOff, tieY + h * 0.02),
        Offset(w * (0.49 + sSway * 0.2) + xOff, h * (0.52 + sBounce * 0.1)),
        Offset(w * (0.48 + sSway * 0.4) + xOff, h * (0.68 + sBounce * 0.2)),
        Offset(w * (0.49 + sSway * 0.5) + xOff, h * (0.82 + sBounce * 0.3)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.018, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.2,
          baseColor: isRainbow ? null : color);
    }

    // Tail tip tapered highlight
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final tipPaint = Paint()
      ..color = _warmHighlight(baseC, 0.25).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..strokeCap = StrokeCap.round;
    final tipPath = Path()
      ..moveTo(w * (0.49 + tailSway * 0.45), h * (0.78 + bounce0 * 0.25))
      ..cubicTo(
          w * (0.48 + tailSway * 0.50), h * (0.82 + bounce0 * 0.28),
          w * (0.49 + tailSway * 0.52), h * (0.84 + bounce0 * 0.30),
          w * (0.50 + tailSway * 0.50), h * (0.86 + bounce0 * 0.32));
    canvas.drawPath(tipPath, tipPaint);
  }

  // ── Buzz (style 5) — very short, barely extends beyond head ──

  void _drawBuzzBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    // Minimal dome — just slightly beyond head shape
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.30)
          ..style = PaintingStyle.fill);
    final domePath = Path()
      ..moveTo(w * 0.18, h * 0.40)
      ..cubicTo(w * 0.14, h * 0.30, w * 0.16, h * 0.18,
          w * 0.50, h * 0.08)
      ..cubicTo(w * 0.84, h * 0.18, w * 0.86, h * 0.30,
          w * 0.82, h * 0.40)
      ..close();
    canvas.drawPath(domePath, deepPaint);
    canvas.drawPath(domePath, paint);

    // Subtle texture dots for buzz-cut feel
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final dotPaintLight = Paint()
      ..color = _warmHighlight(baseC, 0.20).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final dotPaintDark = Paint()
      ..color = _coolShadow(baseC, 0.15).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final rng = Random(style * 37 + 7);
    for (int i = 0; i < 60; i++) {
      final dx = w * (0.22 + rng.nextDouble() * 0.56);
      final dy = h * (0.12 + rng.nextDouble() * 0.24);
      final r = w * (0.002 + rng.nextDouble() * 0.003);
      canvas.drawCircle(Offset(dx, dy), r, i.isEven ? dotPaintLight : dotPaintDark);
    }
  }

  // ── Afro (style 6) — large round poofy shape, much wider than head ──

  void _drawAfroBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // Extra-large shadow
    final shadowPath = Path()
      ..moveTo(w * (-0.02 + sway0), h * (0.80 + bounce0))
      ..cubicTo(w * -0.08, h * 0.40, w * -0.02, h * 0.02,
          w * 0.50, h * -0.04)
      ..cubicTo(w * 1.02, h * 0.02, w * 1.08, h * 0.40,
          w * (1.02 + sway0), h * (0.80 + bounce0))
      ..close();
    canvas.drawPath(shadowPath, _shadowPaint);

    // Deep base — very wide circular
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.35)
          ..style = PaintingStyle.fill);
    final massPath = Path()
      ..moveTo(w * (-0.03 + sway0), h * (0.78 + bounce0))
      ..cubicTo(w * -0.09, h * 0.38, w * -0.03, h * 0.00,
          w * 0.50, h * -0.05)
      ..cubicTo(w * 1.03, h * 0.00, w * 1.09, h * 0.38,
          w * (1.03 + sway0), h * (0.78 + bounce0))
      ..close();
    canvas.drawPath(massPath, deepPaint);

    // Mid-tone
    final midPath = Path()
      ..moveTo(w * (-0.01 + sway0), h * (0.76 + bounce0))
      ..cubicTo(w * -0.07, h * 0.38, w * -0.01, h * 0.02,
          w * 0.50, h * -0.03)
      ..cubicTo(w * 1.01, h * 0.02, w * 1.07, h * 0.38,
          w * (1.01 + sway0), h * (0.76 + bounce0))
      ..close();
    canvas.drawPath(midPath, paint);

    // Crown highlight
    if (!isRainbow) {
      final crownPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.4),
          radius: 0.7,
          colors: [
            _warmHighlight(color, 0.30).withValues(alpha: 0.18),
            _warmHighlight(color, 0.30).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(midPath, crownPaint);
    }

    // Afro texture — many small bumps around the perimeter
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final bumpPaint = Paint()
      ..color = _midTone(baseC).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final bumpHl = Paint()
      ..color = _warmHighlight(baseC, 0.25).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final rng = Random(61);
    for (int i = 0; i < 30; i++) {
      final angle = i * pi * 2 / 30;
      final radiusX = w * (0.48 + rng.nextDouble() * 0.06);
      final radiusY = h * (0.38 + rng.nextDouble() * 0.04);
      final cx = w * 0.50 + cos(angle) * radiusX + sway0 * w * 0.1 * sin(angle);
      final cy = h * 0.36 + sin(angle) * radiusY + bounce0 * h * 0.05;
      final r = w * (0.025 + rng.nextDouble() * 0.020);
      canvas.drawCircle(Offset(cx, cy), r, bumpPaint);
      canvas.drawCircle(Offset(cx, cy - r * 0.25), r * 0.4, bumpHl);
    }
  }

  // ── Pigtails (style 8) — two bunches on sides ──

  void _drawPigtailsBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway1 = _computeSway(swayValue, 1, windStrength);
    final sway3 = _computeSway(swayValue, 3, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // Tight center dome
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.30)
          ..style = PaintingStyle.fill);
    final domePath = Path()
      ..moveTo(w * 0.16, h * 0.42)
      ..cubicTo(w * 0.12, h * 0.30, w * 0.14, h * 0.14,
          w * 0.50, h * 0.04)
      ..cubicTo(w * 0.86, h * 0.14, w * 0.88, h * 0.30,
          w * 0.84, h * 0.42)
      ..close();
    canvas.drawPath(domePath, deepPaint);
    canvas.drawPath(domePath, paint);

    // Left pigtail
    final leftTieY = h * 0.34;
    final leftTieX = w * 0.18;
    // Tie
    final tiePaint = Paint()
      ..color = _coolShadow(color, 0.50).withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(leftTieX, leftTieY), width: w * 0.06, height: h * 0.03),
      tiePaint,
    );
    // Left pigtail body
    final leftTail = Path()
      ..moveTo(leftTieX - w * 0.03, leftTieY)
      ..cubicTo(
          w * (0.10 + sway1 * 0.3), h * 0.48,
          w * (0.08 + sway1 * 0.5), h * 0.62,
          w * (0.10 + sway1 * 0.6), h * (0.78 + bounce0 * 0.3))
      ..lineTo(w * (0.16 + sway1 * 0.6), h * (0.78 + bounce0 * 0.3))
      ..cubicTo(
          w * (0.18 + sway1 * 0.5), h * 0.62,
          w * (0.20 + sway1 * 0.3), h * 0.48,
          leftTieX + w * 0.03, leftTieY)
      ..close();
    canvas.drawPath(leftTail, deepPaint);
    canvas.drawPath(leftTail, paint);

    // Right pigtail
    final rightTieX = w * 0.82;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rightTieX, leftTieY), width: w * 0.06, height: h * 0.03),
      tiePaint,
    );
    final rightTail = Path()
      ..moveTo(rightTieX - w * 0.03, leftTieY)
      ..cubicTo(
          w * (0.80 + sway3 * 0.3), h * 0.48,
          w * (0.82 + sway3 * 0.5), h * 0.62,
          w * (0.84 + sway3 * 0.6), h * (0.78 + bounce0 * 0.3))
      ..lineTo(w * (0.90 + sway3 * 0.6), h * (0.78 + bounce0 * 0.3))
      ..cubicTo(
          w * (0.92 + sway3 * 0.5), h * 0.62,
          w * (0.90 + sway3 * 0.3), h * 0.48,
          rightTieX + w * 0.03, leftTieY)
      ..close();
    canvas.drawPath(rightTail, deepPaint);
    canvas.drawPath(rightTail, paint);

    // Strand details on pigtails
    for (int s = 0; s < 3; s++) {
      final sSway = _computeSway(swayValue, s + 1, windStrength) * 1.2;
      final sBounce = _computeBounce(bounceValue, s + 1);
      final xOff = (s - 1) * w * 0.010;
      // Left
      final lStrand = [
        Offset(leftTieX + xOff, leftTieY + h * 0.02),
        Offset(w * (0.12 + sSway * 0.3) + xOff, h * (0.52 + sBounce * 0.1)),
        Offset(w * (0.11 + sSway * 0.5) + xOff, h * (0.68 + sBounce * 0.2)),
      ];
      _drawStrandGroup(canvas, lStrand, w * 0.016, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.2,
          baseColor: isRainbow ? null : color);
      // Right
      final rStrand = [
        Offset(rightTieX + xOff, leftTieY + h * 0.02),
        Offset(w * (0.88 + sSway * 0.3) + xOff, h * (0.52 + sBounce * 0.1)),
        Offset(w * (0.89 + sSway * 0.5) + xOff, h * (0.68 + sBounce * 0.2)),
      ];
      _drawStrandGroup(canvas, rStrand, w * 0.016, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.2,
          baseColor: isRainbow ? null : color);
    }
  }

  // ── Bob (style 9) — chin-length, clean straight bottom edge ──

  void _drawBobBack(Canvas canvas, double w, double h, _BackEdge ie,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final bounce0 = _computeBounce(bounceValue, 0);

    // Shadow
    final shadowPath = Path()
      ..moveTo(w * (0.08 + sway0), h * (0.62 + bounce0))
      ..lineTo(w * (0.92 + sway0), h * (0.62 + bounce0))
      ..cubicTo(w * 0.94, h * 0.45, w * 0.92, h * 0.18,
          w * 0.50, h * 0.04)
      ..cubicTo(w * 0.08, h * 0.18, w * 0.06, h * 0.45,
          w * (0.08 + sway0), h * (0.62 + bounce0))
      ..close();
    canvas.drawPath(shadowPath, _shadowPaint);

    // Deep shadow base
    final deepPaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.35)
          ..style = PaintingStyle.fill);
    final massPath = Path()
      ..moveTo(w * (0.07 + sway0), h * (0.60 + bounce0))
      ..lineTo(w * (0.93 + sway0), h * (0.60 + bounce0))
      ..cubicTo(w * 0.95, h * 0.44, w * 0.92, h * 0.16,
          w * 0.50, h * 0.03)
      ..cubicTo(w * 0.08, h * 0.16, w * 0.05, h * 0.44,
          w * (0.07 + sway0), h * (0.60 + bounce0))
      ..close();
    canvas.drawPath(massPath, deepPaint);

    // Mid-tone with flat bottom
    final midPath = Path()
      ..moveTo(w * (0.09 + sway0), h * (0.58 + bounce0))
      ..lineTo(w * (0.91 + sway0), h * (0.58 + bounce0))
      ..cubicTo(w * 0.93, h * 0.44, w * 0.90, h * 0.16,
          w * 0.50, h * 0.05)
      ..cubicTo(w * 0.10, h * 0.16, w * 0.07, h * 0.44,
          w * (0.09 + sway0), h * (0.58 + bounce0))
      ..close();
    canvas.drawPath(midPath, paint);

    // Crown highlight
    if (!isRainbow) {
      final crownPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.6),
          radius: 0.5,
          colors: [
            _warmHighlight(color, 0.30).withValues(alpha: 0.15),
            _warmHighlight(color, 0.30).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(midPath, crownPaint);
    }

    // Clean bottom edge emphasis
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final edgePaint = Paint()
      ..color = _coolShadow(baseC, 0.25).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    final edgePath = Path()
      ..moveTo(w * (0.09 + sway0), h * (0.58 + bounce0))
      ..lineTo(w * (0.91 + sway0), h * (0.58 + bounce0));
    canvas.drawPath(edgePath, edgePaint);

    // Inward-curving tips at bottom corners
    final tipPaint = Paint()
      ..color = (isRainbow ? baseC : color).withValues(alpha: 0.50)
      ..style = PaintingStyle.fill;
    // Left tip curl
    final leftTip = Path()
      ..moveTo(w * (0.09 + sway0), h * (0.58 + bounce0))
      ..cubicTo(
          w * (0.08 + sway0), h * (0.60 + bounce0),
          w * (0.10 + sway0), h * (0.62 + bounce0),
          w * (0.13 + sway0), h * (0.60 + bounce0))
      ..close();
    canvas.drawPath(leftTip, tipPaint);
    // Right tip curl
    final rightTip = Path()
      ..moveTo(w * (0.91 + sway0), h * (0.58 + bounce0))
      ..cubicTo(
          w * (0.92 + sway0), h * (0.60 + bounce0),
          w * (0.90 + sway0), h * (0.62 + bounce0),
          w * (0.87 + sway0), h * (0.60 + bounce0))
      ..close();
    canvas.drawPath(rightTip, tipPaint);
  }

  @override
  bool shouldRepaint(HairBackPainter old) =>
      old.style != style ||
      old.color != color ||
      old.isRainbow != isRainbow ||
      old.faceShape != faceShape ||
      (old.swayValue * 100).round() != (swayValue * 100).round() ||
      (old.windStrength * 100).round() != (windStrength * 100).round() ||
      (old.bounceValue * 100).round() != (bounceValue * 100).round();
}

// ======================================================================
//  HAIR FRONT PAINTER — renders on top of face
// ======================================================================

/// Renders the front layer of hair (on top of face).
///
/// Single perfected medium-length natural style with side-swept bangs,
/// individual strand groups, shine streak, and sway animation.
///
/// Parameters:
/// - [swayValue] 0.0-1.0 from idle sway AnimationController
/// - [windStrength] 0.0-1.0 for celebration wind effect (0 = none, 1 = strong)
/// - [bounceValue] 0.0-1.0 for jump/celebrate vertical bounce
class HairFrontPainter extends CustomPainter {
  final int style;
  final Color color;
  final bool isRainbow;
  final int faceShape;
  final double swayValue;
  final double windStrength;
  final double bounceValue;

  HairFrontPainter({
    required this.style,
    required this.color,
    this.isRainbow = false,
    this.faceShape = 0,
    this.swayValue = 0.0,
    this.windStrength = 0.0,
    this.bounceValue = 0.0,
    super.repaint,
  });

  // Cached paints
  static final Paint _contactShadow = Paint()
    ..color = const Color(0xFF0A0A1A).withValues(alpha: 0.12)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

  Paint _massPaint(Rect bounds) {
    if (isRainbow) {
      return Paint()
        ..shader = const SweepGradient(
          center: Alignment.center,
          colors: _rainbowColors,
        ).createShader(bounds);
    }
    final hi = _warmHighlight(color);
    final mid = _midTone(color);
    final sh = _coolShadow(color);
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [hi, mid, color, sh],
        stops: const [0.0, 0.20, 0.50, 1.0],
      ).createShader(bounds);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final e = _frontEdge(faceShape);
    final bounds = Rect.fromLTWH(0, 0, w, h);
    final paint = _massPaint(bounds)..style = PaintingStyle.fill;
    final hlPaint =
        _anisotropicHighlightPaint(color, isRainbow, bounds, swayValue);

    switch (style) {
      case 0: // Short
        _drawShortFront(canvas, w, h, e, paint, hlPaint);
        break;
      case 1: // Long
      case 3: // Wavy (→ long variant)
        _drawLongFront(canvas, w, h, e, paint, hlPaint);
        break;
      case 2: // Curly
        _drawCurlyFront(canvas, w, h, e, paint, hlPaint);
        break;
      case 4: // Ponytail
      case 11: // Braids (→ ponytail variant)
        _drawPonytailFront(canvas, w, h, e, paint, hlPaint);
        break;
      case 5: // Buzz
        _drawBuzzFront(canvas, w, h, e, paint, hlPaint);
        break;
      case 6: // Afro
        _drawAfroFront(canvas, w, h, e, paint, hlPaint);
        break;
      case 8: // Pigtails
        _drawPigtailsFront(canvas, w, h, e, paint, hlPaint);
        break;
      case 9: // Bob
        _drawBobFront(canvas, w, h, e, paint, hlPaint);
        break;
      default: // 7, 10, 12-15 — natural medium
        _drawNaturalFront(canvas, w, h, e, paint, hlPaint);
        break;
    }

    // ── Hair shimmer shader overlay ──
    if (!isRainbow) {
      final hairShader = ShaderLoader.hairShimmer;
      if (hairShader != null) {
        hairShader.setFloat(0, w); // uSize.x
        hairShader.setFloat(1, h); // uSize.y
        hairShader.setFloat(2, swayValue * 0.8); // uTime
        hairShader.setFloat(3, swayValue); // uSway
        // Clip to hair cap region
        final clipPath = Path()
          ..moveTo(w * e.oL, h * e.oB)
          ..cubicTo(
              w * e.oL, h * 0.12, w * 0.30, h * 0.06, w * 0.50, h * 0.055)
          ..cubicTo(
              w * 0.70, h * 0.06, w * e.oR, h * 0.12, w * e.oR, h * e.oB)
          ..lineTo(w * e.iR, h * 0.28)
          ..quadraticBezierTo(
              w * e.iR, h * e.iT, w * 0.50, h * (e.iT + 0.02))
          ..quadraticBezierTo(w * e.iL, h * e.iT, w * e.iL, h * 0.28)
          ..close();
        canvas.save();
        canvas.clipPath(clipPath);
        canvas.drawRect(
          bounds,
          Paint()..shader = hairShader,
        );
        canvas.restore();
      }
    }
  }

  /// The single perfected natural medium-length style with side-swept bangs.
  void _drawNaturalFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final sway1 = _computeSway(swayValue, 1, windStrength);

    // ── Hair cap (covers top of head) ──
    _drawHairCap(canvas, paint, w, h, e, hlPaint);

    // ── Bang depth shadow ──
    // Soft shadow below the bangs, simulating them floating above the forehead.
    {
      final bangShadowColor = _coolShadow(
          isRainbow ? const Color(0xFF3A3A5E) : color, 0.30);
      final bangDepthShadow = Paint()
        ..color = bangShadowColor.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..style = PaintingStyle.fill;
      final bangShadowPath = Path()
        ..moveTo(w * 0.64, h * (0.08 + 0.03))
        ..cubicTo(
            w * 0.58, h * (0.07 + 0.03),
            w * 0.42, h * (0.07 + 0.03),
            w * 0.34, h * (0.09 + 0.03))
        ..cubicTo(
            w * (0.28 + sway0 * 0.15), h * (0.16 + 0.03),
            w * (0.22 + sway1 * 0.22), h * (0.28 + 0.03),
            w * (0.20 + sway1 * 0.28), h * (e.oB + 0.04))
        ..lineTo(w * e.iL, h * (e.iT + 0.09))
        ..quadraticBezierTo(
            w * 0.50, h * (e.iT + 0.02),
            w * e.iR, h * (e.iT + 0.05))
        ..lineTo(w * 0.64, h * (0.08 + 0.03))
        ..close();
      canvas.drawPath(bangShadowPath, bangDepthShadow);
    }

    // ── Solid bang base fill (darker than strands for contrast) ──
    {
      final bangBasePaint = isRainbow
          ? paint
          : (Paint()
            ..color = _coolShadow(color, 0.20)
            ..style = PaintingStyle.fill);
      final bangBase = Path()
        ..moveTo(w * 0.64, h * 0.08)
        ..cubicTo(
            w * 0.58, h * 0.07,
            w * 0.42, h * 0.07,
            w * 0.34, h * 0.09)
        ..cubicTo(
            w * (0.28 + sway0 * 0.15), h * 0.16,
            w * (0.22 + sway1 * 0.22), h * 0.28,
            w * (0.20 + sway1 * 0.28), h * (e.oB + 0.01))
        ..lineTo(w * e.iL, h * (e.iT + 0.06))
        ..quadraticBezierTo(
            w * 0.50, h * (e.iT - 0.01),
            w * e.iR, h * (e.iT + 0.02))
        ..lineTo(w * 0.64, h * 0.08)
        ..close();
      canvas.drawPath(bangBase, bangBasePaint);
    }

    // ── Side-swept bangs ──
    // 7 strand groups sweeping from right to left across forehead.
    // Thicker strands with more overlap for dense, natural look.

    // Strand group 1: rightmost, short wispy strand
    {
      final strand = [
        Offset(w * 0.63, h * 0.09),
        Offset(w * (0.59 + sway0 * 0.15), h * 0.14),
        Offset(w * (0.53 + sway0 * 0.20), h * (e.iT + 0.02)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.024, paint, hlPaint,
          strandCount: 4, spreadFactor: 0.3,
          baseColor: isRainbow ? null : color);
    }

    // Strand group 1b: fill between 1 and 2
    {
      final strand = [
        Offset(w * 0.60, h * 0.085),
        Offset(w * (0.54 + sway0 * 0.16), h * 0.13),
        Offset(w * (0.47 + sway0 * 0.21), h * 0.18),
        Offset(w * (0.42 + sway1 * 0.23), h * (e.iT + 0.03)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.022, paint, null,
          strandCount: 3, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Strand group 2: mid-right, medium length
    {
      final strand = [
        Offset(w * 0.56, h * 0.08),
        Offset(w * (0.48 + sway0 * 0.18), h * 0.13),
        Offset(w * (0.40 + sway0 * 0.22), h * 0.18),
        Offset(w * (0.36 + sway1 * 0.25), h * (e.iT + 0.04)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.028, paint, hlPaint,
          strandCount: 4, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Strand group 3: center, longest — the main bang sweep
    {
      final strand = [
        Offset(w * 0.50, h * 0.07),
        Offset(w * (0.42 + sway0 * 0.15), h * 0.12),
        Offset(w * (0.34 + sway0 * 0.22), h * 0.18),
        Offset(w * (0.28 + sway1 * 0.28), h * 0.24),
        Offset(w * (0.24 + sway1 * 0.30), h * (e.oB - 0.02)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.032, paint, null,
          strandCount: 5, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Strand group 3b: fill between 3 and 4
    {
      final strand = [
        Offset(w * 0.47, h * 0.075),
        Offset(w * (0.40 + sway0 * 0.13), h * 0.13),
        Offset(w * (0.33 + sway0 * 0.20), h * 0.20),
        Offset(w * (0.28 + sway1 * 0.24), h * (e.iT + 0.05)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.024, paint, null,
          strandCount: 3, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Strand group 4: mid-left, medium
    {
      final strand = [
        Offset(w * 0.44, h * 0.08),
        Offset(w * (0.38 + sway0 * 0.12), h * 0.14),
        Offset(w * (0.32 + sway0 * 0.18), h * 0.20),
        Offset(w * (0.28 + sway1 * 0.22), h * (e.iT + 0.06)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.026, paint, hlPaint,
          strandCount: 4, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Strand group 5: leftmost, short wispy
    {
      final strand = [
        Offset(w * 0.38, h * 0.09),
        Offset(w * (0.34 + sway0 * 0.10), h * 0.15),
        Offset(w * (0.30 + sway0 * 0.15), h * (e.iT + 0.03)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.022, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.3,
          baseColor: isRainbow ? null : color);
    }

    // ── Inter-strand ambient occlusion shadows ──
    // Thin dark lines in gaps between major strand groups.
    {
      final aoColor = _coolShadow(
          isRainbow ? const Color(0xFF3A3A5E) : color, 0.35);
      final aoPaint = Paint()
        ..color = aoColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.003
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1)
        ..strokeCap = StrokeCap.round;

      // Shadow lines between major groups (approx midpoints)
      final aoLines = <List<Offset>>[
        // Between group 1 and 2
        [Offset(w * 0.595, h * 0.087),
         Offset(w * (0.515 + sway0 * 0.17), h * 0.135),
         Offset(w * (0.445 + sway0 * 0.21), h * (e.iT + 0.025))],
        // Between group 2 and 3
        [Offset(w * 0.53, h * 0.075),
         Offset(w * (0.45 + sway0 * 0.165), h * 0.125),
         Offset(w * (0.37 + sway0 * 0.20), h * 0.19),
         Offset(w * (0.32 + sway1 * 0.265), h * (e.iT + 0.045))],
        // Between group 3 and 4
        [Offset(w * 0.455, h * 0.078),
         Offset(w * (0.39 + sway0 * 0.125), h * 0.135),
         Offset(w * (0.325 + sway0 * 0.19), h * 0.20),
         Offset(w * (0.28 + sway1 * 0.23), h * (e.iT + 0.055))],
        // Between group 4 and 5
        [Offset(w * 0.41, h * 0.085),
         Offset(w * (0.36 + sway0 * 0.11), h * 0.145),
         Offset(w * (0.31 + sway0 * 0.165), h * (e.iT + 0.045))],
      ];

      for (final pts in aoLines) {
        final aoPath = Path()..moveTo(pts[0].dx, pts[0].dy);
        if (pts.length == 3) {
          aoPath.quadraticBezierTo(
              pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy);
        } else {
          aoPath.cubicTo(pts[1].dx, pts[1].dy, pts[2].dx, pts[2].dy,
              pts[3].dx, pts[3].dy);
        }
        canvas.drawPath(aoPath, aoPaint);
      }
    }

    // ── Strand surface micro-lines ──
    // Fine hair-within-strand detail on top of the major groups.
    {
      final microWarm = Paint()
        ..color = _warmHighlight(
                isRainbow ? const Color(0xFFFFD700) : color, 0.20)
            .withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.002
        ..strokeCap = StrokeCap.round;
      final microCool = Paint()
        ..color = _coolShadow(
                isRainbow ? const Color(0xFF3A3A5E) : color, 0.12)
            .withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.0015
        ..strokeCap = StrokeCap.round;

      // Micro-lines on the 3 main strand groups (2, 3, 4)
      // Group 2 micro-lines
      for (int m = 0; m < 2; m++) {
        final off = (m - 0.5) * w * 0.006;
        final micro = Path()
          ..moveTo(w * 0.56 + off, h * 0.08)
          ..cubicTo(
              w * (0.48 + sway0 * 0.18) + off, h * 0.13,
              w * (0.40 + sway0 * 0.22) + off, h * 0.18,
              w * (0.36 + sway1 * 0.25) + off, h * (e.iT + 0.04));
        canvas.drawPath(micro, m.isEven ? microWarm : microCool);
      }
      // Group 3 micro-lines
      for (int m = 0; m < 3; m++) {
        final off = (m - 1.0) * w * 0.005;
        final micro = Path()
          ..moveTo(w * 0.50 + off, h * 0.07)
          ..cubicTo(
              w * (0.42 + sway0 * 0.15) + off, h * 0.12,
              w * (0.34 + sway0 * 0.22) + off, h * 0.18,
              w * (0.28 + sway1 * 0.28) + off, h * 0.24);
        canvas.drawPath(micro, m.isEven ? microWarm : microCool);
      }
      // Group 4 micro-lines
      for (int m = 0; m < 2; m++) {
        final off = (m - 0.5) * w * 0.006;
        final micro = Path()
          ..moveTo(w * 0.44 + off, h * 0.08)
          ..cubicTo(
              w * (0.38 + sway0 * 0.12) + off, h * 0.14,
              w * (0.32 + sway0 * 0.18) + off, h * 0.20,
              w * (0.28 + sway1 * 0.22) + off, h * (e.iT + 0.06));
        canvas.drawPath(micro, m.isEven ? microWarm : microCool);
      }
    }

    // ── Root darkening on bang strands ──
    // Short gradient shadow at the top root of each major strand group.
    {
      final rootShadow = Paint()
        ..color = _coolShadow(
                isRainbow ? const Color(0xFF3A3A5E) : color, 0.25)
            .withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        ..style = PaintingStyle.fill;
      // Root zones at the top of strands 1-5
      final rootZones = <Rect>[
        Rect.fromLTWH(w * 0.60, h * 0.075, w * 0.06, h * 0.03),
        Rect.fromLTWH(w * 0.52, h * 0.065, w * 0.08, h * 0.035),
        Rect.fromLTWH(w * 0.46, h * 0.055, w * 0.08, h * 0.04),
        Rect.fromLTWH(w * 0.40, h * 0.065, w * 0.08, h * 0.035),
        Rect.fromLTWH(w * 0.34, h * 0.075, w * 0.06, h * 0.03),
      ];
      for (final zone in rootZones) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(zone, Radius.circular(w * 0.01)),
            rootShadow);
      }
    }

    // ── Tip fade on bang strands ──
    // Semi-transparent overlay at the tips of the longest strands.
    {
      final tipFade = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00000000),
            const Color(0x00000000),
            (isRainbow ? const Color(0xFF0A0A1A) : _coolShadow(color, 0.20))
                .withValues(alpha: 0.30),
          ],
          stops: const [0.0, 0.70, 1.0],
        ).createShader(Rect.fromLTWH(0, h * (e.iT - 0.02), w, h * 0.12));
      // Draw over the bang tip region
      final tipRect = Rect.fromLTWH(
          w * (0.18 + sway1 * 0.28), h * (e.iT - 0.02),
          w * 0.50, h * 0.12);
      canvas.drawRect(tipRect, tipFade);
    }

    // ── Shine streaks (diffuse + sharp specular pair) ──
    final shineBase = _warmHighlight(
        isRainbow ? const Color(0xFFFFD700) : color, 0.40);

    // Primary diffuse shine
    final shinePaint = Paint()
      ..color = shineBase.withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;

    final shineStreak = Path()
      ..moveTo(w * 0.54, h * 0.085)
      ..cubicTo(
          w * (0.46 + sway0 * 0.10), h * 0.12,
          w * (0.38 + sway0 * 0.18), h * 0.17,
          w * (0.30 + sway1 * 0.24), h * 0.23);
    canvas.drawPath(shineStreak, shinePaint);

    // Secondary sharp specular (thinner, brighter, offset slightly)
    final shineSharp = Paint()
      ..color = shineBase.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..strokeCap = StrokeCap.round;

    final shineStreak2 = Path()
      ..moveTo(w * 0.55, h * 0.082)
      ..cubicTo(
          w * (0.47 + sway0 * 0.10), h * 0.115,
          w * (0.39 + sway0 * 0.18), h * 0.165,
          w * (0.31 + sway1 * 0.24), h * 0.225);
    canvas.drawPath(shineStreak2, shineSharp);

    // ── Bang tip wisps — thin strands extending beyond main bang tips ──
    {
      final wispPaint = Paint()
        ..color = _warmHighlight(
                isRainbow ? const Color(0xFFFFD700) : color, 0.25)
            .withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.003
        ..strokeCap = StrokeCap.round;

      // 3 wisps at the left (swept) end of bangs
      final wispSway = _computeSway(swayValue, 2, windStrength) * 1.3;
      for (int i = 0; i < 3; i++) {
        final yOff = i * 0.015;
        final wisp = Path()
          ..moveTo(w * (0.24 + sway1 * 0.30), h * (e.oB - 0.02 + yOff))
          ..cubicTo(
              w * (0.22 + wispSway * 0.35), h * (e.oB + 0.02 + yOff),
              w * (0.20 + wispSway * 0.45), h * (e.oB + 0.05 + yOff),
              w * (0.18 + wispSway * 0.55), h * (e.oB + 0.07 + yOff));
        canvas.drawPath(wisp, wispPaint);
      }

      // 2 wisps at the right start of bangs
      for (int i = 0; i < 2; i++) {
        final yOff = i * 0.012;
        final wisp = Path()
          ..moveTo(w * 0.63, h * (0.09 + yOff))
          ..cubicTo(
              w * (0.65 + sway0 * 0.10), h * (0.12 + yOff),
              w * (0.66 + sway0 * 0.15), h * (0.15 + yOff),
              w * (0.67 + sway0 * 0.18), h * (0.17 + yOff));
        canvas.drawPath(wisp, wispPaint);
      }
    }

    // ── Temple wisps — thin S-curve strands in front of ears ──
    {
      final templePaint = Paint()
        ..color = (isRainbow ? const Color(0xFFFFD700) : color)
            .withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.003
        ..strokeCap = StrokeCap.round;

      // Left temple — 3 wisps
      for (int i = 0; i < 3; i++) {
        final tSway = _computeSway(swayValue, i, windStrength) * 0.8;
        final xBase = 0.14 + i * 0.008;
        final wisp = Path()
          ..moveTo(w * xBase, h * 0.26)
          ..cubicTo(
              w * (xBase - 0.02 + tSway * 0.2), h * 0.32,
              w * (xBase + 0.01 + tSway * 0.3), h * 0.38,
              w * (xBase - 0.01 + tSway * 0.4), h * 0.44);
        canvas.drawPath(wisp, templePaint);
      }

      // Right temple — 3 wisps
      for (int i = 0; i < 3; i++) {
        final tSway = _computeSway(swayValue, i + 2, windStrength) * 0.8;
        final xBase = 0.86 - i * 0.008;
        final wisp = Path()
          ..moveTo(w * xBase, h * 0.26)
          ..cubicTo(
              w * (xBase + 0.02 + tSway * 0.2), h * 0.32,
              w * (xBase - 0.01 + tSway * 0.3), h * 0.38,
              w * (xBase + 0.01 + tSway * 0.4), h * 0.44);
        canvas.drawPath(wisp, templePaint);
      }
    }

    // ── Forehead contact shadow beneath bangs ──
    final bangShadow = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.01))
      ..cubicTo(
          w * (e.iL + 0.05), h * (e.iT + 0.04),
          w * 0.45, h * (e.iT + 0.05),
          w * 0.55, h * (e.iT + 0.03))
      ..cubicTo(
          w * 0.65, h * (e.iT + 0.01),
          w * (e.iR - 0.05), h * e.iT,
          w * e.iR, h * (e.iT + 0.01))
      ..close();
    canvas.drawPath(bangShadow, _contactShadow);
  }

  /// Hair cap — the solid top portion covering the crown.
  void _drawHairCap(Canvas canvas, Paint paint, double w, double h,
      _FrontEdge e, Paint hlPaint) {
    final sway = _computeSway(swayValue, 0, windStrength);

    final path = Path()
      ..moveTo(w * e.oL, h * e.oB)
      // Left side rising to crown — organic dome curve
      ..cubicTo(
          w * e.oL, h * 0.12,
          w * 0.30, h * (0.06 + sway * 0.15),
          w * 0.50, h * 0.055)
      // Crown to right side
      ..cubicTo(
          w * 0.70, h * (0.06 + sway * 0.15),
          w * e.oR, h * 0.12,
          w * e.oR, h * e.oB)
      // Hairline inner edge (right to left)
      ..lineTo(w * e.iR, h * 0.28)
      ..quadraticBezierTo(
          w * e.iR, h * e.iT, w * 0.50, h * (e.iT + 0.02))
      ..quadraticBezierTo(w * e.iL, h * e.iT, w * e.iL, h * 0.28)
      ..close();

    // Contact shadow on forehead
    final shadowPath = Path()
      ..moveTo(w * e.iL, h * 0.28)
      ..quadraticBezierTo(
          w * e.iL, h * (e.iT + 0.03), w * 0.50, h * (e.iT + 0.05))
      ..quadraticBezierTo(
          w * e.iR, h * (e.iT + 0.03), w * e.iR, h * 0.28)
      ..close();
    canvas.drawPath(shadowPath, _contactShadow);

    canvas.drawPath(path, paint);

    // Anisotropic cap highlight — warm band across the crown
    final capHl = Path()
      ..moveTo(w * (e.oL + 0.04), h * 0.18)
      ..quadraticBezierTo(w * 0.50, h * 0.10, w * (e.oR - 0.04), h * 0.18)
      ..quadraticBezierTo(w * 0.50, h * 0.14, w * (e.oL + 0.04), h * 0.18)
      ..close();
    canvas.drawPath(capHl, hlPaint);

    // Radial crown intensity boost — bright spot at the crown center
    if (!isRainbow) {
      final crownColor = _warmHighlight(color, 0.45);
      final crownBoost = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.55),
          radius: 0.35,
          colors: [
            crownColor.withValues(alpha: 0.22),
            crownColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(capHl, crownBoost);
    }

    // Subtle SSS rim on the top arc of the cap (light wrapping over crown)
    {
      final capRimColor = _warmHighlight(
          isRainbow ? const Color(0xFFFFD700) : color, 0.35);
      final capRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3)
        ..color = capRimColor.withValues(alpha: 0.15);
      final capRimPath = Path()
        ..moveTo(w * (e.oL + 0.06), h * 0.14)
        ..cubicTo(
            w * 0.30, h * (0.07 + sway * 0.10),
            w * 0.70, h * (0.07 + sway * 0.10),
            w * (e.oR - 0.06), h * 0.14);
      canvas.drawPath(capRimPath, capRimPaint);
    }
  }

  // ── Short front (style 0) — short cap, minimal fringe ──

  void _drawShortFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);

    // Compact hair cap
    _drawHairCap(canvas, paint, w, h, e, hlPaint);

    // Very short fringe — just 3 small strand groups across forehead
    for (int i = 0; i < 3; i++) {
      final xStart = 0.38 + i * 0.08;
      final strand = [
        Offset(w * xStart, h * 0.09),
        Offset(w * (xStart - 0.02 + sway0 * 0.08), h * 0.14),
        Offset(w * (xStart - 0.03 + sway0 * 0.10), h * (e.iT + 0.01)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.020, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Contact shadow
    final bangShadow = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.01))
      ..cubicTo(
          w * (e.iL + 0.05), h * (e.iT + 0.03),
          w * 0.45, h * (e.iT + 0.03),
          w * 0.55, h * (e.iT + 0.02))
      ..cubicTo(
          w * 0.65, h * (e.iT + 0.01),
          w * (e.iR - 0.05), h * e.iT,
          w * e.iR, h * (e.iT + 0.01))
      ..close();
    canvas.drawPath(bangShadow, _contactShadow);

    // Subtle texture for close-cropped look
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final dotPaint = Paint()
      ..color = _warmHighlight(baseC, 0.15).withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final rng = Random(17);
    for (int i = 0; i < 15; i++) {
      final dx = w * (0.25 + rng.nextDouble() * 0.50);
      final dy = h * (0.08 + rng.nextDouble() * 0.10);
      canvas.drawCircle(Offset(dx, dy), w * 0.003, dotPaint);
    }
  }

  // ── Long front (style 1) — natural bangs extending longer ──

  void _drawLongFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    // Reuse the natural front — long style mainly differs in the back
    _drawNaturalFront(canvas, w, h, e, paint, hlPaint);
  }

  // ── Curly front (style 2) — voluminous curly bangs ──

  void _drawCurlyFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final sway1 = _computeSway(swayValue, 1, windStrength);

    // Hair cap
    _drawHairCap(canvas, paint, w, h, e, hlPaint);

    // Curly bang base
    final bangBasePaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.20)
          ..style = PaintingStyle.fill);
    final bangBase = Path()
      ..moveTo(w * 0.68, h * 0.08)
      ..cubicTo(w * 0.58, h * 0.06, w * 0.38, h * 0.06, w * 0.30, h * 0.09)
      ..cubicTo(
          w * (0.24 + sway0 * 0.15), h * 0.18,
          w * (0.18 + sway1 * 0.22), h * 0.30,
          w * (0.16 + sway1 * 0.28), h * (e.oB + 0.03))
      ..lineTo(w * e.iL, h * (e.iT + 0.06))
      ..quadraticBezierTo(w * 0.50, h * (e.iT - 0.01), w * e.iR, h * (e.iT + 0.02))
      ..lineTo(w * 0.68, h * 0.08)
      ..close();
    canvas.drawPath(bangBase, bangBasePaint);

    // Curly bump bangs — semicircle bumps across the forehead
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final curlPaint = Paint()
      ..color = (isRainbow ? baseC : _midTone(color)).withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;
    final curlHl = Paint()
      ..color = _warmHighlight(baseC, 0.30).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // 5 curly bumps across forehead
    for (int i = 0; i < 5; i++) {
      final phase = i % 5;
      final cSway = _computeSway(swayValue, phase, windStrength);
      final cx = w * (0.30 + i * 0.09 + cSway * 0.1);
      final cy = h * (e.iT + 0.02 + (i % 2) * 0.015);
      final r = w * (0.035 + (i % 2) * 0.008);
      canvas.drawCircle(Offset(cx, cy), r, curlPaint);
      canvas.drawCircle(Offset(cx, cy - r * 0.3), r * 0.4, curlHl);
    }

    // Side curls spilling forward near temples
    for (int side = 0; side < 2; side++) {
      final xBase = side == 0 ? 0.14 : 0.86;
      final xSign = side == 0 ? -1.0 : 1.0;
      for (int j = 0; j < 2; j++) {
        final phase = (side * 2 + j) % 5;
        final cSway = _computeSway(swayValue, phase, windStrength);
        final cx = w * (xBase + xSign * j * 0.02 + cSway * 0.15);
        final cy = h * (0.28 + j * 0.08);
        final r = w * 0.030;
        canvas.drawCircle(Offset(cx, cy), r, curlPaint);
        canvas.drawCircle(Offset(cx, cy - r * 0.3), r * 0.35, curlHl);
      }
    }

    // Contact shadow
    final bangShadow = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.01))
      ..cubicTo(
          w * (e.iL + 0.05), h * (e.iT + 0.04),
          w * 0.45, h * (e.iT + 0.05),
          w * 0.55, h * (e.iT + 0.03))
      ..cubicTo(
          w * 0.65, h * (e.iT + 0.01),
          w * (e.iR - 0.05), h * e.iT,
          w * e.iR, h * (e.iT + 0.01))
      ..close();
    canvas.drawPath(bangShadow, _contactShadow);
  }

  // ── Ponytail front (style 4) — sleek pulled-back top, minimal bangs ──

  void _drawPonytailFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);

    // Hair cap — sleek and tight
    _drawHairCap(canvas, paint, w, h, e, hlPaint);

    // Pulled-back texture lines (showing hair direction toward back)
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final texPaint = Paint()
      ..color = _warmHighlight(baseC).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 5; i++) {
      final xStart = 0.30 + i * 0.10;
      final line = Path()
        ..moveTo(w * xStart, h * 0.12)
        ..cubicTo(
            w * (xStart + 0.02), h * 0.10,
            w * (xStart + 0.04), h * 0.09,
            w * 0.50, h * 0.07);
      canvas.drawPath(line, texPaint);
    }

    // Very thin wispy baby-hair strands at forehead
    final wispPaint = Paint()
      ..color = (isRainbow ? baseC : color).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.003
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final xBase = 0.35 + i * 0.10;
      final wisp = Path()
        ..moveTo(w * xBase, h * (e.iT + 0.005))
        ..cubicTo(
            w * (xBase - 0.01 + sway0 * 0.05), h * (e.iT + 0.02),
            w * (xBase - 0.02 + sway0 * 0.08), h * (e.iT + 0.04),
            w * (xBase - 0.02 + sway0 * 0.10), h * (e.iT + 0.05));
      canvas.drawPath(wisp, wispPaint);
    }

    // Contact shadow
    final bangShadow = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.005))
      ..cubicTo(
          w * (e.iL + 0.05), h * (e.iT + 0.02),
          w * 0.45, h * (e.iT + 0.02),
          w * 0.55, h * (e.iT + 0.015))
      ..cubicTo(
          w * 0.65, h * (e.iT + 0.005),
          w * (e.iR - 0.05), h * e.iT,
          w * e.iR, h * (e.iT + 0.005))
      ..close();
    canvas.drawPath(bangShadow, _contactShadow);
  }

  // ── Buzz front (style 5) — minimal cap, no bangs ──

  void _drawBuzzFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    // Very thin hair cap
    final path = Path()
      ..moveTo(w * e.oL, h * (e.oB - 0.04))
      ..cubicTo(
          w * e.oL, h * 0.14,
          w * 0.30, h * 0.08,
          w * 0.50, h * 0.07)
      ..cubicTo(
          w * 0.70, h * 0.08,
          w * e.oR, h * 0.14,
          w * e.oR, h * (e.oB - 0.04))
      ..lineTo(w * e.iR, h * 0.26)
      ..quadraticBezierTo(
          w * e.iR, h * e.iT, w * 0.50, h * (e.iT + 0.02))
      ..quadraticBezierTo(w * e.iL, h * e.iT, w * e.iL, h * 0.26)
      ..close();

    canvas.drawPath(path, paint);

    // Subtle fuzz dots on cap
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final dotPaint = Paint()
      ..color = _warmHighlight(baseC, 0.15).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final rng = Random(53);
    for (int i = 0; i < 40; i++) {
      final dx = w * (0.20 + rng.nextDouble() * 0.60);
      final dy = h * (0.09 + rng.nextDouble() * 0.12);
      canvas.drawCircle(Offset(dx, dy), w * 0.002, dotPaint);
    }

    // Very thin hairline edge
    final edgePaint = Paint()
      ..color = _coolShadow(baseC, 0.20).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.004;
    final edgePath = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.01))
      ..quadraticBezierTo(w * 0.50, h * (e.iT - 0.005), w * e.iR, h * (e.iT + 0.01));
    canvas.drawPath(edgePath, edgePaint);
  }

  // ── Afro front (style 6) — big round top, side volume ──

  void _drawAfroFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    // Wider hair cap for afro volume
    final path = Path()
      ..moveTo(w * (e.oL - 0.06), h * e.oB)
      ..cubicTo(
          w * (e.oL - 0.08), h * 0.08,
          w * 0.25, h * 0.00,
          w * 0.50, h * -0.02)
      ..cubicTo(
          w * 0.75, h * 0.00,
          w * (e.oR + 0.08), h * 0.08,
          w * (e.oR + 0.06), h * e.oB)
      ..lineTo(w * e.iR, h * 0.28)
      ..quadraticBezierTo(
          w * e.iR, h * e.iT, w * 0.50, h * (e.iT + 0.02))
      ..quadraticBezierTo(w * e.iL, h * e.iT, w * e.iL, h * 0.28)
      ..close();

    // Contact shadow
    final shadowPath = Path()
      ..moveTo(w * e.iL, h * 0.28)
      ..quadraticBezierTo(
          w * e.iL, h * (e.iT + 0.03), w * 0.50, h * (e.iT + 0.05))
      ..quadraticBezierTo(
          w * e.iR, h * (e.iT + 0.03), w * e.iR, h * 0.28)
      ..close();
    canvas.drawPath(shadowPath, _contactShadow);
    canvas.drawPath(path, paint);

    // Anisotropic highlight
    final capHl = Path()
      ..moveTo(w * (e.oL - 0.02), h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.06, w * (e.oR + 0.02), h * 0.16)
      ..quadraticBezierTo(w * 0.50, h * 0.10, w * (e.oL - 0.02), h * 0.16)
      ..close();
    canvas.drawPath(capHl, hlPaint);

    // Crown highlight
    if (!isRainbow) {
      final crownColor = _warmHighlight(color, 0.40);
      final crownBoost = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.7),
          radius: 0.4,
          colors: [
            crownColor.withValues(alpha: 0.20),
            crownColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(capHl, crownBoost);
    }

    // Poofy texture bumps on front
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final bumpPaint = Paint()
      ..color = _midTone(baseC).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    final rng = Random(67);
    for (int i = 0; i < 12; i++) {
      final dx = w * (0.15 + rng.nextDouble() * 0.70);
      final dy = h * (0.04 + rng.nextDouble() * 0.14);
      final r = w * (0.015 + rng.nextDouble() * 0.012);
      canvas.drawCircle(Offset(dx, dy), r, bumpPaint);
    }

    // Side volume bumps near temples
    for (int side = 0; side < 2; side++) {
      final xBase = side == 0 ? e.oL - 0.04 : e.oR + 0.04;
      for (int j = 0; j < 3; j++) {
        final cy = h * (0.22 + j * 0.05);
        final cx = w * xBase;
        canvas.drawCircle(Offset(cx, cy), w * 0.018, bumpPaint);
      }
    }
  }

  // ── Pigtails front (style 8) — center part with side volume ──

  void _drawPigtailsFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);

    // Hair cap
    _drawHairCap(canvas, paint, w, h, e, hlPaint);

    // Center part line
    final baseC = isRainbow ? const Color(0xFFFFD700) : color;
    final partPaint = Paint()
      ..color = _coolShadow(baseC, 0.30).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.006
      ..strokeCap = StrokeCap.round;
    final partLine = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..lineTo(w * 0.50, h * (e.iT + 0.02));
    canvas.drawPath(partLine, partPaint);

    // Parted bangs — left side sweeping left, right side sweeping right
    // Left bangs
    for (int i = 0; i < 3; i++) {
      final xStart = 0.48 - i * 0.06;
      final strand = [
        Offset(w * xStart, h * 0.08),
        Offset(w * (xStart - 0.04 + sway0 * 0.08), h * 0.14),
        Offset(w * (xStart - 0.06 + sway0 * 0.12), h * (e.iT + 0.02)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.022, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }
    // Right bangs
    for (int i = 0; i < 3; i++) {
      final xStart = 0.52 + i * 0.06;
      final strand = [
        Offset(w * xStart, h * 0.08),
        Offset(w * (xStart + 0.04 + sway0 * 0.08), h * 0.14),
        Offset(w * (xStart + 0.06 + sway0 * 0.12), h * (e.iT + 0.02)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.022, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.25,
          baseColor: isRainbow ? null : color);
    }

    // Contact shadow
    final bangShadow = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.01))
      ..cubicTo(
          w * (e.iL + 0.05), h * (e.iT + 0.04),
          w * 0.45, h * (e.iT + 0.04),
          w * 0.55, h * (e.iT + 0.03))
      ..cubicTo(
          w * 0.65, h * (e.iT + 0.01),
          w * (e.iR - 0.05), h * e.iT,
          w * e.iR, h * (e.iT + 0.01))
      ..close();
    canvas.drawPath(bangShadow, _contactShadow);
  }

  // ── Bob front (style 9) — framing bangs with straight bottom ──

  void _drawBobFront(Canvas canvas, double w, double h, _FrontEdge e,
      Paint paint, Paint hlPaint) {
    final sway0 = _computeSway(swayValue, 0, windStrength);
    final sway1 = _computeSway(swayValue, 1, windStrength);

    // Hair cap
    _drawHairCap(canvas, paint, w, h, e, hlPaint);

    // Straight-across fringe / blunt bangs
    final bangBasePaint = isRainbow
        ? paint
        : (Paint()
          ..color = _coolShadow(color, 0.18)
          ..style = PaintingStyle.fill);
    final bangBase = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.06))
      ..quadraticBezierTo(
          w * 0.50, h * (e.iT + 0.08),
          w * e.iR, h * (e.iT + 0.06))
      ..quadraticBezierTo(
          w * 0.50, h * (e.iT - 0.01),
          w * e.iL, h * (e.iT + 0.06))
      ..close();
    canvas.drawPath(bangBase, bangBasePaint);

    // Blunt bang strands — evenly spaced across forehead
    for (int i = 0; i < 6; i++) {
      final xStart = 0.24 + i * 0.10;
      final strand = [
        Offset(w * xStart, h * 0.085),
        Offset(w * (xStart + sway0 * 0.05), h * 0.14),
        Offset(w * (xStart + sway0 * 0.08), h * (e.iT + 0.04)),
      ];
      _drawStrandGroup(canvas, strand, w * 0.024, paint,
          i == 2 || i == 3 ? hlPaint : null,
          strandCount: 3, spreadFactor: 0.20,
          baseColor: isRainbow ? null : color);
    }

    // Side framing pieces — longer strands beside face
    for (int side = 0; side < 2; side++) {
      final xBase = side == 0 ? e.oL + 0.02 : e.oR - 0.02;
      final dir = side == 0 ? -1.0 : 1.0;
      final sSway = side == 0 ? sway1 : _computeSway(swayValue, 3, windStrength);
      final framingStrand = [
        Offset(w * xBase, h * 0.22),
        Offset(w * (xBase + dir * 0.02 + sSway * 0.15), h * 0.34),
        Offset(w * (xBase + dir * 0.01 + sSway * 0.20), h * 0.46),
      ];
      _drawStrandGroup(canvas, framingStrand, w * 0.020, paint, hlPaint,
          strandCount: 3, spreadFactor: 0.2,
          baseColor: isRainbow ? null : color);
    }

    // Shine streak across blunt bangs
    final shineBase = _warmHighlight(
        isRainbow ? const Color(0xFFFFD700) : color, 0.40);
    final shinePaint = Paint()
      ..color = shineBase.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..strokeCap = StrokeCap.round;
    final shinePath = Path()
      ..moveTo(w * 0.28, h * (e.iT + 0.02))
      ..quadraticBezierTo(
          w * 0.50, h * (e.iT + 0.035),
          w * 0.72, h * (e.iT + 0.02));
    canvas.drawPath(shinePath, shinePaint);

    // Contact shadow
    final bangShadow = Path()
      ..moveTo(w * e.iL, h * (e.iT + 0.01))
      ..cubicTo(
          w * (e.iL + 0.05), h * (e.iT + 0.05),
          w * 0.45, h * (e.iT + 0.06),
          w * 0.55, h * (e.iT + 0.04))
      ..cubicTo(
          w * 0.65, h * (e.iT + 0.02),
          w * (e.iR - 0.05), h * (e.iT + 0.01),
          w * e.iR, h * (e.iT + 0.01))
      ..close();
    canvas.drawPath(bangShadow, _contactShadow);
  }

  @override
  bool shouldRepaint(HairFrontPainter old) =>
      old.style != style ||
      old.color != color ||
      old.isRainbow != isRainbow ||
      old.faceShape != faceShape ||
      (old.swayValue * 100).round() != (swayValue * 100).round() ||
      (old.windStrength * 100).round() != (windStrength * 100).round() ||
      (old.bounceValue * 100).round() != (bounceValue * 100).round();
}
