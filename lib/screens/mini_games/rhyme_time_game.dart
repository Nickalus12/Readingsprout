import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/rhyme_words.dart';
import '../../data/sticker_definitions.dart';
import '../../models/player_profile.dart';
import '../../services/audio_service.dart';
import '../../services/profile_service.dart';
import '../../services/progress_service.dart';
import '../../models/game_difficulty_params.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

class RhymeTimeGame extends StatefulWidget {
  final ProgressService progressService;
  final AudioService audioService;
  final String playerName;
  final ProfileService? profileService;
  final bool hintsEnabled;
  final GameDifficultyParams? difficultyParams;

  const RhymeTimeGame({
    super.key,
    required this.progressService,
    required this.audioService,
    required this.playerName,
    this.profileService,
    this.hintsEnabled = true,
    this.difficultyParams,
  });

  @override
  State<RhymeTimeGame> createState() => _RhymeTimeGameState();
}

// ── Data models ─────────────────────────────────────────────────────────────

class _WordBubble {
  final int id;
  final String word;
  final bool isCorrect;
  double x, y;
  double vx, vy;
  double radius;
  double wobblePhase;
  double popTimer;
  bool popped;
  Color color;

  _WordBubble({
    required this.id,
    required this.word,
    required this.isCorrect,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.wobblePhase,
    required this.color,
  })  : popTimer = 0,
        popped = false;
}

class _PopParticle {
  double x, y, vx, vy, size, life;
  Color color;
  _PopParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
  });
}

class _FloatingNote {
  double x, y;
  double opacity = 1.0;
  String text;
  double vy = -60;
  _FloatingNote({
    required this.x,
    required this.y,
    required this.text,
  });
}

// ── Simulation ChangeNotifier ───────────────────────────────────────────────

class _RhymeTimeSim extends ChangeNotifier {
  final Random rng;
  List<_WordBubble> bubbles = [];
  final List<_PopParticle> particles = [];
  final List<_FloatingNote> floatingNotes = [];
  double screenShake = 0;
  double flashOpacity = 0;
  Color? flashColor;
  Size screenSize = Size.zero;

  static const double bubbleZoneTop = 0.22;
  static const double bubbleZoneBottom = 0.88;

  _RhymeTimeSim({required this.rng});

  void tick(double dt) {
    if (screenSize == Size.zero) return;

    for (final b in bubbles) {
      if (b.popped) continue;
      b.wobblePhase += dt * 2;
      b.x += b.vx * dt;
      b.y += b.vy * dt;

      if (rng.nextDouble() < 0.02) {
        b.vx += (rng.nextDouble() - 0.5) * 0.04;
        b.vy += (rng.nextDouble() - 0.5) * 0.03;
      }

      final rNorm = b.radius / screenSize.width;
      if (b.x < rNorm) {
        b.x = rNorm;
        b.vx = b.vx.abs();
      }
      if (b.x > 1 - rNorm) {
        b.x = 1 - rNorm;
        b.vx = -b.vx.abs();
      }

      final rNormY = b.radius / screenSize.height;
      final topBound = bubbleZoneTop + rNormY;
      final bottomBound = bubbleZoneBottom - rNormY;
      if (b.y < topBound) {
        b.y = topBound;
        b.vy = b.vy.abs();
      }
      if (b.y > bottomBound) {
        b.y = bottomBound;
        b.vy = -b.vy.abs();
      }

      if (b.popTimer > 0) {
        b.popTimer -= dt;
        if (b.popTimer <= 0) b.popped = true;
      }
    }

    for (int i = 0; i < bubbles.length; i++) {
      for (int j = i + 1; j < bubbles.length; j++) {
        final a = bubbles[i];
        final b = bubbles[j];
        if (a.popped || b.popped) continue;
        final dx = (a.x - b.x) * screenSize.width;
        final dy = (a.y - b.y) * screenSize.height;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = a.radius + b.radius + 8;
        if (dist < minDist && dist > 0) {
          final nx = dx / dist;
          final ny = dy / dist;
          final push = (minDist - dist) / screenSize.width * 0.5;
          a.vx += nx * push;
          a.vy += ny * push / (screenSize.height / screenSize.width);
          b.vx -= nx * push;
          b.vy -= ny * push / (screenSize.height / screenSize.width);
        }
      }
    }

    for (final b in bubbles) {
      if (b.popped) continue;
      b.vx *= 0.997;
      b.vy *= 0.997;
      final speed = sqrt(b.vx * b.vx + b.vy * b.vy);
      if (speed > 0.35) {
        b.vx = b.vx / speed * 0.35;
        b.vy = b.vy / speed * 0.35;
      }
      if (speed < 0.03) {
        b.vx += (rng.nextDouble() - 0.5) * 0.06;
        b.vy += (rng.nextDouble() - 0.5) * 0.05;
      }
    }

    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 120 * dt;
      p.life -= dt * 2;
      if (p.life <= 0) particles.removeAt(i);
    }

