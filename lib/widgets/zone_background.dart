import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/app_theme.dart';

/// Zone-specific color palettes for backgrounds and particles.
class ZoneColors {
  /// Gradient colors for each zone background (top → bottom).
  static const List<List<Color>> gradients = [
    // 0 — Whispering Woods: deep forest greens
    [Color(0xFF0A140F), Color(0xFF0F1F15)],
    // 1 — Shimmer Shore: dark ocean blues
    [Color(0xFF0A1018), Color(0xFF0F1825)],
    // 2 — Crystal Peaks: icy purple-blue
    [Color(0xFF0F0C1E), Color(0xFF15102A)],
    // 3 — Skyward Kingdom: warm dark sunset
    [Color(0xFF1A100E), Color(0xFF1A1218)],
    // 4 — Celestial Crown: deep space purple-navy
    [Color(0xFF08051A), Color(0xFF0D0820)],
  ];

  /// Primary particle colors per zone.
  static const List<List<Color>> particles = [
    // 0 — leaves and fireflies
    [
      Color(0xFF2D8B4E), Color(0xFF3DA55D), Color(0xFF5DC47E), // leaves
      Color(0xFFFFE066), Color(0xFFB8FF66), // fireflies
    ],
    // 1 — bubbles and water
    [
      Color(0xFF48A9C5), Color(0xFF7DD3E8), Color(0xFF3B8FB5),
      Color(0xFFB0E0F0), Color(0xFF60C0DD),
    ],
    // 2 — snow and crystals
    [
      Color(0xFFE0E8FF), Color(0xFFC8D4FF), Color(0xFFB0B8E0),
      Color(0xFF9BA8D0), Color(0xFFDDE4FF),
    ],
    // 3 — clouds and golden light
    [
      Color(0xFFE8D0B0), Color(0xFFF0C8A0), Color(0xFFD4B896),
      Color(0xFFF5E0C4), Color(0xFFCDB898),
    ],
    // 4 — stars and nebula
    [
      Color(0xFFFFFFFF), Color(0xFFE0E8FF), Color(0xFFC8B4F0),
      Color(0xFF9BE0FF), Color(0xFFFFD4E8),
    ],
  ];
}

/// An animated background that renders zone-themed particles.
///
/// Uses a [Ticker]-driven [ChangeNotifier] simulation so only the
/// [CustomPaint] layer repaints each frame — no widget rebuilds.
class ZoneBackground extends StatefulWidget {
  /// Zone index (0–4).
  final int zone;

  const ZoneBackground({super.key, required this.zone});

  @override
  State<ZoneBackground> createState() => _ZoneBackgroundState();
}

class _ZoneBackgroundState extends State<ZoneBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  late _ZoneSimulation _sim;

  @override
  void initState() {
    super.initState();
    _sim = _ZoneSimulation(zone: widget.zone.clamp(0, 4));
    _ticker = createTicker(_sim.tick)..start();
  }

  @override
  void didUpdateWidget(covariant ZoneBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone != widget.zone) {
      _sim.setZone(widget.zone.clamp(0, 4));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(builder: (context, constraints) {
        _sim.size = constraints.biggest;
        return CustomPaint(
          size: constraints.biggest,
          painter: _ZonePainter(sim: _sim),
        );
      }),
    );
  }
}

// =====================================================================
//  Particle data classes
// =====================================================================

/// Generic floating particle used by all zones.
class _Particle {
  double x, y;
  double vx, vy;
  double size;
  double opacity;
  double rotation;
  double rotationSpeed;
  double wobblePhase;
  double wobbleSpeed;
  Color color;
  int type; // zone-specific sub-type (0 = primary, 1 = secondary, etc.)
  double life = 0; // 0→1 normalized lifetime progress (unused by some zones)

  _Particle({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.size = 8,
    this.opacity = 0.5,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.wobblePhase = 0,
    this.wobbleSpeed = 1.0,
    required this.color,
    this.type = 0,
  });
}

/// A shooting star for the Celestial Crown zone.
class _ShootingStar {
  double x, y;
  double vx, vy;
  double length;
  double opacity;
  double elapsed = 0;
  double duration;

  _ShootingStar({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.length = 60,
    this.opacity = 0.7,
    this.duration = 1.0,
  });
}

// =====================================================================
//  Simulation
// =====================================================================

class _ZoneSimulation extends ChangeNotifier {
  int zone;
  Size size = Size.zero;
  double time = 0;
  double _spawnTimer = 0;
  Duration _lastElapsed = Duration.zero;
  final _rng = Random();

