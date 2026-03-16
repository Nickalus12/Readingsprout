import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../services/audio_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/haptics.dart';

// ---------------------------------------------------------------------------
// Sound Garden — A musical garden sandbox for kids
// ---------------------------------------------------------------------------
// Kids plant musical flowers on a garden grid. Each flower type makes a
// different sound when tapped. Flowers grow through stages (seed → sprout →
// bloom). A "wind" button plays all flowers in sequence creating a melody.
// Learning: pattern recognition, cause-and-effect, sequencing.
// ---------------------------------------------------------------------------

/// Cost in star coins for initial 3-minute session.
const int kSoundGardenCost = 5;

/// Cost in star coins for a 2-minute extension.
const int kSoundGardenExtensionCost = 3;

/// Initial session duration.
const Duration kSoundGardenSessionDuration = Duration(minutes: 3);

/// Extension duration.
const Duration kSoundGardenExtensionDuration = Duration(minutes: 2);

/// Garden grid dimensions.
const int kGardenCols = 5;
const int kGardenRows = 4;

/// Growth stages for flowers.
enum _GrowthStage { empty, seed, sprout, bloom }

/// Types of flowers/instruments.
enum _FlowerType {
  tulip,    // plays letter sounds a-e
  daisy,    // plays letter sounds f-j
  rose,     // plays letter sounds k-o
  sunflower, // plays letter sounds p-t
  bluebell, // plays letter sounds u-z
}

/// A single garden cell.
class _GardenCell {
  _FlowerType? flowerType;
  _GrowthStage stage = _GrowthStage.empty;
  double growthProgress = 0.0;
  double swayAngle = 0.0;
  bool isPlaying = false;
}

/// Colors for each flower type.
const Map<_FlowerType, Color> _flowerColors = {
  _FlowerType.tulip: Color(0xFFFF4444),     // Red
  _FlowerType.daisy: Color(0xFFFFDD44),     // Yellow
  _FlowerType.rose: Color(0xFFFF69B4),      // Pink
  _FlowerType.sunflower: Color(0xFFFF8C00), // Orange
  _FlowerType.bluebell: Color(0xFF6B8CFF),  // Blue
};

/// Names for each flower type (for audio).
const Map<_FlowerType, String> _flowerNames = {
  _FlowerType.tulip: 'tulip',
  _FlowerType.daisy: 'daisy',
  _FlowerType.rose: 'rose',
  _FlowerType.sunflower: 'sunflower',
  _FlowerType.bluebell: 'bluebell',
};

/// Letters assigned to each flower type for sound.
const Map<_FlowerType, List<String>> _flowerLetters = {
  _FlowerType.tulip: ['a', 'b', 'c', 'd', 'e'],
  _FlowerType.daisy: ['f', 'g', 'h', 'i', 'j'],
  _FlowerType.rose: ['k', 'l', 'm', 'n', 'o'],
  _FlowerType.sunflower: ['p', 'q', 'r', 's', 't'],
  _FlowerType.bluebell: ['u', 'v', 'w', 'x', 'y'],
};

class SoundGardenGame extends StatefulWidget {
  final ProgressService progressService;
  final AudioService audioService;
  final String playerName;
  final bool freePlay;

  const SoundGardenGame({
    super.key,
    required this.progressService,
    required this.audioService,
    required this.playerName,
    this.freePlay = false,
  });

  @override
  State<SoundGardenGame> createState() => _SoundGardenGameState();
}

