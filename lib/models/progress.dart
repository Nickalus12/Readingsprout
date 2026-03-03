class LevelProgress {
  final int level;
  final int wordsCompleted; // out of 10
  final int bestStreak;
  final bool unlocked;
  final Map<String, WordStats> wordStats; // word text -> stats

  const LevelProgress({
    required this.level,
    this.wordsCompleted = 0,
    this.bestStreak = 0,
    this.unlocked = false,
    this.wordStats = const {},
  });

  bool get isComplete => wordsCompleted >= 10;

  double get completionPercent => (wordsCompleted / 10).clamp(0.0, 1.0);

  LevelProgress copyWith({
    int? wordsCompleted,
    int? bestStreak,
    bool? unlocked,
    Map<String, WordStats>? wordStats,
  }) {
    return LevelProgress(
      level: level,
      wordsCompleted: wordsCompleted ?? this.wordsCompleted,
      bestStreak: bestStreak ?? this.bestStreak,
      unlocked: unlocked ?? this.unlocked,
      wordStats: wordStats ?? this.wordStats,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'wordsCompleted': wordsCompleted,
        'bestStreak': bestStreak,
        'unlocked': unlocked,
        'wordStats':
            wordStats.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    final statsMap = (json['wordStats'] as Map<String, dynamic>?)?.map(
          (k, v) =>
              MapEntry(k, WordStats.fromJson(v as Map<String, dynamic>)),
        ) ??
        {};
    return LevelProgress(
      level: json['level'] as int,
      wordsCompleted: json['wordsCompleted'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      unlocked: json['unlocked'] as bool? ?? false,
      wordStats: statsMap,
    );
  }
}

class WordStats {
  final int attempts;
  final int perfectAttempts; // No mistakes
  final int totalMistakes;

  const WordStats({
    this.attempts = 0,
    this.perfectAttempts = 0,
    this.totalMistakes = 0,
  });

  bool get mastered => perfectAttempts >= 3; // Mastered after 3 perfect runs

  WordStats copyWith({
    int? attempts,
    int? perfectAttempts,
    int? totalMistakes,
  }) {
    return WordStats(
      attempts: attempts ?? this.attempts,
      perfectAttempts: perfectAttempts ?? this.perfectAttempts,
      totalMistakes: totalMistakes ?? this.totalMistakes,
    );
  }

  Map<String, dynamic> toJson() => {
        'attempts': attempts,
        'perfectAttempts': perfectAttempts,
        'totalMistakes': totalMistakes,
      };

  factory WordStats.fromJson(Map<String, dynamic> json) => WordStats(
        attempts: json['attempts'] as int? ?? 0,
        perfectAttempts: json['perfectAttempts'] as int? ?? 0,
        totalMistakes: json['totalMistakes'] as int? ?? 0,
      );
}