  final List<_Particle> particles = [];
  final List<_ShootingStar> shootingStars = [];

  // Wave state for Shimmer Shore
  double _wavePhase = 0;

  // Tuning per zone
  static const _maxParticles = [18, 16, 22, 12, 40];
  static const _spawnIntervals = [0.5, 0.6, 0.35, 0.9, 0.15];

  _ZoneSimulation({required this.zone});

  void setZone(int newZone) {
    if (newZone == zone) return;
    zone = newZone;
    particles.clear();
    shootingStars.clear();
    _spawnTimer = 0;
  }

  void tick(Duration elapsed) {
    final dtRaw = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final dt = dtRaw.clamp(0.0, 0.05);
    if (size == Size.zero) return;

    time += dt;
    _spawnTimer += dt;
    _wavePhase += dt * 0.5;

    // Spawn particles
    final interval = _spawnIntervals[zone];
    final maxP = _maxParticles[zone];
    if (_spawnTimer >= interval && particles.length < maxP) {
      _spawnTimer = 0;
      _spawnParticle();
    }

    // Spawn shooting stars (zone 4 only)
    if (zone == 4 && _rng.nextDouble() < 0.003) {
      _spawnShootingStar();
    }

    // Update particles
    _updateParticles(dt);

    // Update shooting stars
    _updateShootingStars(dt);

    notifyListeners();
  }

  // ── Spawn logic per zone ────────────────────────────────────────

  void _spawnParticle() {
    switch (zone) {
      case 0:
        _spawnWhisperingWoods();
      case 1:
        _spawnShimmerShore();
      case 2:
        _spawnCrystalPeaks();
      case 3:
        _spawnSkywardKingdom();
      case 4:
        _spawnCelestialCrown();
    }
  }

  void _spawnWhisperingWoods() {
    final isFirefly = _rng.nextDouble() < 0.35;
    final colors = ZoneColors.particles[0];
    particles.add(_Particle(
      x: _rng.nextDouble() * size.width,
      y: size.height + 20 + _rng.nextDouble() * 40,
      vy: isFirefly ? _lerp(-20, -45, _rng.nextDouble()) : _lerp(-30, -60, _rng.nextDouble()),
      vx: (_rng.nextDouble() - 0.5) * 8,
      size: isFirefly ? 3.0 + _rng.nextDouble() * 3.0 : 8.0 + _rng.nextDouble() * 10.0,
      opacity: isFirefly ? 0.5 + _rng.nextDouble() * 0.4 : 0.2 + _rng.nextDouble() * 0.25,
      rotation: _rng.nextDouble() * 2 * pi,
      rotationSpeed: (_rng.nextDouble() - 0.5) * 1.2,
      wobblePhase: _rng.nextDouble() * 2 * pi,
      wobbleSpeed: 0.6 + _rng.nextDouble() * 0.6,
      color: isFirefly ? colors[3 + _rng.nextInt(2)] : colors[_rng.nextInt(3)],
      type: isFirefly ? 1 : 0, // 0=leaf, 1=firefly
    ));
  }

  void _spawnShimmerShore() {
    final colors = ZoneColors.particles[1];
    particles.add(_Particle(
      x: _rng.nextDouble() * size.width,
      y: size.height * 0.5 + _rng.nextDouble() * size.height * 0.55,
      vy: _lerp(-15, -35, _rng.nextDouble()),
      vx: (_rng.nextDouble() - 0.5) * 6,
      size: 4.0 + _rng.nextDouble() * 8.0,
      opacity: 0.15 + _rng.nextDouble() * 0.25,
      wobblePhase: _rng.nextDouble() * 2 * pi,
      wobbleSpeed: 0.4 + _rng.nextDouble() * 0.5,
      color: colors[_rng.nextInt(colors.length)],
      type: 0, // bubble
    ));
  }

  void _spawnCrystalPeaks() {
    final colors = ZoneColors.particles[2];
    final isCrystal = _rng.nextDouble() < 0.25;
    particles.add(_Particle(
      x: _rng.nextDouble() * size.width,
      y: -10 - _rng.nextDouble() * 30,
      vy: _lerp(20, 50, _rng.nextDouble()),
      vx: (_rng.nextDouble() - 0.5) * 15,
      size: isCrystal ? 3.0 + _rng.nextDouble() * 4.0 : 2.0 + _rng.nextDouble() * 3.5,
      opacity: 0.25 + _rng.nextDouble() * 0.35,
      rotation: _rng.nextDouble() * 2 * pi,
      rotationSpeed: isCrystal ? (_rng.nextDouble() - 0.5) * 2.0 : 0,
      wobblePhase: _rng.nextDouble() * 2 * pi,
      wobbleSpeed: 0.3 + _rng.nextDouble() * 0.5,
      color: colors[_rng.nextInt(colors.length)],
      type: isCrystal ? 1 : 0, // 0=snowflake, 1=crystal
    ));
  }

