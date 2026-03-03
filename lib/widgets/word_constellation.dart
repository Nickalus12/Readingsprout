import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/dolch_words.dart';
import '../services/audio_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';

/// A "Words I Know" star map showing mastered words as glowing
/// text chips clustered by level, connected by faint lines.
class WordConstellation extends StatelessWidget {
  final ProgressService progressService;
  final AudioService audioService;

  const WordConstellation({
    super.key,
    required this.progressService,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    // Gather all mastered words with their level info
    final masteredWords = <_MasteredWord>[];

    for (int level = 1; level <= DolchWords.totalLevels; level++) {
      final lp = progressService.getLevel(level);
      final words = DolchWords.wordsForLevel(level);

      for (final word in words) {
        final stats = lp.wordStats[word.text];
        if (stats != null && stats.attempts > 0) {
          if (stats.perfectAttempts > 0) {
            masteredWords.add(_MasteredWord(
              text: word.text,
              level: level,
              perfectAttempts: stats.perfectAttempts,
              isMastered: stats.mastered,
            ));
          }
        }
      }
    }

    const totalWords = 220; // Dolch word count
    final remaining = totalWords - masteredWords.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Words I Know',
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.electricBlue,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF080818),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.electricBlue.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: [
              // Star field with word chips
              SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    // Background stars
                    CustomPaint(
                      size: const Size(double.infinity, 240),
                      painter: _StarFieldPainter(),
                    ),
                    // Word chips by cluster
                    if (masteredWords.isEmpty)
                      Center(
                        child: Text(
                          'Master words to fill your star map!',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: AppColors.secondaryText
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else
                      _ConstellationLayout(
                        masteredWords: masteredWords,
                        audioService: audioService,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Counter
              Text(
                '${masteredWords.length} words mastered'
                '${remaining > 0 ? ' \u00B7 $remaining more to discover!' : ' \u00B7 You know them all!'}',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: AppColors.electricBlue.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MasteredWord {
  final String text;
  final int level;
  final int perfectAttempts;
  final bool isMastered;

  const _MasteredWord({
    required this.text,
    required this.level,
    required this.perfectAttempts,
    required this.isMastered,
  });
}

/// Lays out mastered word chips in clusters by level, wrapping in
/// a scrollable area.
class _ConstellationLayout extends StatelessWidget {
  final List<_MasteredWord> masteredWords;
  final AudioService audioService;

  const _ConstellationLayout({
    required this.masteredWords,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    // Group words by level
    final byLevel = <int, List<_MasteredWord>>{};
    for (final w in masteredWords) {
      byLevel.putIfAbsent(w.level, () => []).add(w);
    }

    final sortedLevels = byLevel.keys.toList()..sort();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final level in sortedLevels)
              _LevelCluster(
                level: level,
                words: byLevel[level]!,
                audioService: audioService,
              ),
          ],
        ),
      ),
    );
  }
}

/// A cluster of word chips for a single level.
class _LevelCluster extends StatelessWidget {
  final int level;
  final List<_MasteredWord> words;
  final AudioService audioService;

  const _LevelCluster({
    required this.level,
    required this.words,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppColors.levelGradients[
        (level - 1) % AppColors.levelGradients.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Level $level',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: gradientColors[0].withValues(alpha: 0.5),
              ),
            ),
          ),
          // Connected word chips
          CustomPaint(
            painter: _ConnectionLinePainter(
              color: gradientColors[0].withValues(alpha: 0.15),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: words.map((w) {
                return _WordChip(
                  word: w,
                  color: gradientColors[0],
                  audioService: audioService,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single word chip in the constellation.
class _WordChip extends StatefulWidget {
  final _MasteredWord word;
  final Color color;
  final AudioService audioService;

  const _WordChip({
    required this.word,
    required this.color,
    required this.audioService,
  });

  @override
  State<_WordChip> createState() => _WordChipState();
}

class _WordChipState extends State<_WordChip> {
  bool _tapped = false;

  void _onTap() async {
    setState(() => _tapped = true);
    widget.audioService.playWord(widget.word.text);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _tapped = false);
  }

  @override
  Widget build(BuildContext context) {
    // Brightness based on mastery level
    final glowAlpha =
        widget.word.isMastered ? 0.6 : 0.3;
    final textAlpha =
        widget.word.isMastered ? 1.0 : 0.7;

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _tapped
              ? widget.color.withValues(alpha: 0.25)
              : widget.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.color.withValues(alpha: _tapped ? 0.7 : 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color
                  .withValues(alpha: _tapped ? glowAlpha : glowAlpha * 0.3),
              blurRadius: _tapped ? 12 : 4,
            ),
          ],
        ),
        child: Text(
          widget.word.text,
          style: GoogleFonts.fredoka(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: widget.color.withValues(alpha: textAlpha),
          ),
        ),
      ),
    );
  }
}

/// Paints tiny white dots as a star field background.
class _StarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42); // Fixed seed for consistent star positions
    final paint = Paint()..color = Colors.white;

    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = rng.nextDouble() * 1.2 + 0.3;
      paint.color =
          Colors.white.withValues(alpha: rng.nextDouble() * 0.3 + 0.1);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Paints faint connecting lines behind the word chips.
class _ConnectionLinePainter extends CustomPainter {
  final Color color;

  _ConnectionLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a subtle horizontal line across the cluster
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectionLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
