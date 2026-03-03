import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/player_profile.dart';
import '../services/audio_service.dart';
import '../services/profile_service.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/bookworm_companion.dart';
import '../widgets/daily_treasure.dart';
import '../widgets/evolution_path.dart';
import '../widgets/sticker_book.dart';
import '../widgets/word_constellation.dart';
import '../widgets/word_garden.dart';
import 'avatar_editor_screen.dart';

/// Main profile screen ("My Garden") showing avatar, stats,
/// companion, treasure, garden, stickers, and word constellation.
class ProfileScreen extends StatefulWidget {
  final ProfileService profileService;
  final ProgressService progressService;
  final AudioService audioService;
  final String playerName;

  const ProfileScreen({
    super.key,
    required this.profileService,
    required this.progressService,
    required this.audioService,
    required this.playerName,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late AvatarConfig _avatar;

  @override
  void initState() {
    super.initState();
    _avatar = widget.profileService.avatar;
  }

  int get _wordCount => widget.profileService.totalWordsEverCompleted;
  int get _masteredCount => widget.progressService.totalStars;
  int get _streak => widget.profileService.currentStreak;

  ReadingLevel get _readingLevel => widget.profileService.readingLevel;

  void _openAvatarEditor() async {
    final result = await Navigator.push<AvatarConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarEditorScreen(
          profileService: widget.profileService,
          wordsMastered: _wordCount,
          streakDays: _streak,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _avatar = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.background, AppColors.backgroundEnd],
              ),
            ),
          ),

          // Firefly particles
          const Positioned.fill(child: _FireflyBackground()),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildHeroSection(),
                        const SizedBox(height: 24),
                        _buildCompanionCard(),
                        const SizedBox(height: 20),
                        DailyTreasure(
                          profileService: widget.profileService,
                          wordsPlayedToday: 0,
                          currentStreak: _streak,
                        ),
                        const SizedBox(height: 20),
                        WordGarden(
                          progressService: widget.progressService,
                          audioService: widget.audioService,
                        ),
                        const SizedBox(height: 20),
                        StickerBook(
                          profileService: widget.profileService,
                        ),
                        const SizedBox(height: 20),
                        WordConstellation(
                          progressService: widget.progressService,
                          audioService: widget.audioService,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.primaryText,
            iconSize: 28,
          ),
          Expanded(
            child: Text(
              'My Garden',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // Settings placeholder
            },
            icon: const Icon(Icons.settings_rounded),
            color: AppColors.secondaryText,
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  // ── Hero Section ───────────────────────────────────────────────────

  Widget _buildHeroSection() {
    final level = _readingLevel;

    return Column(
      children: [
        // Reading level title with gold glow
        GestureDetector(
          onTap: () => EvolutionPath.showAsBottomSheet(
            context,
            wordCount: _wordCount,
          ),
          child: Text(
            level.title,
            style: GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.starGold,
              shadows: [
                Shadow(
                  color: AppColors.starGold.withValues(alpha: 0.6),
                  blurRadius: 12,
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .then()
              .shimmer(
                duration: 2500.ms,
                color: AppColors.starGold.withValues(alpha: 0.3),
              ),
        ),

        const SizedBox(height: 12),

        // Avatar with glow ring — long press opens editor
        GestureDetector(
          onTap: _openAvatarEditor,
          onLongPress: _openAvatarEditor,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.violet.withValues(alpha: 0.6),
                  width: 3,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: AvatarWidget(config: _avatar, size: 80),
            ),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              ),
        ),

        const SizedBox(height: 8),

        // Bookworm companion below avatar
        BookwormCompanion(
          wordCount: _wordCount,
          size: 64,
          onTap: () {},
        ),

        const SizedBox(height: 8),

        // Player name
        if (widget.playerName.isNotEmpty)
          Text(
            widget.playerName,
            style: GoogleFonts.fredoka(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: AppColors.magenta.withValues(alpha: 0.6),
                  blurRadius: 20,
                ),
                Shadow(
                  color: AppColors.violet.withValues(alpha: 0.4),
                  blurRadius: 40,
                ),
              ],
            ),
          ).animate().fadeIn(duration: 600.ms),

        const SizedBox(height: 16),

        // Stats row: 3 glass-morphism cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GlassStatCard(
                icon: Icons.local_florist_rounded,
                iconColor: AppColors.emerald,
                value: '$_wordCount',
                label: 'Flowers',
              ),
              const SizedBox(width: 12),
              _GlassStatCard(
                icon: Icons.star_rounded,
                iconColor: AppColors.starGold,
                value: '$_masteredCount',
                label: 'Stars',
              ),
              const SizedBox(width: 12),
              _GlassStatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.flameOrange,
                value: '$_streak',
                label: 'Streak',
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms),
        ),
      ],
    );
  }

  // ── Companion Card ─────────────────────────────────────────────────

  Widget _buildCompanionCard() {
    final stage = BookwormStage.fromWordCount(_wordCount);
    final level = _readingLevel;
    final progress = level.progressToNext(_wordCount);
    final nextLevel = level.next;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stage.primaryColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: stage.primaryColor.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          BookwormCompanion(
            wordCount: _wordCount,
            size: 72,
            onTap: () {},
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.title,
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: stage.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 8,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.border.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  stage.primaryColor,
                                  stage.primaryColor.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: stage.primaryColor
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nextLevel != null
                      ? '${(_wordCount - level.minWords)} / ${level.maxWords - level.minWords + 1} to ${nextLevel.title}'
                      : 'Max level reached!',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => EvolutionPath.showAsBottomSheet(
                    context,
                    wordCount: _wordCount,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: stage.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: stage.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.route_rounded,
                          size: 14,
                          color: stage.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'See Evolution Path',
                          style: GoogleFonts.fredoka(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: stage.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(
          begin: 0.1,
          end: 0,
          duration: 500.ms,
          curve: Curves.easeOut,
        );
  }
}

// ── Glass-morphism stat card ───────────────────────────────────────────

class _GlassStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _GlassStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Firefly background (adapted from FloatingHeartsBackground) ─────────

class _FireflyBackground extends StatefulWidget {
  const _FireflyBackground();

  @override
  State<_FireflyBackground> createState() => _FireflyBackgroundState();
}

class _FireflyBackgroundState extends State<_FireflyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Firefly> _fireflies;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    final rng = Random(42);
    _fireflies = List.generate(20, (_) => _Firefly(rng));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _FireflyPainter(
            fireflies: _fireflies,
            time: _controller.value,
          ),
        );
      },
    );
  }
}

class _Firefly {
  final double x;
  final double y;
  final double speed;
  final double phase;
  final double size;

  _Firefly(Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        speed = 0.3 + rng.nextDouble() * 0.7,
        phase = rng.nextDouble() * 2 * pi,
        size = 1.5 + rng.nextDouble() * 2.0;
}

class _FireflyPainter extends CustomPainter {
  final List<_Firefly> fireflies;
  final double time;

  _FireflyPainter({required this.fireflies, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fly in fireflies) {
      final t = time * fly.speed + fly.phase;
      final x = (fly.x + sin(t * 2 * pi) * 0.03) * size.width;
      final y = (fly.y + cos(t * 2 * pi * 0.7) * 0.02) * size.height;
      final alpha = (0.3 + sin(t * 2 * pi * 1.5) * 0.3).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = AppColors.starGold.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fly.size * 2);

      canvas.drawCircle(Offset(x, y), fly.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireflyPainter oldDelegate) => true;
}