    for (int i = floatingNotes.length - 1; i >= 0; i--) {
      final n = floatingNotes[i];
      n.y += n.vy * dt;
      n.opacity -= dt * 1.5;
      if (n.opacity <= 0) floatingNotes.removeAt(i);
    }

    if (screenShake > 0) screenShake *= 0.9;
    if (screenShake < 0.5) screenShake = 0;

    if (flashOpacity > 0) {
      flashOpacity -= dt * 4;
      if (flashOpacity < 0) flashOpacity = 0;
    }

    notifyListeners();
  }

  _WordBubble? hitTest(Offset localPos) {
    if (screenSize == Size.zero) return null;
    for (final b in bubbles) {
      if (b.popped || b.popTimer > 0) continue;
      final bx = b.x * screenSize.width;
      final by = b.y * screenSize.height + sin(b.wobblePhase) * 3;
      final dx = localPos.dx - bx;
      final dy = localPos.dy - by;
      if (dx * dx + dy * dy <= b.radius * b.radius) return b;
    }
    return null;
  }

  void spawnPopBurst(double cx, double cy, Color color, int count) {
    for (int i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = 80 + rng.nextDouble() * 160;
      particles.add(_PopParticle(
        x: cx,
        y: cy,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 40,
        size: 3 + rng.nextDouble() * 5,
        life: 1.0,
        color: Color.lerp(color, Colors.white, rng.nextDouble() * 0.4)!,
      ));
    }
  }
}

// ── State ───────────────────────────────────────────────────────────────────