  void _spawnSkywardKingdom() {
    final colors = ZoneColors.particles[3];
    final isBird = _rng.nextDouble() < 0.2;
    particles.add(_Particle(
      x: isBird ? -20.0 : _rng.nextDouble() * size.width,
      y: isBird
          ? size.height * 0.1 + _rng.nextDouble() * size.height * 0.3
          : _rng.nextDouble() * size.height * 0.6,
      vx: isBird
          ? 20 + _rng.nextDouble() * 25
          : _lerp(5, 15, _rng.nextDouble()),
      vy: isBird
          ? (_rng.nextDouble() - 0.5) * 5
          : (_rng.nextDouble() - 0.5) * 3,
      size: isBird ? 4.0 + _rng.nextDouble() * 3.0 : 20.0 + _rng.nextDouble() * 30.0,
      opacity: isBird ? 0.2 + _rng.nextDouble() * 0.15 : 0.06 + _rng.nextDouble() * 0.08,
      wobblePhase: _rng.nextDouble() * 2 * pi,
      wobbleSpeed: 0.2 + _rng.nextDouble() * 0.3,
      color: colors[_rng.nextInt(colors.length)],
      type: isBird ? 1 : 0, // 0=cloud, 1=bird
    ));
  }

  void _spawnCelestialCrown() {
    final colors = ZoneColors.particles[4];
    particles.add(_Particle(
      x: _rng.nextDouble() * size.width,
      y: _rng.nextDouble() * size.height,
      size: 1.0 + _rng.nextDouble() * 2.5,
      opacity: 0.1 + _rng.nextDouble() * 0.5,
      wobblePhase: _rng.nextDouble() * 2 * pi,
      wobbleSpeed: 0.3 + _rng.nextDouble() * 1.5,
      color: colors[_rng.nextInt(colors.length)],
      type: 0, // star
    ));
  }

  void _spawnShootingStar() {
    if (shootingStars.length >= 2) return;
    final startX = _rng.nextDouble() * size.width * 0.8;
    final startY = _rng.nextDouble() * size.height * 0.4;
    final angle = pi / 6 + _rng.nextDouble() * pi / 6; // 30-60 degrees
    final speed = 250 + _rng.nextDouble() * 200;
    shootingStars.add(_ShootingStar(
      x: startX,
      y: startY,
      vx: cos(angle) * speed,
      vy: sin(angle) * speed,
      length: 40 + _rng.nextDouble() * 40,
      opacity: 0.5 + _rng.nextDouble() * 0.3,
      duration: 0.6 + _rng.nextDouble() * 0.6,
    ));
  }

  // ── Update logic ────────────────────────────────────────────────

  void _updateParticles(double dt) {
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];

      // Movement
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rotation += p.rotationSpeed * dt;
      p.life += dt;

      // Wobble
      p.x += sin(time * p.wobbleSpeed * 2 * pi + p.wobblePhase) * 12 * dt;

      // Zone-specific twinkle for stars (zone 4)
      if (zone == 4 && p.type == 0) {
        // Stars twinkle: modulate opacity with sine
        final twinkle = 0.5 + 0.5 * sin(time * p.wobbleSpeed * 2 * pi + p.wobblePhase);
        p.opacity = (0.1 + twinkle * 0.55).clamp(0.0, 0.7);
      }

      // Firefly pulse (zone 0, type 1)
      if (zone == 0 && p.type == 1) {
        final pulse = 0.5 + 0.5 * sin(time * 2.5 + p.wobblePhase);
        p.opacity = (0.2 + pulse * 0.7).clamp(0.0, 0.9);
      }

      // Remove off-screen particles
      bool remove = false;
      switch (zone) {
        case 0: // float up
          remove = p.y < -50;
        case 1: // float up
          remove = p.y < -50;
        case 2: // fall down
          remove = p.y > size.height + 50;
        case 3: // drift right
          remove = p.x > size.width + 80;
        case 4: // stars live until life > threshold, then fade
          if (p.life > 8 + _rng.nextDouble() * 6) remove = true;
        default:
          remove = p.y < -80 || p.y > size.height + 80 ||
              p.x < -80 || p.x > size.width + 80;
      }

