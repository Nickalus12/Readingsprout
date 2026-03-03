import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/progress.dart';
import '../data/dolch_words.dart';

class ProgressService {
  static const _key = 'sight_words_progress';
  late SharedPreferences _prefs;
  late Map<int, LevelProgress> _progress;

  Map<int, LevelProgress> get progress => Map.unmodifiable(_progress);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadProgress();
  }

  void _loadProgress() {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _progress = decoded.map((key, value) => MapEntry(
            int.parse(key),
            LevelProgress.fromJson(value as Map<String, dynamic>),
          ));
    } else {
      _progress = {};
    }

    // Ensure level 1 is always unlocked
    _progress.putIfAbsent(
        1, () => const LevelProgress(level: 1, unlocked: true));
    if (!_progress[1]!.unlocked) {
      _progress[1] = _progress[1]!.copyWith(unlocked: true);
    }
  }

  Future<void> _save() async {
    final encoded = jsonEncode(
      _progress.map((key, value) => MapEntry(key.toString(), value.toJson())),
    );
    await _prefs.setString(_key, encoded);
  }

  LevelProgress getLevel(int level) {
    return _progress[level] ??
        LevelProgress(level: level, unlocked: level == 1);
  }

  bool isLevelUnlocked(int level) {
    if (level == 1) return true;
    return _progress[level]?.unlocked ?? false;
  }

  int get highestUnlockedLevel {
    int highest = 1;
    for (final entry in _progress.entries) {
      if (entry.value.unlocked && entry.key > highest) {
        highest = entry.key;
      }
    }
    return highest;
  }

  /// Record that a word was completed in a level.
  /// Returns true if this was the LAST word in the level (level complete!).
  Future<bool> recordWordComplete({
    required int level,
    required String wordText,
    required int mistakes,
  }) async {
    final current = getLevel(level);
    final stats = current.wordStats[wordText] ?? const WordStats();
    final updatedStats = stats.copyWith(
      attempts: stats.attempts + 1,
      perfectAttempts:
          mistakes == 0 ? stats.perfectAttempts + 1 : stats.perfectAttempts,
      totalMistakes: stats.totalMistakes + mistakes,
    );

    final newWordStats = Map<String, WordStats>.from(current.wordStats);
    newWordStats[wordText] = updatedStats;

    final newCompleted = newWordStats.values
        .where((s) => s.attempts > 0)
        .length
        .clamp(0, 10);

    _progress[level] = current.copyWith(
      wordsCompleted: newCompleted,
      wordStats: newWordStats,
      unlocked: true,
    );

    // Unlock next level if this one is complete
    final levelComplete = newCompleted >= 10;
    if (levelComplete && level < DolchWords.totalLevels) {
      final nextLevel = level + 1;
      _progress.putIfAbsent(
        nextLevel,
        () => LevelProgress(level: nextLevel, unlocked: true),
      );
      if (!_progress[nextLevel]!.unlocked) {
        _progress[nextLevel] =
            _progress[nextLevel]!.copyWith(unlocked: true);
      }
    }

    await _save();
    return levelComplete;
  }

  /// Get total stars (mastered words)
  int get totalStars {
    int count = 0;
    for (final lp in _progress.values) {
      count += lp.wordStats.values.where((s) => s.mastered).length;
    }
    return count;
  }

  /// Get total words completed across all levels
  int get totalWordsCompleted {
    int count = 0;
    for (final lp in _progress.values) {
      count += lp.wordStats.values.where((s) => s.attempts > 0).length;
    }
    return count;
  }

  /// Reset all progress
  Future<void> resetAll() async {
    _progress.clear();
    _progress[1] = const LevelProgress(level: 1, unlocked: true);
    await _save();
  }
}
