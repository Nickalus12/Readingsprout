import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/sticker_definitions.dart';
import '../models/player_profile.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// A horizontally scrollable sticker book that shows earned and
/// unearned stickers. Earned stickers glow and are tappable;
/// unearned ones are dark silhouettes.
class StickerBook extends StatelessWidget {
  final ProfileService profileService;

  const StickerBook({
    super.key,
    required this.profileService,
  });

  @override
  Widget build(BuildContext context) {
    final earnedStickers = profileService.allStickers;
    final earnedIds = {for (final s in earnedStickers) s.stickerId};

    // Find the most recent sticker for "NEW!" badge
    StickerRecord? mostRecent;
    for (final s in earnedStickers) {
      if (s.isNew) {
        if (mostRecent == null ||
            s.dateEarned.isAfter(mostRecent.dateEarned)) {
          mostRecent = s;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Text(
                'Sticker Book',
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.starGold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${earnedIds.length}/${StickerDefinitions.all.length}',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.3),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: StickerDefinitions.all.length,
            itemBuilder: (context, index) {
              final def = StickerDefinitions.all[index];
              final isEarned = earnedIds.contains(def.id);
              final isNew = mostRecent?.stickerId == def.id;
              final record = isEarned
                  ? earnedStickers
                      .firstWhere((s) => s.stickerId == def.id)
                  : null;

              return _StickerTile(
                definition: def,
                isEarned: isEarned,
                isNew: isNew,
                record: record,
                profileService: profileService,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single sticker tile in the book.
class _StickerTile extends StatefulWidget {
  final StickerDefinition definition;
  final bool isEarned;
  final bool isNew;
  final StickerRecord? record;
  final ProfileService profileService;

  const _StickerTile({
    required this.definition,
    required this.isEarned,
    required this.isNew,
    this.record,
    required this.profileService,
  });

  @override
  State<_StickerTile> createState() => _StickerTileState();
}

class _StickerTileState extends State<_StickerTile>
    with SingleTickerProviderStateMixin {
  bool _showDetails = false;

  void _onTap() async {
    if (!widget.isEarned) return;

    setState(() => _showDetails = true);

    // Mark as seen
    if (widget.record != null && widget.record!.isNew) {
      widget.profileService.markStickerSeen(widget.definition.id);
    }

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _showDetails = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Sticker body
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.isEarned
                        ? widget.definition.color.withValues(alpha: 0.2)
                        : AppColors.surface.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isEarned
                          ? widget.definition.color.withValues(alpha: 0.6)
                          : AppColors.border.withValues(alpha: 0.2),
                      width: 2,
                    ),
                    boxShadow: widget.isEarned
                        ? [
                            BoxShadow(
                              color: widget.definition.color
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.definition.icon,
                    size: 24,
                    color: widget.isEarned
                        ? widget.definition.color
                        : AppColors.secondaryText.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 4),
                // Name
                Text(
                  widget.isEarned ? widget.definition.name : '???',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: widget.isEarned
                        ? AppColors.primaryText.withValues(alpha: 0.8)
                        : AppColors.secondaryText.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),

            // "NEW!" badge
            if (widget.isNew)
              Positioned(
                top: -4,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'NEW!',
                    style: GoogleFonts.fredoka(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 0.9, end: 1.1, duration: 800.ms),
              ),

            // Details popup on tap
            if (_showDetails && widget.record != null)
              Positioned(
                bottom: 90,
                left: -20,
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          widget.definition.color.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.definition.name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.fredoka(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.definition.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.definition.description,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 9,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(widget.record!.dateEarned),
                        style: GoogleFonts.nunito(
                          fontSize: 8,
                          color:
                              AppColors.secondaryText.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 200.ms)
                    .scaleXY(begin: 0.8, end: 1, duration: 200.ms),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
