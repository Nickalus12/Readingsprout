import 'package:flutter/material.dart';

/// Categories for sticker grouping.
enum StickerCategory {
  level,
  milestone,
  streak,
  perfect,
  evolution,
  special,
}

/// Definition of a single sticker that can be earned.
class StickerDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final StickerCategory category;
  final Color color;

  const StickerDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.color,
  });
}

/// All sticker definitions for the app (~41 total).
class StickerDefinitions {
  StickerDefinitions._();

  // ── Level Completion (22 stickers) ────────────────────────────────

  static final List<StickerDefinition> levelStickers = List.generate(
    22,
    (i) => StickerDefinition(
      id: 'level_${i + 1}',
      name: 'Level ${i + 1}',
      description: 'Completed all words in Level ${i + 1}!',
      icon: Icons.local_florist,
      category: StickerCategory.level,
      color: _levelColors[i % _levelColors.length],
    ),
  );

  static const List<Color> _levelColors = [
    Color(0xFFFF9A76), // Peach
    Color(0xFFB794F6), // Lavender
    Color(0xFF7BD4A8), // Mint
    Color(0xFF6BB8F0), // Sky
    Color(0xFFD680A8), // Rose
    Color(0xFFFFBF69), // Honey
    Color(0xFFFF7085), // Coral
    Color(0xFF8FD4B8), // Sage
    Color(0xFFA5B0D9), // Periwinkle
    Color(0xFFFFAFCC), // Blush
    Color(0xFF9B8FE0), // Iris
  ];

  // ── Milestone Stickers (8) ────────────────────────────────────────

  static const List<StickerDefinition> milestoneStickers = [
    StickerDefinition(
      id: 'milestone_1',
      name: 'First Word!',
      description: 'Mastered your very first word!',
      icon: Icons.emoji_events,
      category: StickerCategory.milestone,
      color: Color(0xFFFFD700),
    ),
    StickerDefinition(
      id: 'milestone_10',
      name: '10 Words!',
      description: 'Mastered 10 words -- great start!',
      icon: Icons.star,
      category: StickerCategory.milestone,
      color: Color(0xFF7BD4A8),
    ),
    StickerDefinition(
      id: 'milestone_25',
      name: '25 Words!',
      description: 'Mastered 25 words -- keep it up!',
      icon: Icons.star,
      category: StickerCategory.milestone,
      color: Color(0xFF6BB8F0),
    ),
    StickerDefinition(
      id: 'milestone_50',
      name: '50 Words!',
      description: 'Mastered 50 words -- amazing!',
      icon: Icons.star_half,
      category: StickerCategory.milestone,
      color: Color(0xFFB794F6),
    ),
    StickerDefinition(
      id: 'milestone_100',
      name: '100 Words!',
      description: 'Mastered 100 words -- halfway there!',
      icon: Icons.stars,
      category: StickerCategory.milestone,
      color: Color(0xFFEC4899),
    ),
    StickerDefinition(
      id: 'milestone_150',
      name: '150 Words!',
      description: 'Mastered 150 words -- incredible!',
      icon: Icons.auto_awesome,
      category: StickerCategory.milestone,
      color: Color(0xFFFF8C42),
    ),
    StickerDefinition(
      id: 'milestone_200',
      name: '200 Words!',
      description: 'Mastered 200 words -- almost done!',
      icon: Icons.workspace_premium,
      category: StickerCategory.milestone,
      color: Color(0xFF00D4FF),
    ),
    StickerDefinition(
      id: 'milestone_all',
      name: 'All Words!',
      description: 'Mastered every single word! You are a superstar!',
      icon: Icons.military_tech,
      category: StickerCategory.milestone,
      color: Color(0xFFFFD700),
    ),
  ];

  // ── Streak Stickers (4) ───────────────────────────────────────────

  static const List<StickerDefinition> streakStickers = [
    StickerDefinition(
      id: 'streak_3',
      name: '3 Day Streak',
      description: 'Practiced 3 days in a row!',
      icon: Icons.local_fire_department,
      category: StickerCategory.streak,
      color: Color(0xFFFF8C42),
    ),
    StickerDefinition(
      id: 'streak_7',
      name: '7 Day Streak',
      description: 'A whole week of reading -- wow!',
      icon: Icons.local_fire_department,
      category: StickerCategory.streak,
      color: Color(0xFFFF4444),
    ),
    StickerDefinition(
      id: 'streak_14',
      name: '14 Day Streak',
      description: 'Two weeks of reading every day!',
      icon: Icons.whatshot,
      category: StickerCategory.streak,
      color: Color(0xFF8B5CF6),
    ),
    StickerDefinition(
      id: 'streak_30',
      name: '30 Day Streak',
      description: 'A whole month -- you are unstoppable!',
      icon: Icons.whatshot,
      category: StickerCategory.streak,
      color: Color(0xFFFFD700),
    ),
  ];

