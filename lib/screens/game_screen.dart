import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/dolch_words.dart';
import '../models/word.dart';
import '../data/phrase_templates.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../widgets/animated_glow_border.dart';
import '../widgets/letter_tile.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/floating_hearts_bg.dart';

class GameScreen extends StatefulWidget {
  final int level;
  final ProgressService progressService;
  final AudioService audioService;
  final String playerName;

  const GameScreen({
    super.key,
    required this.level,
    required this.progressService,
    required this.audioService,
    this.playerName = '',
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late List<Word> _words;
  int _currentWordIndex = 0;
  int _currentLetterIndex = 0;
  int _mistakesThisWord = 0;
  int _perfectWords = 0; // Track words with zero mistakes
  bool _showingCelebration = false;
  bool _levelComplete = false;
  bool _shaking = false;
  bool _isPlayingAudio = false;
  bool _savingProgress = false;
  String _levelCompletePhrase = '';

  // Track which letters have been correctly typed
  final List<bool> _revealedLetters = [];

  // Animation controllers
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late ConfettiController _confettiController;
  late ConfettiController _levelConfettiController;

  // Focus node for keyboard input
  final FocusNode _focusNode = FocusNode();

  Word get _currentWord => _words[_currentWordIndex];
  String get _targetText => _currentWord.text.toLowerCase();
  bool get _isLastWord => _currentWordIndex >= _words.length - 1;

  GlowState get _screenGlowState {
    if (_levelComplete) return GlowState.celebrate;
    if (_showingCelebration) return GlowState.correct;
    if (_shaking) return GlowState.error;
    if (_isPlayingAudio) return GlowState.listening;
    return GlowState.idle;
  }

  @override
  void initState() {
    super.initState();

    // Load words for this level, shuffle for variety
    _words = List.from(DolchWords.wordsForLevel(widget.level))..shuffle();
    _initRevealedLetters();

    // Shake animation for wrong input
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
        setState(() => _shaking = false);
      }
    });

