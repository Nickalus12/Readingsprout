import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/dolch_words.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';
import '../widgets/floating_hearts_bg.dart';
import 'game_screen.dart';

/// Tier definitions — groups of levels with a label and icon.
class _Tier {
  final String name;
  final IconData icon;
  final int startLevel;
  final int endLevel; // inclusive
  const _Tier(this.name, this.icon, this.startLevel, this.endLevel);
}

const _tiers = [
  _Tier('Pre-Primer', Icons.child_care_rounded, 1, 5),
  _Tier('Primer', Icons.menu_book_rounded, 6, 10),
  _Tier('First Grade', Icons.auto_stories_rounded, 11, 15),
  _Tier('Second Grade', Icons.school_rounded, 16, 19),
  _Tier('Third Grade', Icons.emoji_events_rounded, 20, 22),
];

class LevelSelectScreen extends StatelessWidget {
  final ProgressService progressService;
  final AudioService audioService;
  final String playerName;

  const LevelSelectScreen({
    super.key,
    required this.progressService,
    required this.audioService,
    this.playerName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.background, AppColors.backgroundEnd],
              ),
            ),
          ),

          // ── Floating hearts ──────────────────────────────────
          const Positioned.fill(
            child: FloatingHeartsBackground(cloudZoneHeight: 0.12),
          ),

          // ── Content ──────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Choose a Level',
                        style: GoogleFonts.fredoka(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                          shadows: [
                            Shadow(
                              color: AppColors.electricBlue
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Total stars
                      _TotalStarsBadge(
                        stars: progressService.totalStars,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Scrollable tier list
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _tiers.length,
                    itemBuilder: (context, tierIndex) {
                      final tier = _tiers[tierIndex];
                      return _buildTierSection(
                        context,
                        tier,
                        tierIndex,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierSection(
    BuildContext context,
    _Tier tier,
    int tierIndex,
  ) {
    final levelCount = tier.endLevel - tier.startLevel + 1;

    // Check if entire tier is locked (first level of tier is locked)
    final tierUnlocked = progressService.isLevelUnlocked(tier.startLevel);

    // Count completed levels in tier
    int completedInTier = 0;
    for (int l = tier.startLevel; l <= tier.endLevel; l++) {
      if (progressService.getLevel(l).isComplete) completedInTier++;
    }
    final tierComplete = completedInTier == levelCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tier header ────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 10, left: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tierComplete
                      ? AppColors.starGold.withValues(alpha: 0.15)
                      : tierUnlocked
                          ? AppColors.electricBlue.withValues(alpha: 0.1)
                          : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tierComplete
                        ? AppColors.starGold.withValues(alpha: 0.3)
                        : tierUnlocked
                            ? AppColors.electricBlue.withValues(alpha: 0.2)
                            : AppColors.border,
                  ),
                ),
                child: Icon(
                  tierComplete ? Icons.star_rounded : tier.icon,
                  size: 20,
                  color: tierComplete
                      ? AppColors.starGold
                      : tierUnlocked
                          ? AppColors.electricBlue
                          : AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.name,
                      style: GoogleFonts.fredoka(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: tierUnlocked
                            ? AppColors.primaryText
                            : AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      '$completedInTier / $levelCount levels',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.secondaryText
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Tier progress mini bar
              SizedBox(
                width: 60,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: completedInTier / levelCount,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      tierComplete
                          ? AppColors.starGold
                          : AppColors.electricBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: tierIndex * 80),
              duration: 400.ms,
            ),

        // ── Level cards ────────────────────────────────────
        ...List.generate(levelCount, (i) {
          final level = tier.startLevel + i;
          final lp = progressService.getLevel(level);
          final unlocked = progressService.isLevelUnlocked(level);
          final gradientIndex =
              (level - 1) % AppColors.levelGradients.length;
          final colors = AppColors.levelGradients[gradientIndex];
          final words = DolchWords.wordsForLevel(level);

          return _LevelCard(
            level: level,
            name: DolchWords.levelName(level),
            unlocked: unlocked,
            completionPercent: lp.completionPercent,
            isComplete: lp.isComplete,
            accentColor: colors.first,
            wordsCompleted: lp.wordsCompleted,
            totalWords: words.length,
            wordPreview: words.take(5).map((w) => w.text).join(', '),
            onTap: unlocked
                ? () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => GameScreen(
                          level: level,
                          progressService: progressService,
                          audioService: audioService,
                          playerName: playerName,
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
                        transitionDuration:
                            const Duration(milliseconds: 350),
                      ),
                    )
                : null,
          )
              .animate()
              .fadeIn(
                delay: Duration(
                    milliseconds: tierIndex * 80 + (i + 1) * 40),
                duration: 350.ms,
              )
              .slideX(
                begin: 0.05,
                end: 0,
                delay: Duration(
                    milliseconds: tierIndex * 80 + (i + 1) * 40),
                curve: Curves.easeOutCubic,
              );
        }),
      ],
    );
  }
}

// ── Level Card ──────────────────────────────────────────────────────

class _LevelCard extends StatelessWidget {
  final int level;
  final String name;
  final bool unlocked;
  final double completionPercent;
  final bool isComplete;
  final Color accentColor;
  final int wordsCompleted;
  final int totalWords;
  final String wordPreview;
  final VoidCallback? onTap;

  const _LevelCard({
    required this.level,
    required this.name,
    required this.unlocked,
    required this.completionPercent,
    required this.isComplete,
    required this.accentColor,
    required this.wordsCompleted,
    required this.totalWords,
    required this.wordPreview,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: unlocked ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isComplete
                  ? accentColor.withValues(alpha: 0.06)
                  : AppColors.surface.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isComplete
                    ? AppColors.success.withValues(alpha: 0.3)
                    : unlocked
                        ? accentColor.withValues(alpha: 0.2)
                        : AppColors.border.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: isComplete
                  ? [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.08),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // ── Left: Level number / star ─────────────
                _LevelBadge(
                  level: level,
                  isComplete: isComplete,
                  unlocked: unlocked,
                  accentColor: accentColor,
                  completionPercent: completionPercent,
                ),
                const SizedBox(width: 14),

                // ── Center: Info ──────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: unlocked
                                  ? AppColors.primaryText
                                  : AppColors.secondaryText,
                            ),
                          ),
                          if (isComplete) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Word preview
                      Text(
                        wordPreview,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppColors.secondaryText
                              .withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 4,
                          child: LinearProgressIndicator(
                            value: completionPercent,
                            backgroundColor:
                                AppColors.surface.withValues(alpha: 0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete ? AppColors.success : accentColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── Right: Status ────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$wordsCompleted/$totalWords',
                      style: GoogleFonts.fredoka(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isComplete
                            ? AppColors.success
                            : unlocked
                                ? AppColors.primaryText
                                : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'words',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: AppColors.secondaryText
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                if (unlocked && !isComplete) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: accentColor.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ],
                if (!unlocked) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.lock_rounded,
                    color: AppColors.secondaryText.withValues(alpha: 0.4),
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Level Badge (circular progress + number) ────────────────────────

class _LevelBadge extends StatelessWidget {
  final int level;
  final bool isComplete;
  final bool unlocked;
  final Color accentColor;
  final double completionPercent;

  const _LevelBadge({
    required this.level,
    required this.isComplete,
    required this.unlocked,
    required this.accentColor,
    required this.completionPercent,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isComplete ? AppColors.success : accentColor;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              value: unlocked
                  ? (isComplete ? 1.0 : completionPercent)
                  : 0.0,
              backgroundColor: unlocked
                  ? ringColor.withValues(alpha: 0.12)
                  : AppColors.border.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(ringColor),
            ),
          ),
          if (isComplete)
            Icon(
              Icons.star_rounded,
              color: AppColors.starGold,
              size: 22,
            )
          else
            Text(
              '$level',
              style: GoogleFonts.fredoka(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: unlocked
                    ? AppColors.primaryText
                    : AppColors.secondaryText,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Total Stars Badge ───────────────────────────────────────────────

class _TotalStarsBadge extends StatelessWidget {
  final int stars;
  const _TotalStarsBadge({required this.stars});

  @override
  Widget build(BuildContext context) {
    if (stars == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.starGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.starGold.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded,
              color: AppColors.starGold, size: 16),
          const SizedBox(width: 4),
          Text(
            '$stars',
            style: GoogleFonts.fredoka(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.starGold,
            ),
          ),
        ],
      ),
    );
  }
}