      if (remove) {
        particles.removeAt(i);
      }
    }
  }

  void _updateShootingStars(double dt) {
    for (int i = shootingStars.length - 1; i >= 0; i--) {
      final s = shootingStars[i];
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.elapsed += dt;

      // Fade in then out
      final t = s.elapsed / s.duration;
      if (t < 0.2) {
        s.opacity = (t / 0.2) * 0.8;
      } else {
        s.opacity = 0.8 * (1.0 - ((t - 0.2) / 0.8)).clamp(0.0, 1.0);
      }

      if (s.elapsed >= s.duration) {
        shootingStars.removeAt(i);
      }
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

// =====================================================================
//  Painter
// =====================================================================

class _ZonePainter extends CustomPainter {
  final _ZoneSimulation sim;

  _ZonePainter({required this.sim}) : super(repaint: sim);

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient
    _paintGradient(canvas, size);

    // Zone-specific decorations
    switch (sim.zone) {
      case 1:
        _paintWaves(canvas, size);
      default:
        break;
    }

    // Particles
    for (final p in sim.particles) {
      switch (sim.zone) {
        case 0:
          p.type == 1
              ? _paintFirefly(canvas, p)
              : _paintLeaf(canvas, p);
        case 1:
          _paintBubble(canvas, p);
        case 2:
          p.type == 1
              ? _paintCrystal(canvas, p)
              : _paintSnowflake(canvas, p);
        case 3:
          p.type == 1
              ? _paintBird(canvas, p)
              : _paintCloud(canvas, p);
        case 4:
          _paintStar(canvas, p);
      }
    }

    // Shooting stars (zone 4)
    for (final s in sim.shootingStars) {
      _paintShootingStar(canvas, s);
    }
  }

  // ── Background gradient ─────────────────────────────────────────

  void _paintGradient(Canvas canvas, Size size) {
    final colors = ZoneColors.gradients[sim.zone];
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors[0], colors[1], AppColors.background],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ── Zone 0: Whispering Woods ────────────────────────────────────

  void _paintLeaf(Canvas canvas, _Particle p) {
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.rotation);

    // Leaf shape: elongated ellipse
    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.4);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: p.size,
      height: p.size * 0.45,
    );
    canvas.drawOval(rect, glowPaint);
    canvas.drawOval(rect, paint);

    // Leaf vein (stem line)
    final veinPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.5)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-p.size * 0.4, 0),
      Offset(p.size * 0.4, 0),
      veinPaint,
    );

    canvas.restore();
  }

  void _paintFirefly(Canvas canvas, _Particle p) {
    // Glowing dot
    final glowPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2);
    canvas.drawCircle(Offset(p.x, p.y), p.size * 1.5, glowPaint);

    final corePaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(p.x, p.y), p.size * 0.5, corePaint);
  }

  // ── Zone 1: Shimmer Shore ───────────────────────────────────────

  void _paintBubble(Canvas canvas, _Particle p) {
    // Bubble: circle with subtle rim highlight
    final rimPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(Offset(p.x, p.y), p.size, rimPaint);

    // Subtle fill
    final fillPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(p.x, p.y), p.size, fillPaint);

    // Highlight spot
    final hlPaint = Paint()
      ..color = Colors.white.withValues(alpha: p.opacity * 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(p.x - p.size * 0.3, p.y - p.size * 0.3),
      p.size * 0.2,
      hlPaint,
    );
  }

  void _paintWaves(Canvas canvas, Size size) {
    // Gentle animated wave at the bottom
    final waveHeight = size.height * 0.06;
    final baseY = size.height * 0.88;

    for (int layer = 0; layer < 3; layer++) {
      final layerOffset = layer * 0.8;
      final alpha = 0.04 - layer * 0.01;
      final path = Path();
      path.moveTo(0, size.height);
      path.lineTo(0, baseY + layer * 8);

      for (double x = 0; x <= size.width; x += 4) {
        final y = baseY +
            layer * 8 +
            sin((x / size.width * 2 * pi) + sim._wavePhase * 2 * pi + layerOffset) * waveHeight +
            sin((x / size.width * 4 * pi) + sim._wavePhase * 3 * pi + layerOffset * 2) * waveHeight * 0.3;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.close();

      final paint = Paint()
        ..color = const Color(0xFF48A9C5).withValues(alpha: alpha.clamp(0.01, 0.05))
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
    }
  }

  // ── Zone 2: Crystal Peaks ───────────────────────────────────────

  void _paintSnowflake(Canvas canvas, _Particle p) {
    // Simple dot snowflake with glow
    final glowPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.5);
    canvas.drawCircle(Offset(p.x, p.y), p.size, glowPaint);

    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(p.x, p.y), p.size * 0.6, paint);
  }

  void _paintCrystal(Canvas canvas, _Particle p) {
    canvas.save();
    canvas.translate(p.x, p.y);
    canvas.rotate(p.rotation);

    // Diamond shape
    final path = Path()
      ..moveTo(0, -p.size)
      ..lineTo(p.size * 0.5, 0)
      ..lineTo(0, p.size)
      ..lineTo(-p.size * 0.5, 0)
      ..close();

    final glowPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size);
    canvas.drawPath(path, glowPaint);

    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  // ── Zone 3: Skyward Kingdom ─────────────────────────────────────

  void _paintCloud(Canvas canvas, _Particle p) {
    // Soft blurred ellipse cluster
    final cx = p.x;
    final cy = p.y;
    final s = p.size;

    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5);

    // Main blob
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: s, height: s * 0.45),
      paint,
    );
    // Left puff
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - s * 0.3, cy + s * 0.05), width: s * 0.6, height: s * 0.35),
      paint,
    );
    // Right puff
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + s * 0.3, cy - s * 0.02), width: s * 0.55, height: s * 0.3),
      paint,
    );
  }

  void _paintBird(Canvas canvas, _Particle p) {
    canvas.save();
    canvas.translate(p.x, p.y);

    // Simple V-shape bird
    final wingFlap = sin(sim.time * 4 + p.wobblePhase) * 0.3;
    final paint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(-p.size, -p.size * wingFlap)
      ..quadraticBezierTo(-p.size * 0.3, -p.size * 0.4, 0, 0)
      ..quadraticBezierTo(p.size * 0.3, -p.size * 0.4, p.size, -p.size * wingFlap);

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  // ── Zone 4: Celestial Crown ─────────────────────────────────────

  void _paintStar(Canvas canvas, _Particle p) {
    // Core dot
    final corePaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(p.x, p.y), p.size * 0.5, corePaint);

    // Glow halo
    final glowPaint = Paint()
      ..color = p.color.withValues(alpha: p.opacity * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2);
    canvas.drawCircle(Offset(p.x, p.y), p.size, glowPaint);

    // Cross-shaped twinkle rays for brighter stars
    if (p.opacity > 0.4) {
      final rayLen = p.size * 2.5 * p.opacity;
      final rayPaint = Paint()
        ..color = p.color.withValues(alpha: p.opacity * 0.25)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(p.x - rayLen, p.y),
        Offset(p.x + rayLen, p.y),
        rayPaint,
      );
      canvas.drawLine(
        Offset(p.x, p.y - rayLen),
        Offset(p.x, p.y + rayLen),
        rayPaint,
      );
    }
  }

  void _paintShootingStar(Canvas canvas, _ShootingStar s) {
    if (s.opacity <= 0) return;

    // Compute tail direction (opposite of velocity)
    final speed = sqrt(s.vx * s.vx + s.vy * s.vy);
    if (speed < 1) return;
    final dx = -s.vx / speed;
    final dy = -s.vy / speed;

    final headPos = Offset(s.x, s.y);
    final tailPos = Offset(s.x + dx * s.length, s.y + dy * s.length);

    // Gradient trail
    final trailPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: s.opacity),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromPoints(headPos, tailPos))
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(headPos, tailPos, trailPaint);

    // Bright head
    final headPaint = Paint()
      ..color = Colors.white.withValues(alpha: s.opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(headPos, 2, headPaint);
  }

  @override
  bool shouldRepaint(covariant _ZonePainter oldDelegate) => false;
}

// =====================================================================
//  Helper: get zone index from level
// =====================================================================

/// Returns the zone index (0-4) for a given 1-based level number.
int zoneIndexForLevel(int level) {
  for (int i = 0; i < 5; i++) {
    final z = [
      (1, 5),
      (6, 10),
      (11, 15),
      (16, 19),
      (20, 22),
    ][i];
    if (level >= z.$1 && level <= z.$2) return i;
  }
  return 4; // default to last zone
}
