import 'package:hive/hive.dart';

part 'player_profile.g.dart';

/// The player's profile data, persisted in the 'profile' Hive box.
@HiveType(typeId: 0)
class PlayerProfile extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final AvatarConfig avatar;

  @HiveField(2)
  final int currentStreak;

  @HiveField(3)
  final int bestStreak;

  @HiveField(4)
  final DateTime? lastPlayDate;

  @HiveField(5)
  final List<String> unlockedItems;

  @HiveField(6)
  final List<String> earnedStickers;

  @HiveField(7)
  final int totalWordsEverCompleted;

  PlayerProfile({
    required this.name,
    required this.avatar,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastPlayDate,
    List<String>? unlockedItems,
    List<String>? earnedStickers,
    this.totalWordsEverCompleted = 0,
  })  : unlockedItems = unlockedItems ?? [],
        earnedStickers = earnedStickers ?? [];

  /// Determine reading level from total mastered word count.
  ReadingLevel get readingLevel =>
      ReadingLevel.forWordCount(totalWordsEverCompleted);

  PlayerProfile copyWith({
    String? name,
    AvatarConfig? avatar,
    int? currentStreak,
    int? bestStreak,
    DateTime? lastPlayDate,
    List<String>? unlockedItems,
    List<String>? earnedStickers,
    int? totalWordsEverCompleted,
  }) {
    return PlayerProfile(
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastPlayDate: lastPlayDate ?? this.lastPlayDate,
      unlockedItems: unlockedItems ?? this.unlockedItems,
      earnedStickers: earnedStickers ?? this.earnedStickers,
      totalWordsEverCompleted:
          totalWordsEverCompleted ?? this.totalWordsEverCompleted,
    );
  }
}

/// Avatar customization configuration.
@HiveType(typeId: 1)
class AvatarConfig extends HiveObject {
  @HiveField(0)
  final int faceShape; // 0-2 (circle, rounded square, oval)

  @HiveField(1)
  final int skinTone; // 0-5

  @HiveField(2)
  final int hairStyle; // 0-7

  @HiveField(3)
  final int hairColor; // 0-7 (includes unlockable)

  @HiveField(4)
  final int eyeStyle; // 0-4

  @HiveField(5)
  final int mouthStyle; // 0-3

  @HiveField(6)
  final int accessory; // 0-8 (includes unlockable)

  @HiveField(7)
  final int bgColor; // 0-7

  @HiveField(8)
  final bool hasSparkle; // unlockable effect

  @HiveField(9)
  final bool hasRainbowSparkle;

  @HiveField(10)
  final bool hasGoldenGlow;

  AvatarConfig({
    required this.faceShape,
    required this.skinTone,
    required this.hairStyle,
    required this.hairColor,
    required this.eyeStyle,
    required this.mouthStyle,
    required this.accessory,
    required this.bgColor,
    this.hasSparkle = false,
    this.hasRainbowSparkle = false,
    this.hasGoldenGlow = false,
  });

  /// Default avatar for first-time users.
  factory AvatarConfig.defaultAvatar() => AvatarConfig(
        faceShape: 0,
        skinTone: 2,
        hairStyle: 0,
        hairColor: 1,
        eyeStyle: 0,
        mouthStyle: 0,
        accessory: 0,
        bgColor: 0,
        hasSparkle: false,
        hasRainbowSparkle: false,
        hasGoldenGlow: false,
      );

  AvatarConfig copyWith({
    int? faceShape,
    int? skinTone,
    int? hairStyle,
    int? hairColor,
    int? eyeStyle,
    int? mouthStyle,
    int? accessory,
    int? bgColor,
    bool? hasSparkle,
    bool? hasRainbowSparkle,
    bool? hasGoldenGlow,
  }) {
    return AvatarConfig(
      faceShape: faceShape ?? this.faceShape,
      skinTone: skinTone ?? this.skinTone,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      mouthStyle: mouthStyle ?? this.mouthStyle,
      accessory: accessory ?? this.accessory,
      bgColor: bgColor ?? this.bgColor,
      hasSparkle: hasSparkle ?? this.hasSparkle,
      hasRainbowSparkle: hasRainbowSparkle ?? this.hasRainbowSparkle,
      hasGoldenGlow: hasGoldenGlow ?? this.hasGoldenGlow,
    );
  }
}

/// Record of an earned sticker.
@HiveType(typeId: 2)
class StickerRecord extends HiveObject {
  @HiveField(0)
  final String stickerId;

  @HiveField(1)
  final DateTime dateEarned;

  @HiveField(2)
  final String category; // 'milestone', 'streak', 'perfect', 'evolution', 'level'

  @HiveField(3)
  final bool isNew; // true until viewed on profile screen

  StickerRecord({
    required this.stickerId,
    required this.dateEarned,
    required this.category,
    this.isNew = true,
  });

  StickerRecord copyWith({bool? isNew}) {
    return StickerRecord(
      stickerId: stickerId,
      dateEarned: dateEarned,
      category: category,
      isNew: isNew ?? this.isNew,
    );
  }
}

/// Reading level based on total words mastered.
/// Not stored in Hive — computed at runtime.
enum ReadingLevel {
  wordSprout(0, 20, 'Word Sprout'),
  wordExplorer(21, 60, 'Word Explorer'),
  wordWizard(61, 120, 'Word Wizard'),
  wordChampion(121, 180, 'Word Champion'),
  readingSuperstar(181, 269, 'Reading Superstar');

  final int minWords;
  final int maxWords;
  final String title;

  const ReadingLevel(this.minWords, this.maxWords, this.title);

  /// Determine the reading level for a given total word count.
  static ReadingLevel forWordCount(int count) {
    for (final level in values.reversed) {
      if (count >= level.minWords) return level;
    }
    return wordSprout;
  }

  /// Progress toward the next level as a 0.0-1.0 fraction.
  double progressToNext(int count) {
    if (this == readingSuperstar) return 1.0;
    final range = maxWords - minWords + 1;
    return ((count - minWords) / range).clamp(0.0, 1.0);
  }

  /// The next reading level, or null if already at max.
  ReadingLevel? get next {
    final idx = index + 1;
    return idx < values.length ? values[idx] : null;
  }
}
