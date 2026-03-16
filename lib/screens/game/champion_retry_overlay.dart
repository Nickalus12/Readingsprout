import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Overlay shown when a Champion tier word is completed with too many mistakes.
///
/// Offers the child a choice to retry just this word or skip to the next one,
/// instead of forcing a full tier restart.
class ChampionRetryOverlay extends StatelessWidget {
  final String word;
  final VoidCallback onRetry;
  final VoidCallback onSkip;

  const ChampionRetryOverlay({
    super.key,
    required this.word,
    required this.onRetry,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A1A).withValues(alpha: 0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encouraging icon
              Icon(
                Icons.emoji_events_rounded,
                size: 56,
                color: AppColors.starGold.withValues(alpha: 0.7),
              )
                  .animate()
                  .scaleXY(
                    begin: 0.0,
                    end: 1.0,
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 16),

              // "Almost!" title
              Text(
                'Almost!',
                style: AppFonts.fredoka(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.electricBlue,
                  shadows: [
                    Shadow(
                      color: AppColors.electricBlue.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 300.ms)
                  .slideY(begin: 0.2, end: 0, delay: 200.ms, duration: 300.ms),

              const SizedBox(height: 8),

              // Word display
              Text(
                '"$word"',
                style: AppFonts.fredoka(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 300.ms),

              const SizedBox(height: 8),

              // Explanation
              Text(
                'Try spelling it with fewer mistakes!',
                textAlign: TextAlign.center,
                style: AppFonts.nunito(
                  fontSize: 15,
                  color: AppColors.secondaryText.withValues(alpha: 0.8),
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 300.ms),

              const SizedBox(height: 28),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Skip / Continue button
                  GestureDetector(
                    onTap: onSkip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.secondaryText.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.skip_next_rounded,
                            size: 20,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Skip',
                            style: AppFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 300.ms)
                      .slideY(
                          begin: 0.2,
                          end: 0,
                          delay: 500.ms,
                          duration: 300.ms),

                  const SizedBox(width: 16),

                  // Try Again button (prominent)
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.electricBlue.withValues(alpha: 0.2),
                            AppColors.violet.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.electricBlue.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.electricBlue.withValues(alpha: 0.15),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: AppColors.electricBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Try Again',
                            style: AppFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.electricBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 300.ms)
                      .slideY(
                          begin: 0.2,
                          end: 0,
                          delay: 600.ms,
                          duration: 300.ms),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