  // ── Perfect Sticker (1) ───────────────────────────────────────────

  static const List<StickerDefinition> perfectStickers = [
    StickerDefinition(
      id: 'perfect_level',
      name: 'Perfect Level',
      description: 'Completed a level with zero mistakes!',
      icon: Icons.verified,
      category: StickerCategory.perfect,
      color: Color(0xFF00E68A),
    ),
  ];

  // ── Evolution Stickers (5) ────────────────────────────────────────

  static const List<StickerDefinition> evolutionStickers = [
    StickerDefinition(
      id: 'evo_sprout',
      name: 'Word Sprout',
      description: 'Your bookworm has hatched!',
      icon: Icons.eco,
      category: StickerCategory.evolution,
      color: Color(0xFF10B981),
    ),
    StickerDefinition(
      id: 'evo_explorer',
      name: 'Word Explorer',
      description: 'Your bookworm is exploring! (21+ words)',
      icon: Icons.explore,
      category: StickerCategory.evolution,
      color: Color(0xFF06B6D4),
    ),
    StickerDefinition(
      id: 'evo_wizard',
      name: 'Word Wizard',
      description: 'Your bookworm learned magic! (61+ words)',
      icon: Icons.auto_fix_high,
      category: StickerCategory.evolution,
      color: Color(0xFF8B5CF6),
    ),
    StickerDefinition(
      id: 'evo_champion',
      name: 'Word Champion',
      description: 'Your bookworm became a butterfly! (121+ words)',
      icon: Icons.flutter_dash,
      category: StickerCategory.evolution,
      color: Color(0xFF00D4FF),
    ),
    StickerDefinition(
      id: 'evo_superstar',
      name: 'Reading Superstar',
      description: 'Your bookworm is a superstar! (181+ words)',
      icon: Icons.auto_awesome,
      category: StickerCategory.evolution,
      color: Color(0xFFFFD700),
    ),
  ];

  // ── Special Stickers (1) ──────────────────────────────────────────

  static const List<StickerDefinition> specialStickers = [
    StickerDefinition(
      id: 'speed_reader',
      name: 'Speed Reader',
      description: 'Completed 5 words in under 2 minutes!',
      icon: Icons.bolt,
      category: StickerCategory.special,
      color: Color(0xFFFFBF69),
    ),
  ];

  // ── All stickers combined ─────────────────────────────────────────

  static List<StickerDefinition> get all => [
        ...levelStickers,
        ...milestoneStickers,
        ...streakStickers,
        ...perfectStickers,
        ...evolutionStickers,
        ...specialStickers,
      ];

  /// Look up a sticker definition by its ID.
  static StickerDefinition? byId(String id) {
    for (final sticker in all) {
      if (sticker.id == id) return sticker;
    }
    return null;
  }

  /// Milestone word counts for easy checking.
  static const List<int> milestoneWordCounts = [1, 10, 25, 50, 100, 150, 200, 269];

  /// Returns the milestone sticker ID for a given word count, or null.
  static String? milestoneIdForWordCount(int count) {
    switch (count) {
      case 1:
        return 'milestone_1';
      case 10:
        return 'milestone_10';
      case 25:
        return 'milestone_25';
      case 50:
        return 'milestone_50';
      case 100:
        return 'milestone_100';
      case 150:
        return 'milestone_150';
      case 200:
        return 'milestone_200';
      case 269:
        return 'milestone_all';
      default:
        return null;
    }
  }

  /// Returns the streak sticker ID for a given streak count, or null.
  static String? streakIdForCount(int streak) {
    switch (streak) {
      case 3:
        return 'streak_3';
      case 7:
        return 'streak_7';
      case 14:
        return 'streak_14';
      case 30:
        return 'streak_30';
      default:
        return null;
    }
  }

  /// Returns the evolution sticker ID for a given word count threshold.
  static String? evolutionIdForWordCount(int count) {
    if (count >= 181) return 'evo_superstar';
    if (count >= 121) return 'evo_champion';
    if (count >= 61) return 'evo_wizard';
    if (count >= 21) return 'evo_explorer';
    if (count >= 0) return 'evo_sprout';
    return null;
  }
}
