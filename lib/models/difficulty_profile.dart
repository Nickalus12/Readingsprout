/// Adaptive difficulty profile — tracks a player's rolling performance
/// and adjusts global + per-game difficulty accordingly.
///
/// Persisted as JSON in SharedPreferences, scoped per profile.
class DifficultyProfile {
  double globalDifficulty; // 0.0 (easiest) to 1.0 (hardest)
  Map<String, double> perGameDifficulty; // gameId -> 0.0..1.0
  List<bool> recentCorrectness; // rolling window of last 50 attempts
  List<double> recentResponseMs; // rolling window of last 50 response times
  DateTime lastUpdated;

  // ── Computed properties ──────────────────────────────────────────────

  double get rollingAccuracy => recentCorrectness.isEmpty
      ? 0.5
      : recentCorrectness.where((c) => c).length / recentCorrectness.length;

  double get avgResponseMs => recentResponseMs.isEmpty
      ? 3000
      : recentResponseMs.reduce((a, b) => a + b) / recentResponseMs.length;

  // ── Constructor ──────────────────────────────────────────────────────

  DifficultyProfile({
    this.globalDifficulty = 0.2, // start easy
    Map<String, double>? perGameDifficulty,
    List<bool>? recentCorrectness,
    List<double>? recentResponseMs,
    DateTime? lastUpdated,
  })  : perGameDifficulty = perGameDifficulty ?? {},
        recentCorrectness = recentCorrectness ?? [],
        recentResponseMs = recentResponseMs ?? [],
        lastUpdated = lastUpdated ?? DateTime.now();

  // ── JSON serialization ───────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'globalDifficulty': globalDifficulty,
        'perGameDifficulty': perGameDifficulty,
        'recentCorrectness': recentCorrectness,
        'recentResponseMs': recentResponseMs,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory DifficultyProfile.fromJson(Map<String, dynamic> json) {
    return DifficultyProfile(
      globalDifficulty: (json['globalDifficulty'] as num?)?.toDouble() ?? 0.2,
      perGameDifficulty: (json['perGameDifficulty'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      recentCorrectness: (json['recentCorrectness'] as List<dynamic>?)
              ?.map((v) => v as bool)
              .toList() ??
          [],
      recentResponseMs: (json['recentResponseMs'] as List<dynamic>?)
              ?.map((v) => (v as num).toDouble())
              .toList() ??
          [],
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