class _SoundGardenGameState extends State<SoundGardenGame>
    with TickerProviderStateMixin {
  // -- Session timer ---------------------------------------------------------
  late int _remainingSeconds;
  Timer? _sessionTimer;
  bool _sessionExpired = false;
  bool _showTimeWarning = false;
  String _timeWarningText = '';

  // -- Garden grid -----------------------------------------------------------
  late List<List<_GardenCell>> _grid;
  _FlowerType _selectedFlower = _FlowerType.tulip;
  bool _isWateringMode = false;

  // -- Wind playback ---------------------------------------------------------
  bool _isPlayingWind = false;

  // -- Animation -------------------------------------------------------------
  late AnimationController _pulseController;
  late AnimationController _swayController;
  Timer? _growthTimer;
  final Random _rng = Random();

  // -- Stats -----------------------------------------------------------------
  int _flowersFullyGrown = 0;

  // -- Mute ------------------------------------------------------------------
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _grid = List.generate(
      kGardenRows,
      (r) => List.generate(kGardenCols, (c) => _GardenCell()),
    );

    _remainingSeconds = widget.freePlay
        ? const Duration(minutes: 999).inSeconds
        : kSoundGardenSessionDuration.inSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Growth timer — every 3 seconds, advance growth
    _growthTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _advanceGrowth();
    });

    _startSessionTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _growthTimer?.cancel();
    _pulseController.dispose();
    _swayController.dispose();
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionExpired) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds == 60) {
          _showTimeWarning = true;
          _timeWarningText = '1 Minute Left!';
          _speakWord('one');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showTimeWarning = false);
          });
        } else if (_remainingSeconds == 30) {
          _showTimeWarning = true;
          _timeWarningText = '30 Seconds Left!';
          _speakWord('thirty');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showTimeWarning = false);
          });
        }
        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          _sessionExpired = true;
          _speakWord('time');
        }
      });
    });
  }

  void _addMoreTime() {
    if (!widget.freePlay) {
      final balance = widget.progressService.starCoins;
      if (balance < kSoundGardenExtensionCost) return;
      widget.progressService.spendStarCoins(kSoundGardenExtensionCost);
    }
    setState(() {
      _remainingSeconds += widget.freePlay
          ? const Duration(minutes: 999).inSeconds
          : kSoundGardenExtensionDuration.inSeconds;
      _sessionExpired = false;
    });
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _timerColor() {
    if (_remainingSeconds > 60) return AppColors.emerald;
    if (_remainingSeconds > 30) return const Color(0xFFFFBB33);
    return AppColors.error;
  }

  Future<void> _speakWord(String word) async {
    if (_isMuted) return;
    await widget.audioService.playWord(word);
  }

  Future<void> _speakLabel(String text) async {
    if (_isMuted) return;
    final ok = await widget.audioService.playWord(text.toLowerCase());
    if (ok) return;
    for (final letter in text.toLowerCase().split('')) {
      if (!mounted || _isMuted) break;
      await widget.audioService.playLetter(letter);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  // -- Garden interactions ---------------------------------------------------

  void _onCellTap(int row, int col) {
    if (_sessionExpired) return;
    final cell = _grid[row][col];

    if (cell.stage == _GrowthStage.empty) {
      // Plant a flower
      setState(() {
        cell.flowerType = _selectedFlower;
        cell.stage = _GrowthStage.seed;
        cell.growthProgress = 0.0;
      });
      Haptics.tap();
      _playFlowerSound(cell);
    } else if (_isWateringMode) {
      // Water to speed up growth
      _waterCell(row, col);
    } else {
      // Tap to play sound
      _playFlowerSound(cell);
      setState(() => cell.isPlaying = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => cell.isPlaying = false);
      });
    }
  }

  void _onCellLongPress(int row, int col) {
    if (_sessionExpired) return;
    final cell = _grid[row][col];
    if (cell.stage != _GrowthStage.empty) {
      // Remove flower
      setState(() {
        cell.flowerType = null;
        cell.stage = _GrowthStage.empty;
        cell.growthProgress = 0.0;
      });
      Haptics.wrong();
    }
  }

  void _waterCell(int row, int col) {
    final cell = _grid[row][col];
    if (cell.stage == _GrowthStage.empty || cell.stage == _GrowthStage.bloom) {
      return;
    }
    setState(() {
      cell.growthProgress += 0.5;
      if (cell.growthProgress >= 1.0) {
        cell.growthProgress = 0.0;
        if (cell.stage == _GrowthStage.seed) {
          cell.stage = _GrowthStage.sprout;
        } else if (cell.stage == _GrowthStage.sprout) {
          cell.stage = _GrowthStage.bloom;
          _flowersFullyGrown++;
        }
      }
    });
    Haptics.correct();
    _playFlowerSound(cell);
  }

  void _advanceGrowth() {
    if (_sessionExpired) return;
    bool changed = false;
    for (final row in _grid) {
      for (final cell in row) {
        if (cell.stage == _GrowthStage.empty ||
            cell.stage == _GrowthStage.bloom) {
          continue;
        }
        cell.growthProgress += 0.15 + _rng.nextDouble() * 0.1;
        if (cell.growthProgress >= 1.0) {
          cell.growthProgress = 0.0;
          if (cell.stage == _GrowthStage.seed) {
            cell.stage = _GrowthStage.sprout;
          } else if (cell.stage == _GrowthStage.sprout) {
            cell.stage = _GrowthStage.bloom;
            _flowersFullyGrown++;
          }
          changed = true;
        }
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  Future<void> _playFlowerSound(_GardenCell cell) async {
    if (_isMuted || cell.flowerType == null) return;
    final letters = _flowerLetters[cell.flowerType!]!;
    // Pick a letter based on growth stage
    final stageIndex = cell.stage.index.clamp(0, 3);
    final letter = letters[stageIndex.clamp(0, letters.length - 1)];
    await widget.audioService.playLetter(letter);
  }

  Future<void> _playWind() async {
    if (_isPlayingWind || _sessionExpired) return;
    setState(() {
      _isPlayingWind = true;
    });

    // Collect all non-empty cells in row order
    final cells = <_GardenCell>[];
    for (final row in _grid) {
      for (final cell in row) {
        if (cell.stage != _GrowthStage.empty) {
          cells.add(cell);
        }
      }
    }

    if (cells.isEmpty) {
      setState(() => _isPlayingWind = false);
      return;
    }

    for (int i = 0; i < cells.length; i++) {
      if (!mounted || _sessionExpired) break;
      setState(() {
        cells[i].isPlaying = true;
      });
      await _playFlowerSound(cells[i]);
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        setState(() => cells[i].isPlaying = false);
      }
    }

    if (mounted) {
      setState(() => _isPlayingWind = false);
    }
  }

  void _clearGarden() {
    setState(() {
      for (final row in _grid) {
        for (final cell in row) {
          cell.flowerType = null;
          cell.stage = _GrowthStage.empty;
          cell.growthProgress = 0.0;
          cell.isPlaying = false;
        }
      }
    });
    Haptics.tap();
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final compact = screenW < 400;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(compact),
                _buildToolbar(compact),
                Expanded(child: _buildGarden(compact)),
                _buildFlowerPicker(compact),
              ],
            ),
            if (_showTimeWarning) _buildTimeWarning(compact),
            if (_sessionExpired) _buildSessionExpiredOverlay(compact),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool compact) {
    final isPulsing = _remainingSeconds <= 30 && !_sessionExpired;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primaryText,
            iconSize: compact ? 24 : 28,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _speakLabel('Sound Garden'),
              child: Text(
                'Sound Garden',
                textAlign: TextAlign.center,
                style: AppFonts.fredoka(
                  fontSize: compact ? 18 : 22,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ),
          // Flower count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.emerald.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_florist_rounded,
                    color: AppColors.emerald, size: compact ? 14 : 16),
                const SizedBox(width: 4),
                Text(
                  '$_flowersFullyGrown',
                  style: AppFonts.fredoka(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Timer
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = isPulsing
                  ? 1.0 + _pulseController.value * 0.08
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _timerColor().withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _formatTime(_remainingSeconds),
                style: AppFonts.fredoka(
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: _timerColor(),
                ),
              ),
            ),
          ),
          // Mute
          IconButton(
            onPressed: () {
              setState(() => _isMuted = !_isMuted);
              Haptics.tap();
            },
            icon: Icon(
              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: _isMuted ? AppColors.secondaryText : AppColors.primaryText,
            ),
            iconSize: compact ? 20 : 24,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool compact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Water mode toggle
          _buildToolButton(
            icon: Icons.water_drop_rounded,
            label: 'Water',
            color: const Color(0xFF4DA6FF),
            selected: _isWateringMode,
            onTap: () {
              setState(() => _isWateringMode = !_isWateringMode);
              Haptics.tap();
              _speakLabel('water');
            },
            compact: compact,
          ),
          const SizedBox(width: 8),
          // Wind button (play melody)
          _buildToolButton(
            icon: Icons.air_rounded,
            label: 'Wind',
            color: const Color(0xFF88CCFF),
            selected: _isPlayingWind,
            onTap: _playWind,
            compact: compact,
          ),
          const Spacer(),
          // Clear
          GestureDetector(
            onTap: _clearGarden,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_rounded,
                      color: AppColors.error, size: compact ? 14 : 16),
                  const SizedBox(width: 4),
                  Text(
                    'Clear',
                    style: AppFonts.fredoka(
                      fontSize: compact ? 11 : 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    required bool compact,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 14,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : AppColors.border.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? color : AppColors.secondaryText,
                size: compact ? 14 : 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppFonts.fredoka(
                fontSize: compact ? 11 : 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Garden Grid ────────────────────────────────────────────────────────

  Widget _buildGarden(bool compact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          painter: _GardenBackgroundPainter(
            swayValue: _swayController.value,
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 16),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: kGardenCols,
                crossAxisSpacing: compact ? 6 : 10,
                mainAxisSpacing: compact ? 6 : 10,
              ),
              itemCount: kGardenRows * kGardenCols,
              itemBuilder: (context, index) {
                final row = index ~/ kGardenCols;
                final col = index % kGardenCols;
                return _buildCell(row, col, compact);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int row, int col, bool compact) {
    final cell = _grid[row][col];
    final isEmpty = cell.stage == _GrowthStage.empty;
    final color = isEmpty
        ? AppColors.gardenSoil
        : _flowerColors[cell.flowerType!] ?? Colors.white;

    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      onLongPress: () => _onCellLongPress(row, col),
      child: AnimatedBuilder(
        animation: _swayController,
        builder: (context, child) {
          final sway = cell.stage == _GrowthStage.bloom
              ? sin(_swayController.value * pi * 2 + row * 0.5 + col * 0.7) *
                  0.05
              : 0.0;
          final scale = cell.isPlaying ? 1.15 : 1.0;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..rotateZ(sway)
              ..multiply(Matrix4.diagonal3Values(scale, scale, 1.0)),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isEmpty
                ? AppColors.gardenSoil.withValues(alpha: 0.6)
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            border: Border.all(
              color: isEmpty
                  ? AppColors.border.withValues(alpha: 0.2)
                  : color.withValues(alpha: cell.isPlaying ? 0.8 : 0.4),
              width: cell.isPlaying ? 2.5 : 1.5,
            ),
            boxShadow: cell.isPlaying
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: CustomPaint(
            painter: _FlowerCellPainter(
              cell: cell,
              color: color,
              pulseValue: _pulseController.value,
            ),
          ),
        ),
      ),
    );
  }

  // ── Flower Picker ──────────────────────────────────────────────────────

  Widget _buildFlowerPicker(bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 16,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isWateringMode
                ? 'Tap flowers to water them!'
                : 'Pick a flower to plant!',
            style: AppFonts.fredoka(
              fontSize: compact ? 11 : 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _FlowerType.values.map((type) {
              final selected = _selectedFlower == type && !_isWateringMode;
              final color = _flowerColors[type]!;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFlower = type;
                    _isWateringMode = false;
                  });
                  Haptics.tap();
                  _speakLabel(_flowerNames[type]!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: selected
                      ? (compact ? 50 : 58)
                      : (compact ? 42 : 48),
                  height: selected
                      ? (compact ? 50 : 58)
                      : (compact ? 42 : 48),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? color
                          : color.withValues(alpha: 0.4),
                      width: selected ? 3 : 2,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: CustomPaint(
                    painter: _MiniFlowerPainter(
                      type: type,
                      color: color,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Overlays ────────────────────────────────────────────────────────────

  Widget _buildTimeWarning(bool compact) {
    return Positioned(
      top: compact ? 60 : 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 24,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.starGold.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Text(
            _timeWarningText,
            style: AppFonts.fredoka(
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.w700,
              color: AppColors.starGold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionExpiredOverlay(bool compact) {
    final canAfford =
        widget.progressService.starCoins >= kSoundGardenExtensionCost;
    final hMargin = compact ? 16.0 : 32.0;
    final pad = compact ? 16.0 : 24.0;

    return Positioned.fill(
      child: Container(
        color: AppColors.background.withValues(alpha: 0.9),
        child: Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: hMargin),
            padding: EdgeInsets.all(pad),
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.emerald.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_off_rounded,
                  color: AppColors.starGold,
                  size: compact ? 36 : 48,
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  "Time's Up!",
                  style: AppFonts.fredoka(
                    fontSize: compact ? 22 : 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
                SizedBox(height: compact ? 6 : 8),
                Text(
                  'You grew $_flowersFullyGrown flowers\nin your garden!',
                  textAlign: TextAlign.center,
                  style: AppFonts.fredoka(
                    fontSize: compact ? 12 : 14,
                    color: AppColors.secondaryText,
                  ),
                ),
                SizedBox(height: compact ? 14 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canAfford ? _addMoreTime : null,
                    icon: Icon(Icons.add_rounded, size: compact ? 16 : 20),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add 2 Min  ',
                          style: AppFonts.fredoka(
                            fontSize: compact ? 13 : 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.star_rounded,
                            color: AppColors.starGold,
                            size: compact ? 14 : 16),
                        Text(
                          ' $kSoundGardenExtensionCost',
                          style: AppFonts.fredoka(
                            fontSize: compact ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.starGold,
                          ),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford
                          ? AppColors.emerald
                          : AppColors.surfaceVariant,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: compact ? 8 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                if (!canAfford) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Complete words in Adventure Mode\nto earn more Star Coins!',
                    textAlign: TextAlign.center,
                    style: AppFonts.fredoka(
                      fontSize: compact ? 10 : 12,
                      color: AppColors.starGold.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                SizedBox(height: compact ? 8 : 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryText,
                      side: BorderSide(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                      padding:
                          EdgeInsets.symmetric(vertical: compact ? 8 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: AppFonts.fredoka(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom Painters ─────────────────────────────────────────────────────────

/// Garden background with soil texture and sky gradient.
class _GardenBackgroundPainter extends CustomPainter {
  final double swayValue;

  _GardenBackgroundPainter({required this.swayValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Night sky gradient
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, size.height),
        [
          const Color(0xFF0A0A2E),
          const Color(0xFF1A1A3E),
          const Color(0xFF0D1A0D),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, skyPaint);

    // Stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.3);
    final rng = Random(42); // Fixed seed for consistent stars
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.4;
      final r = 0.5 + rng.nextDouble() * 1.5;
      final alpha = 0.2 + sin(swayValue * pi * 2 + i) * 0.15;
      starPaint.color = Colors.white.withValues(alpha: alpha.clamp(0.05, 0.5));
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Ground
    final groundPaint = Paint()
      ..color = const Color(0xFF1A2E0A);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.85, size.width, size.height * 0.15),
      groundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GardenBackgroundPainter oldDelegate) =>
      oldDelegate.swayValue != swayValue;
}

/// Paints a flower in a garden cell based on its growth stage.
class _FlowerCellPainter extends CustomPainter {
  final _GardenCell cell;
  final Color color;
  final double pulseValue;

  _FlowerCellPainter({
    required this.cell,
    required this.color,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(size.width, size.height) * 0.35;

    switch (cell.stage) {
      case _GrowthStage.empty:
        // Draw a small soil mound
        final soilPaint = Paint()
          ..color = AppColors.gardenSoil.withValues(alpha: 0.4);
        canvas.drawCircle(Offset(cx, cy + r * 0.3), r * 0.3, soilPaint);
        // Plus icon hint
        final plusPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(cx - r * 0.2, cy),
          Offset(cx + r * 0.2, cy),
          plusPaint,
        );
        canvas.drawLine(
          Offset(cx, cy - r * 0.2),
          Offset(cx, cy + r * 0.2),
          plusPaint,
        );
        break;

      case _GrowthStage.seed:
        // Small brown seed
        final seedPaint = Paint()..color = const Color(0xFF8B6914);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, cy + r * 0.2),
            width: r * 0.4,
            height: r * 0.3,
          ),
          seedPaint,
        );
        // Tiny sprout hint
        final sproutPaint = Paint()
          ..color = AppColors.gardenStem.withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cx, cy + r * 0.1),
          Offset(cx, cy - r * 0.1),
          sproutPaint,
        );
        break;

      case _GrowthStage.sprout:
        // Stem
        final stemPaint = Paint()
          ..color = AppColors.gardenStem
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cx, cy + r * 0.6),
          Offset(cx, cy - r * 0.2),
          stemPaint,
        );
        // Two small leaves
        final leafPaint = Paint()..color = AppColors.gardenLeaf;
        final leafPath1 = Path()
          ..moveTo(cx, cy + r * 0.1)
          ..quadraticBezierTo(cx + r * 0.4, cy - r * 0.1, cx, cy - r * 0.1);
        canvas.drawPath(leafPath1, leafPaint);
        final leafPath2 = Path()
          ..moveTo(cx, cy + r * 0.2)
          ..quadraticBezierTo(cx - r * 0.35, cy, cx, cy);
        canvas.drawPath(leafPath2, leafPaint);
        break;

      case _GrowthStage.bloom:
        // Stem
        final stemPaint = Paint()
          ..color = AppColors.gardenStem
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cx, cy + r * 0.8),
          Offset(cx, cy - r * 0.1),
          stemPaint,
        );
        // Leaves
        final leafPaint = Paint()..color = AppColors.gardenLeaf;
        final leafPath1 = Path()
          ..moveTo(cx, cy + r * 0.3)
          ..quadraticBezierTo(
              cx + r * 0.5, cy + r * 0.1, cx + r * 0.1, cy + r * 0.05);
        canvas.drawPath(leafPath1, leafPaint);
        final leafPath2 = Path()
          ..moveTo(cx, cy + r * 0.4)
          ..quadraticBezierTo(
              cx - r * 0.45, cy + r * 0.2, cx - r * 0.1, cy + r * 0.15);
        canvas.drawPath(leafPath2, leafPaint);

        // Flower petals
        const petalCount = 5;
        final petalR = r * (0.3 + pulseValue * 0.03);
        for (int i = 0; i < petalCount; i++) {
          final angle = (i / petalCount) * pi * 2 - pi / 2;
          final px = cx + cos(angle) * petalR * 0.5;
          final py = (cy - r * 0.3) + sin(angle) * petalR * 0.5;
          final petalPaint = Paint()
            ..color = color.withValues(alpha: 0.8);
          canvas.drawCircle(Offset(px, py), petalR * 0.4, petalPaint);
        }
        // Center
        final centerPaint = Paint()
          ..color = const Color(0xFFFFDD44);
        canvas.drawCircle(
          Offset(cx, cy - r * 0.3),
          petalR * 0.22,
          centerPaint,
        );

        // Glow when playing
        if (cell.isPlaying) {
          final glowPaint = Paint()
            ..color = color.withValues(alpha: 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
          canvas.drawCircle(Offset(cx, cy - r * 0.2), r * 0.6, glowPaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerCellPainter oldDelegate) => true;
}

/// Mini flower icon for the picker buttons.
class _MiniFlowerPainter extends CustomPainter {
  final _FlowerType type;
  final Color color;

  _MiniFlowerPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = min(size.width, size.height) * 0.3;

    // Simple flower icon
    const petalCount = 5;
    for (int i = 0; i < petalCount; i++) {
      final angle = (i / petalCount) * pi * 2 - pi / 2;
      final px = cx + cos(angle) * r * 0.45;
      final py = cy + sin(angle) * r * 0.45;
      final petalPaint = Paint()..color = color;
      canvas.drawCircle(Offset(px, py), r * 0.35, petalPaint);
    }
    // Center
    final centerPaint = Paint()..color = const Color(0xFFFFDD44);
    canvas.drawCircle(Offset(cx, cy), r * 0.25, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniFlowerPainter oldDelegate) => false;
}

// ── Icon Painter for Mini Games Hub ─────────────────────────────────────────

/// A garden/flower icon for the Sound Garden game button.
class SoundGardenIconPainter extends CustomPainter {
  const SoundGardenIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.3;

    // Musical note stem
    final stemPaint = Paint()
      ..color = AppColors.gardenStem
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy + r * 0.6),
      Offset(cx, cy - r * 0.5),
      stemPaint,
    );

    // Flower head (as musical note)
    final colors = [
      const Color(0xFFFF4444),
      const Color(0xFFFFDD44),
      const Color(0xFFFF69B4),
      const Color(0xFF6B8CFF),
    ];
    for (int i = 0; i < 4; i++) {
      final angle = (i / 4) * pi * 2 - pi / 2;
      final px = cx + cos(angle) * r * 0.35;
      final py = (cy - r * 0.3) + sin(angle) * r * 0.35;
      final paint = Paint()..color = colors[i];
      canvas.drawCircle(Offset(px, py), r * 0.22, paint);
    }

    // Center
    final centerPaint = Paint()..color = const Color(0xFFFFDD44);
    canvas.drawCircle(Offset(cx, cy - r * 0.3), r * 0.14, centerPaint);

    // Musical notes floating
    final notePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    // Note 1
    canvas.drawCircle(Offset(cx + r * 0.7, cy - r * 0.4), r * 0.12, notePaint);
    canvas.drawLine(
      Offset(cx + r * 0.7 + r * 0.12, cy - r * 0.4),
      Offset(cx + r * 0.7 + r * 0.12, cy - r * 0.8),
      notePaint,
    );
    // Note 2
    canvas.drawCircle(Offset(cx - r * 0.6, cy - r * 0.6), r * 0.1, notePaint);
    canvas.drawLine(
      Offset(cx - r * 0.6 + r * 0.1, cy - r * 0.6),
      Offset(cx - r * 0.6 + r * 0.1, cy - r * 0.9),
      notePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SoundGardenIconPainter oldDelegate) => false;
}
