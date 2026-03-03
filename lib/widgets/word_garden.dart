import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/dolch_words.dart';
import '../models/progress.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';

/// A horizontal scrolling garden where each level is a "plot" with
/// flower positions representing words. Planted flowers sway gently;
/// empty slots show dark soil.
class WordGarden extends StatelessWidget {
  final ProgressService progressService;
  final AudioService audioService;

  const WordGarden({
    super.key,
    required this.progressService,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'My Garden',
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.gardenStem,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: DolchWords.totalLevels,
            itemBuilder: (context, index) {
              final level = index + 1;
              final levelProgress = progressService.getLevel(level);
              final words = DolchWords.wordsForLevel(level);
              final gradientColors = AppColors.levelGradients[
                  index % AppColors.levelGradients.length];

              return _GardenPlot(
                level: level,
                levelProgress: levelProgress,
                words: words.map((w) => w.text).toList(),
                gradientColors: gradientColors,
                audioService: audioService,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single garden plot representing one level.
class _GardenPlot extends StatelessWidget {
  final int level;
  final LevelProgress levelProgress;
  final List<String> words;
  final List<Color> gradientColors;
  final AudioService audioService;

  const _GardenPlot({
    required this.level,
    required this.levelProgress,
    required this.words,
    required this.gradientColors,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = levelProgress.highestCompletedTier >= 1;

    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gardenSoil,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? AppColors.gardenStem.withValues(alpha: 0.5)
              : AppColors.border.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: isComplete
            ? [
                BoxShadow(
                  color: AppColors.gardenStem.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Level label
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  gradientColors[0].withValues(alpha: 0.25),
                  gradientColors[1].withValues(alpha: 0.15),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Text(
              'Level $level',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: gradientColors[0],
              ),
            ),
          ),
          // Flower grid: 2 rows x 5 columns
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: _buildFlowerGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowerGrid() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Row 1: words 0-4
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) => _buildFlowerSlot(i)),
          ),
        ),
        const SizedBox(height: 4),
        // Row 2: words 5-9
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) => _buildFlowerSlot(i + 5)),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowerSlot(int wordIndex) {
    if (wordIndex >= words.length) {
      return const SizedBox(width: 22, height: 22);
    }

    final word = words[wordIndex];
    final stats = levelProgress.wordStats[word];
    final hasAttempted = stats != null && stats.attempts > 0;
    final hasMastered = stats != null && stats.mastered;
    final hasPerfect = stats != null && stats.perfectAttempts > 0;

    if (!hasAttempted) {
      return _EmptySlot();
    }

    // Determine flower tier appearance
    final FlowerTier tier;
    if (hasMastered) {
      tier = FlowerTier.golden;
    } else if (hasPerfect) {
      tier = FlowerTier.bloom;
    } else {
      tier = FlowerTier.bud;
    }

    return _FlowerWidget(
      word: word,
      tier: tier,
      color: gradientColors[0],
      audioService: audioService,
    );
  }
}

/// Empty soil slot with a dim "?" marker.
class _EmptySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.gardenSoil.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Text(
          '?',
          style: GoogleFonts.fredoka(
            fontSize: 10,
            color: AppColors.secondaryText.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

enum FlowerTier { bud, bloom, golden }

/// An animated flower representing a word in the garden.
class _FlowerWidget extends StatefulWidget {
  final String word;
  final FlowerTier tier;
  final Color color;
  final AudioService audioService;

  const _FlowerWidget({
    required this.word,
    required this.tier,
    required this.color,
    required this.audioService,
  });

  @override
  State<_FlowerWidget> createState() => _FlowerWidgetState();
}

class _FlowerWidgetState extends State<_FlowerWidget> {
  bool _showLabel = false;

  void _onTap() async {
    setState(() => _showLabel = true);
    widget.audioService.playWord(widget.word);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _showLabel = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = switch (widget.tier) {
      FlowerTier.bud => 16.0,
      FlowerTier.bloom => 20.0,
      FlowerTier.golden => 22.0,
    };

    final flowerColor = switch (widget.tier) {
      FlowerTier.bud => AppColors.gardenStem,
      FlowerTier.bloom => widget.color,
      FlowerTier.golden => AppColors.starGold,
    };

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        width: 24,
        height: 50,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Stem
            Positioned(
              bottom: 0,
              child: Container(
                width: 2,
                height: 20,
                color: AppColors.gardenStem.withValues(alpha: 0.6),
              ),
            ),
            // Flower head
            Positioned(
              top: 4,
              child: _buildFlowerHead(size, flowerColor),
            ),
            // Word label popup
            if (_showLabel)
              Positioned(
                top: -20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: flowerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    widget.word,
                    style: GoogleFonts.fredoka(
                      fontSize: 10,
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 200.ms)
                    .slideY(begin: 0.3, end: 0, duration: 200.ms),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowerHead(double size, Color color) {
    if (widget.tier == FlowerTier.bud) {
      // Simple green dot
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .slideY(begin: 0, end: -0.05, duration: 2000.ms)
          .then()
          .slideY(begin: -0.05, end: 0, duration: 2000.ms);
    }

    if (widget.tier == FlowerTier.bloom) {
      // Colored circle with small petal indicators
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.4,
            height: size * 0.4,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .rotate(begin: -0.02, end: 0.02, duration: 3000.ms);
    }

    // Golden flower: glowing with animated petals
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.starGold.withValues(alpha: 0.6),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.local_florist, size: 14, color: Colors.white),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .rotate(begin: -0.03, end: 0.03, duration: 2500.ms)
        .scaleXY(begin: 0.95, end: 1.05, duration: 2500.ms);
  }
}