class _RhymeTimeGameState extends State<RhymeTimeGame>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late final _RhymeTimeSim _sim;

  late final int _gameDurationSecs;
  late final int _maxLives;
  late final int _startChoices;
  late final int _maxChoices;

  bool _gameStarted = false;
  bool _gameOver = false;
  bool _introPlayed = false;
  int _score = 0;
  late int _lives;
  int _combo = 0;
  int _bestCombo = 0;
  int _wordsMatched = 0;
  late int _timeRemaining;
  Timer? _gameTimer;

  String _targetWord = '';
  int _nextBubbleId = 0;
  bool _roundTransitioning = false;

  late int _currentChoices;

  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  late List<RhymeFamily> _shuffledFamilies;
  int _familyIndex = 0;

  static const _roundColors = [
    Color(0xFF00D4FF),
    Color(0xFFFF69B4),
    Color(0xFF10B981),
    Color(0xFFFFD700),
    Color(0xFF8B5CF6),
    Color(0xFFFF6B6B),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
  ];

  late final Stopwatch _sessionTimer;

  @override
  void initState() {
    super.initState();
    _sim = _RhymeTimeSim(rng: _rng);
    _gameDurationSecs = widget.difficultyParams?.gameDurationSeconds.toInt() ?? 60;
    _maxLives = widget.difficultyParams?.lives ?? 3;
    _startChoices = widget.difficultyParams?.distractorCount ?? 3;
    _maxChoices = (_startChoices + 3).clamp(_startChoices, 8);
    _lives = _maxLives;
    _timeRemaining = _gameDurationSecs;
    _currentChoices = _startChoices;
    _sessionTimer = Stopwatch()..start();
    _shuffledFamilies = List.of(rhymeFamilies)..shuffle(_rng);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _gameTimer?.cancel();
    _sessionTimer.stop();
    _sim.dispose();
    super.dispose();
  }

  // ── Game lifecycle ────────────────────────────────────────────────────────

  void _playIntro() {
    widget.audioService.playWord('rhyme_time_intro');
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _score = 0;
      _lives = _maxLives;
      _combo = 0;
      _bestCombo = 0;
      _wordsMatched = 0;
      _timeRemaining = _gameDurationSecs;
      _currentChoices = _startChoices;
      _familyIndex = 0;
      _shuffledFamilies = List.of(rhymeFamilies)..shuffle(_rng);
      _sim.particles.clear();
      _sim.floatingNotes.clear();
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _gameOver) return;
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 0) _endGame();
      });
    });

    _loadRound();
  }

  void _endGame() {
    _gameTimer?.cancel();
    setState(() => _gameOver = true);
    _awardMiniGameStickers();
  }

  void _awardMiniGameStickers() {
    final ps = widget.profileService;
    if (ps == null) return;
    final earned = StickerDefinitions.miniGameStickersForScore('rhyme_time', _score);
    for (final id in earned) {
      if (!ps.hasSticker(id)) {
        final def = StickerDefinitions.byId(id);
        if (def != null) {
          ps.awardSticker(StickerRecord(
            stickerId: id,
            dateEarned: DateTime.now(),
            category: def.category.name,
          ));
        }
      }
    }
  }

  void _loadRound() {
    if (_gameOver) return;

    if (_familyIndex >= _shuffledFamilies.length) {
      _familyIndex = 0;
      _shuffledFamilies.shuffle(_rng);
    }
    final family = _shuffledFamilies[_familyIndex++];

    final familyWords = List.of(family.words)..shuffle(_rng);
    if (familyWords.isEmpty) return;
    _targetWord = familyWords.first;

    final correctWord = familyWords.length > 1
        ? familyWords.firstWhere((w) => w != _targetWord, orElse: () => familyWords.first)
        : familyWords.first;

    final otherWords = <String>[];
    for (final f in _shuffledFamilies) {
      if (f.familyName != family.familyName) {
        otherWords.addAll(f.words);
      }
    }
    otherWords.shuffle(_rng);

    final numDistractors = _currentChoices - 1;
    final distractors = otherWords.take(numDistractors).toList();

    final allChoices = <_WordBubble>[];
    final roundColor = _roundColors[_wordsMatched % _roundColors.length];

    allChoices.add(_makeBubble(correctWord, true, roundColor));
    for (final d in distractors) {
      allChoices.add(_makeBubble(d, false, roundColor));
    }
    allChoices.shuffle(_rng);

    _sim.bubbles = allChoices;
    _roundTransitioning = false;
    setState(() {
      // Update target word display in HUD
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && !_gameOver) {
        widget.audioService.playWord(_targetWord);
      }
    });
  }

  _WordBubble _makeBubble(String word, bool correct, Color roundColor) {
    const xMargin = 0.08;
    return _WordBubble(
      id: _nextBubbleId++,
      word: word,
      isCorrect: correct,
      x: xMargin + _rng.nextDouble() * (1.0 - 2 * xMargin),
      y: _RhymeTimeSim.bubbleZoneTop + 0.05 +
          _rng.nextDouble() * (_RhymeTimeSim.bubbleZoneBottom - _RhymeTimeSim.bubbleZoneTop - 0.1),
      vx: (_rng.nextDouble() - 0.5) * 0.18,
      vy: (_rng.nextDouble() - 0.5) * 0.14,
      radius: 42,
      wobblePhase: _rng.nextDouble() * pi * 2,
      color: (correct && widget.hintsEnabled)
          ? roundColor
          : [
              const Color(0xFF4B5563),
              const Color(0xFF6B7280),
              const Color(0xFF374151),
              const Color(0xFF525E6E),
            ][_rng.nextInt(4)],
    );
  }

  // ── Tick ───────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final dtRaw = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final dt = dtRaw.clamp(0.0, 0.05);
    if (_sim.screenSize == Size.zero || !_gameStarted || _gameOver) return;

    _sim.tick(dt);
  }

  // ── Bubble tap ────────────────────────────────────────────────────────────

  void _onCanvasTap(TapUpDetails details) {
    if (_gameOver || _roundTransitioning) return;
    final bubble = _sim.hitTest(details.localPosition);
    if (bubble != null) _onBubbleTap(bubble);
  }

  void _onBubbleTap(_WordBubble bubble) {
    if (bubble.popped || bubble.popTimer > 0 || _roundTransitioning) return;
    if (_gameOver) return;

    widget.audioService.playWord(bubble.word);

    if (bubble.isCorrect) {
      _onCorrectTap(bubble);
    } else {
      _onWrongTap(bubble);
    }
  }

  void _onCorrectTap(_WordBubble bubble) {
    Haptics.success();
    _combo++;
    if (_combo > _bestCombo) _bestCombo = _combo;
    final comboMultiplier = _combo >= 5 ? 3 : (_combo >= 3 ? 2 : 1);
    final points = 100 * comboMultiplier;
    _wordsMatched++;

    bubble.popTimer = 0.3;

    final bx = bubble.x * _sim.screenSize.width;
    final by = bubble.y * _sim.screenSize.height;
    _sim.spawnPopBurst(bx, by, bubble.color, 16);

    _sim.floatingNotes.add(_FloatingNote(
      x: bx,
      y: by - 30,
      text: '+$points${_combo >= 3 ? ' x$comboMultiplier' : ''}',
    ));

    if (_combo >= 3) {
      _sim.floatingNotes.add(_FloatingNote(
        x: bx,
        y: by - 60,
        text: '$_combo combo!',
      ));
    }

    _sim.flashColor = AppColors.success;
    _sim.flashOpacity = 0.15;

    if (_wordsMatched % 3 == 0 && _currentChoices < _maxChoices) {
      _currentChoices++;
    }

    _roundTransitioning = true;

    setState(() {
      _score += points;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || _gameOver) return;
      int delay = 0;
      for (final b in _sim.bubbles) {
        if (!b.popped && b.popTimer <= 0) {
          Future.delayed(Duration(milliseconds: delay), () {
            if (!mounted) return;
            b.popTimer = 0.2;
            final px = b.x * _sim.screenSize.width;
            final py = b.y * _sim.screenSize.height;
            _sim.spawnPopBurst(px, py, b.color.withValues(alpha: 0.5), 6);
          });
          delay += 50;
        }
      }

      Future.delayed(Duration(milliseconds: delay + 300), () {
        if (mounted && !_gameOver) _loadRound();
      });
    });
  }

  void _onWrongTap(_WordBubble bubble) {
    Haptics.wrong();
    _combo = 0;
    _sim.screenShake = 8;

    _sim.flashColor = AppColors.error;
    _sim.flashOpacity = 0.2;

    bubble.popTimer = 0.25;
    final bx = bubble.x * _sim.screenSize.width;
    final by = bubble.y * _sim.screenSize.height;
    _sim.spawnPopBurst(bx, by, AppColors.error, 8);

    final wrongMessages = ['Not quite!', 'Hmm, nope!', 'Keep trying!', 'Almost!'];
    _sim.floatingNotes.add(_FloatingNote(
      x: bx,
      y: by - 30,
      text: wrongMessages[_rng.nextInt(wrongMessages.length)],
    ));

    setState(() {
      _lives--;
    });

    if (_lives <= 0) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _endGame();
      });
    }
  }

  void _replayTarget() {
    widget.audioService.playWord(_targetWord);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(builder: (context, constraints) {
        _sim.screenSize = Size(constraints.maxWidth, constraints.maxHeight);
        return _gameOver
            ? _buildGameOver()
            : _gameStarted
                ? _buildGameplay()
                : _buildStartScreen();
      }),
    );
  }

  // ── Start screen ──────────────────────────────────────────────────────────

  Widget _buildStartScreen() {
    if (!_introPlayed) {
      _introPlayed = true;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_gameStarted) _playIntro();
      });
    }

    return Stack(
      children: [
        _buildBackground(),
        SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AppColors.primaryText),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              Text(
                'Rhyme Time',
                style: AppFonts.fredoka(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: AppColors.magenta.withValues(alpha: 0.6),
                      blurRadius: 24,
                    ),
                    Shadow(
                      color: AppColors.violet.withValues(alpha: 0.4),
                      blurRadius: 48,
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    curve: Curves.easeOutBack,
                    duration: 600.ms,
                  ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: _playIntro,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.magenta.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.magenta.withValues(alpha: 0.4),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.magenta.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.volume_up_rounded,
                      color: AppColors.magenta, size: 48),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                      begin: 1.0,
                      end: 1.1,
                      duration: 1200.ms,
                      curve: Curves.easeInOut)
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 500.ms),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => widget.audioService.playWord('cat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.electricBlue.withValues(alpha: 0.2),
                        border: Border.all(
                          color: AppColors.electricBlue.withValues(alpha: 0.6),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.electricBlue.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.volume_up_rounded,
                              color: AppColors.electricBlue, size: 22),
                          const SizedBox(height: 2),
                          Text(
                            'cat',
                            style: AppFonts.fredoka(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.electricBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                          begin: 1.0,
                          end: 1.08,
                          duration: 1500.ms,
                          curve: Curves.easeInOut),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: AppColors.secondaryText, size: 28),
                  ),

                  GestureDetector(
                    onTap: () => widget.audioService.playWord('hat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.magenta.withValues(alpha: 0.2),
                        border: Border.all(
                          color: AppColors.magenta.withValues(alpha: 0.6),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.magenta.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app_rounded,
                              color: AppColors.magenta, size: 22),
                          const SizedBox(height: 2),
                          Text(
                            'hat',
                            style: AppFonts.fredoka(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.magenta,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(
                          begin: 1.0,
                          end: 1.08,
                          duration: 1500.ms,
                          delay: 200.ms,
                          curve: Curves.easeInOut),
                ],
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

              const Spacer(flex: 2),

              GestureDetector(
                onTap: _startGame,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.magenta.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                      const SizedBox(width: 8),
                      Text(
                        'Play!',
                        style: AppFonts.fredoka(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate(
                    onPlay: (c) => c.repeat(reverse: true),
                  )
                  .scaleXY(
                    begin: 1.0,
                    end: 1.05,
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 500.ms),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ],
    );
  }

  // ── Gameplay ──────────────────────────────────────────────────────────────

  Widget _buildGameplay() {
    return Stack(
      children: [
        _buildBackground(),

        SafeArea(
          child: Column(
            children: [
              _buildHUD(),
              _buildTargetArea(),
            ],
          ),
        ),

        Positioned.fill(
          child: RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: _onCanvasTap,
              child: CustomPaint(
                painter: _RhymeTimeGamePainter(_sim),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHUD() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primaryText,
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_score',
              style: AppFonts.fredoka(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.starGold,
              ),
            ),
          ),

          const Spacer(),

          if (_combo >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.magenta.withValues(alpha: 0.3),
                    AppColors.violet.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.magenta.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                '${_combo}x',
                style: AppFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.magenta,
                ),
              ),
            ),

          const Spacer(),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_maxLives, (i) {
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  i < _lives
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                  color: i < _lives
                      ? AppColors.magenta
                      : AppColors.secondaryText.withValues(alpha: 0.3),
                ),
              );
            }),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _timeRemaining <= 10
                  ? AppColors.error.withValues(alpha: 0.2)
                  : AppColors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: _timeRemaining <= 10
                  ? Border.all(
                      color: AppColors.error.withValues(alpha: 0.5))
                  : null,
            ),
            child: Text(
              '${_timeRemaining}s',
              style: AppFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _timeRemaining <= 10
                    ? AppColors.error
                    : AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetArea() {
    return GestureDetector(
      onTap: _replayTarget,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.electricBlue.withValues(alpha: 0.12),
              AppColors.violet.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.electricBlue.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.electricBlue.withValues(alpha: 0.1),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.volume_up_rounded,
              color: AppColors.electricBlue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'What rhymes with ',
              style: AppFonts.nunito(
                fontSize: 16,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '"$_targetWord"',
              style: AppFonts.fredoka(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.electricBlue,
              ),
            ),
            Text(
              ' ?',
              style: AppFonts.nunito(
                fontSize: 16,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Game Over ─────────────────────────────────────────────────────────────

  Widget _buildGameOver() {
    final isGood = _wordsMatched >= 5;
    final isStar = _wordsMatched >= 10;

    String title;
    String subtitle;
    IconData icon;
    Color accentColor;

    if (isStar) {
      title = 'Rhyme Star!';
      subtitle = 'You are a rhyming superstar!';
      icon = Icons.star_rounded;
      accentColor = AppColors.starGold;
    } else if (isGood) {
      title = 'Awesome!';
      subtitle = 'You matched so many rhymes!';
      icon = Icons.emoji_events_rounded;
      accentColor = AppColors.magenta;
    } else if (_wordsMatched >= 2) {
      title = 'Good Job!';
      subtitle = 'Keep practicing your rhymes!';
      icon = Icons.thumb_up_rounded;
      accentColor = AppColors.electricBlue;
    } else {
      title = 'Nice Try!';
      subtitle = 'Rhyming gets easier with practice!';
      icon = Icons.favorite_rounded;
      accentColor = AppColors.violet;
    }

    return Stack(
      children: [
        _buildBackground(),
        SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: accentColor)
                    .animate()
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      curve: Curves.easeOutBack,
                      duration: 600.ms,
                    ),

                const SizedBox(height: 16),

                Text(
                  title,
                  style: AppFonts.fredoka(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: accentColor.withValues(alpha: 0.5),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                const SizedBox(height: 6),

                Text(
                  subtitle,
                  style: AppFonts.nunito(
                    fontSize: 16,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 400.ms),

                const SizedBox(height: 24),

                _buildStatRow(Icons.star_rounded, AppColors.starGold,
                    'Score', '$_score', 'score'),
                const SizedBox(height: 8),
                _buildStatRow(Icons.check_circle_rounded, AppColors.success,
                    'Rhymes Found', '$_wordsMatched', 'rhymes_found'),
                const SizedBox(height: 8),
                _buildStatRow(Icons.local_fire_department_rounded,
                    AppColors.magenta, 'Best Combo', '${_bestCombo}x', 'best_combo'),

                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton('Play Again', Icons.replay_rounded, () {
                      _startGame();
                    }),
                    const SizedBox(width: 16),
                    _buildActionButton('Exit', Icons.home_rounded, () {
                      Navigator.of(context).pop();
                    }),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _speakStat(String statKey) {
    final wordMap = {
      'score': 'score',
      'rhymes_found': 'rhymes',
      'best_combo': 'combo',
    };
    final word = wordMap[statKey];
    if (word != null) {
      widget.audioService.playWord(word);
    }
  }

  Widget _buildStatRow(
      IconData icon, Color color, String label, String value,
      [String? speakKey]) {
    return GestureDetector(
      onTap: speakKey != null ? () => _speakStat(speakKey) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppFonts.nunito(
                fontSize: 14,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: AppFonts.fredoka(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
              ),
            ),
            if (speakKey != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.volume_up_rounded, size: 16,
                  color: AppColors.secondaryText.withValues(alpha: 0.5)),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideX(
          begin: -0.1,
          curve: Curves.easeOut,
          duration: 400.ms,
        );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primaryText),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background ────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F0A1E),
            Color(0xFF1A1035),
            Color(0xFF12082A),
          ],
        ),
      ),
    );
  }
}

// ── Game Painter ─────────────────────────────────────────────────────────────

class _RhymeTimeGamePainter extends CustomPainter {
  final _RhymeTimeSim sim;

  _RhymeTimeGamePainter(this.sim) : super(repaint: sim);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = sim.rng;

    // Screen shake offset
    if (sim.screenShake > 0) {
      final dx = (rng.nextDouble() - 0.5) * sim.screenShake * 2;
      final dy = (rng.nextDouble() - 0.5) * sim.screenShake * 2;
      canvas.save();
      canvas.translate(dx, dy);
    }

    // Draw bubbles
    for (final b in sim.bubbles) {
      if (b.popped) continue;
      final px = b.x * size.width;
      final py = b.y * size.height;
      final wobble = sin(b.wobblePhase) * 3;
      final scale = b.popTimer > 0 ? 1.0 + (0.3 - b.popTimer) * 2 : 1.0;
      final opacity = b.popTimer > 0
          ? (b.popTimer / 0.3).clamp(0.0, 1.0)
          : 1.0;

      final r = b.radius * scale;
      final center = Offset(px, py + wobble);

      // Shadow/glow
      canvas.drawCircle(
        center,
        r + 4,
        Paint()
          ..color = b.color.withValues(alpha: opacity * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );

      // Bubble fill gradient
      final gradient = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          b.color.withValues(alpha: opacity * 0.5),
          b.color.withValues(alpha: opacity * 0.2),
        ],
      );
      canvas.drawCircle(
        center,
        r,
        Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: r)),
      );

      // Border
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = b.color.withValues(alpha: opacity * 0.7),
      );

      // Word text
      final tp = TextPainter(
        text: TextSpan(
          text: b.word,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: opacity),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: opacity * 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
    }

    // Pop particles
    for (final p in sim.particles) {
      final alpha = p.life.clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * 2,
        Paint()
          ..color = p.color.withValues(alpha: alpha * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size),
      );
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * alpha,
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }

    // Floating score notes
    for (final n in sim.floatingNotes) {
      final tp = TextPainter(
        text: TextSpan(
          text: n.text,
          style: TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: n.opacity.clamp(0.0, 1.0)),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: n.opacity * 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(n.x - tp.width / 2, n.y));
    }

    // Flash overlay
    if (sim.flashOpacity > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = (sim.flashColor ?? Colors.white)
              .withValues(alpha: sim.flashOpacity.clamp(0.0, 1.0)),
      );
    }

    if (sim.screenShake > 0) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RhymeTimeGamePainter old) => false;
}