    // Confetti
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    _levelConfettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Announce the first word after a brief delay
    Future.delayed(const Duration(milliseconds: 600), _announceCurrentWord);
  }

  void _initRevealedLetters() {
    _revealedLetters.clear();
    _revealedLetters.addAll(List.filled(_targetText.length, false));
    _currentLetterIndex = 0;
    _mistakesThisWord = 0;
  }

  Future<void> _announceCurrentWord() async {
    setState(() => _isPlayingAudio = true);
    final ok = await widget.audioService.playWord(_currentWord.text);
    if (mounted) {
      setState(() => _isPlayingAudio = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio not available — tap "Hear Word" to try again'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onKeyPressed(String key) {
    if (_showingCelebration || _levelComplete) return;

    final expectedLetter = _targetText[_currentLetterIndex];

    if (key.toLowerCase() == expectedLetter.toLowerCase()) {
      // Correct letter!
      setState(() {
        _revealedLetters[_currentLetterIndex] = true;
        _currentLetterIndex++;
      });

      // Play the phonetic sound for this letter
      widget.audioService.playLetter(expectedLetter);

      // Check if word is complete
      if (_currentLetterIndex >= _targetText.length) {
        _onWordComplete();
      }
    } else {
      // Wrong letter — shake and retry
      _onWrongLetter();
    }
  }

  void _onWrongLetter() {
    setState(() {
      _shaking = true;
      _mistakesThisWord++;
    });
    _shakeController.forward();
    widget.audioService.playError();
    if (Platform.isAndroid || Platform.isIOS) HapticFeedback.mediumImpact();
  }

  Future<void> _onWordComplete() async {
    // Track perfect words
    if (_mistakesThisWord == 0) _perfectWords++;

    // Save progress BEFORE showing celebration UI to prevent data loss on back-nav
    setState(() => _savingProgress = true);
    final wasLevelComplete = await widget.progressService.recordWordComplete(
      level: widget.level,
      wordText: _currentWord.text,
      mistakes: _mistakesThisWord,
    );
    if (mounted) setState(() => _savingProgress = false);

    // Play success sound + personalized encouragement
    widget.audioService.playSuccess();
    Future.delayed(const Duration(milliseconds: 300), () {
      widget.audioService.playWordComplete(widget.playerName);
    });
    _confettiController.play();
    if (Platform.isAndroid || Platform.isIOS) HapticFeedback.lightImpact();

    setState(() => _showingCelebration = true);

    // Celebrate briefly, then advance
    await Future.delayed(const Duration(milliseconds: 1800));

    if (_isLastWord || wasLevelComplete) {
      // Level complete!
      _levelConfettiController.play();
      widget.audioService.playLevelCompleteEffect();
      Future.delayed(const Duration(milliseconds: 500), () {
        widget.audioService.playLevelComplete(widget.playerName);
      });
      setState(() {
        _showingCelebration = false;
        _levelComplete = true;
        _levelCompletePhrase =
            PhraseTemplates.randomLevelComplete(widget.playerName);
      });
    } else {
      // Next word
      setState(() {
        _showingCelebration = false;
        _currentWordIndex++;
        _initRevealedLetters();
      });

      Future.delayed(
          const Duration(milliseconds: 400), _announceCurrentWord);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _confettiController.stop();
    _confettiController.dispose();
    _levelConfettiController.stop();
    _levelConfettiController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradientIndex =
        (widget.level - 1) % AppColors.levelGradients.length;
    final levelColors = AppColors.levelGradients[gradientIndex];

    return Scaffold(
      body: AnimatedGlowBorder(
        state: _screenGlowState,
        borderRadius: 0,
        strokeWidth: 2,
        glowRadius: 18,
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: (event) {
            if (event is KeyDownEvent && event.character != null) {
              final char = event.character!;
              if (RegExp(r'^[a-zA-Z]$').hasMatch(char)) {
                _onKeyPressed(char);
              }
            }
          },
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Stack(
              children: [
                // ── Background gradient ──────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        levelColors.first.withValues(alpha: 0.12),
                        AppColors.background,
                      ],
                    ),
                  ),
                ),

                // ── Floating hearts (subtle in game) ─────
                const Positioned.fill(
                  child: Opacity(
                    opacity: 0.4,
                    child: FloatingHeartsBackground(
                      cloudZoneHeight: 0.10,
                    ),
                  ),
                ),

                // ── Main content ─────────────────────────
                SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(levelColors),
                      if (_levelComplete)
                        Expanded(child: _buildLevelComplete())
                      else ...[
                        const SizedBox(height: 8),
                        // Progress dots
                        _buildProgressDots(levelColors),
                        const Spacer(flex: 2),

                        // Hear word button
                        _buildHearButton(),
                        const SizedBox(height: 28),

                        // Letter tiles
                        _buildLetterTiles(),
                        const SizedBox(height: 32),

                        // On-screen keyboard
                        _buildKeyboard(levelColors),
                        const Spacer(flex: 1),
                      ],
                    ],
                  ),
                ),

                // ── Celebration overlay ───────────────────
                if (_showingCelebration)
                  CelebrationOverlay(
                    word: _currentWord.text,
                    playerName: widget.playerName,
                  ),

                // ── Confetti ─────────────────────────────
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: pi / 2,
                    maxBlastForce: 5,
                    minBlastForce: 2,
                    emissionFrequency: 0.3,
                    numberOfParticles: 8,
                    gravity: 0.3,
                    colors: AppColors.confettiColors,
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _levelConfettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    maxBlastForce: 15,
                    minBlastForce: 5,
                    emissionFrequency: 0.1,
                    numberOfParticles: 20,
                    gravity: 0.2,
                    colors: AppColors.confettiColors,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────

  Widget _buildHeader(List<Color> levelColors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: _savingProgress ? null : () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: _savingProgress
                  ? AppColors.secondaryText
                  : AppColors.primaryText,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Level ${widget.level}',
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                DolchWords.levelName(widget.level),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Word counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '${_currentWordIndex + 1}/${_words.length}',
              style: GoogleFonts.fredoka(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Progress Dots ───────────────────────────────────────────────

  Widget _buildProgressDots(List<Color> levelColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_words.length, (i) {
          final isDone = i < _currentWordIndex;
          final isCurrent = i == _currentWordIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isCurrent ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isDone
                  ? AppColors.success
                  : isCurrent
                      ? levelColors.first
                      : AppColors.surface,
              border: Border.all(
                color: isDone
                    ? AppColors.success.withValues(alpha: 0.5)
                    : isCurrent
                        ? levelColors.first.withValues(alpha: 0.5)
                        : AppColors.border.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: (isDone || isCurrent)
                  ? [
                      BoxShadow(
                        color: (isDone
                                ? AppColors.success
                                : levelColors.first)
                            .withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  // ── Hear Word Button ────────────────────────────────────────────

  Widget _buildHearButton() {
    return GestureDetector(
      onTap: _announceCurrentWord,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _isPlayingAudio
              ? AppColors.electricBlue.withValues(alpha: 0.15)
              : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isPlayingAudio
                ? AppColors.electricBlue.withValues(alpha: 0.4)
                : AppColors.border.withValues(alpha: 0.5),
          ),
          boxShadow: _isPlayingAudio
              ? [
                  BoxShadow(
                    color:
                        AppColors.electricBlue.withValues(alpha: 0.15),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlayingAudio
                  ? Icons.hearing_rounded
                  : Icons.volume_up_rounded,
              color: AppColors.electricBlue,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              _isPlayingAudio ? 'Listen...' : 'Hear Word',
              style: GoogleFonts.fredoka(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.electricBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Letter Tiles ────────────────────────────────────────────────

  Widget _buildLetterTiles() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        double offsetX = 0;
        if (_shaking) {
          offsetX = sin(_shakeAnimation.value * pi * 4) * 12;
        }
        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: child,
        );
      },
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: List.generate(_targetText.length, (i) {
          return LetterTile(
            letter: _targetText[i],
            isRevealed: _revealedLetters[i],
            isActive: i == _currentLetterIndex && !_showingCelebration,
            isError: _shaking && i == _currentLetterIndex,
          );
        }),
      ),
    );
  }

  // ── On-Screen Keyboard ──────────────────────────────────────────

  Widget _buildKeyboard(List<Color> levelColors) {
    const rows = [
      ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((letter) {
                final isExpected = !_showingCelebration &&
                    !_levelComplete &&
                    _currentLetterIndex < _targetText.length &&
                    letter == _targetText[_currentLetterIndex];

                return _KeyboardKey(
                  letter: letter,
                  isExpected: isExpected,
                  accentColor: levelColors.first,
                  onTap: () => _onKeyPressed(letter),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Level Complete ──────────────────────────────────────────────

  Widget _buildLevelComplete() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star with glow
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.starGold.withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.star_rounded,
                color: AppColors.starGold,
                size: 80,
              ),
            ).animate().scale(
                  begin: const Offset(0.3, 0.3),
                  end: const Offset(1.0, 1.0),
                  curve: Curves.elasticOut,
                  duration: 800.ms,
                ),
            const SizedBox(height: 20),

            Text(
              'Level Complete!',
              style: GoogleFonts.fredoka(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
                shadows: [
                  Shadow(
                    color: AppColors.starGold.withValues(alpha: 0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),

            const SizedBox(height: 8),

            // Personalized phrase
            Text(
              _levelCompletePhrase.isNotEmpty
                  ? _levelCompletePhrase
                  : 'Amazing job!',
              style: GoogleFonts.fredoka(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
                shadows: [
                  Shadow(
                    color: AppColors.success.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 16),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StatChip(
                  icon: Icons.check_circle_rounded,
                  value: '${_words.length}',
                  label: 'Words',
                  color: AppColors.success,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  icon: Icons.star_rounded,
                  value: '$_perfectWords',
                  label: 'Perfect',
                  color: AppColors.starGold,
                ),
              ],
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundButton(
                  label: 'Replay',
                  icon: Icons.replay_rounded,
                  color: AppColors.secondaryText,
                  onTap: () {
                    setState(() {
                      _words.shuffle();
                      _currentWordIndex = 0;
                      _perfectWords = 0;
                      _initRevealedLetters();
                      _levelComplete = false;
                    });
                    Future.delayed(const Duration(milliseconds: 400),
                        _announceCurrentWord);
                  },
                ),
                const SizedBox(width: 24),
                if (widget.level < DolchWords.totalLevels)
                  _RoundButton(
                    label: 'Next',
                    icon: Icons.arrow_forward_rounded,
                    color: AppColors.success,
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => GameScreen(
                            level: widget.level + 1,
                            progressService: widget.progressService,
                            audioService: widget.audioService,
                            playerName: widget.playerName,
                          ),
                          transitionsBuilder: (_, animation, __, child) {
                            return FadeTransition(
                              opacity: CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              ),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}

// ── Keyboard Key ────────────────────────────────────────────────────

class _KeyboardKey extends StatefulWidget {
  final String letter;
  final bool isExpected;
  final Color accentColor;
  final VoidCallback onTap;

  const _KeyboardKey({
    required this.letter,
    required this.isExpected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_KeyboardKey> createState() => _KeyboardKeyState();
}

class _KeyboardKeyState extends State<_KeyboardKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        width: 34,
        height: 46,
        transform: Matrix4.identity()
          ..scale(_pressed ? 0.92 : 1.0, _pressed ? 0.92 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.isExpected
              ? AppColors.electricBlue.withValues(alpha: 0.2)
              : _pressed
                  ? AppColors.surface.withValues(alpha: 0.5)
                  : AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isExpected
                ? AppColors.electricBlue
                : AppColors.border.withValues(alpha: 0.5),
            width: widget.isExpected ? 1.5 : 1,
          ),
          boxShadow: [
            if (widget.isExpected)
              BoxShadow(
                color: AppColors.electricBlue.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
          ],
        ),
        child: Center(
          child: Text(
            widget.letter,
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight:
                  widget.isExpected ? FontWeight.w600 : FontWeight.w400,
              color: widget.isExpected
                  ? AppColors.electricBlue
                  : AppColors.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Round Button ────────────────────────────────────────────────────

class _RoundButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border:
                  Border.all(color: color.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.fredoka(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Chip ───────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
