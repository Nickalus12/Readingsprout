import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/difficulty_profile.dart';
import '../models/game_difficulty_params.dart';

/// Tracks player performance and adjusts difficulty dynamically.
///
/// Uses an asymmetric exponential moving average: difficulty increases faster
/// when the player is doing well and decreases slower when struggling,
/// preventing frustration while still providing challenge.
class AdaptiveDifficultyService {
  late SharedPreferences _prefs;
  String _profileId = 'default';
  late DifficultyProfile _profile;

  String get _key => 'adaptive_difficulty_$_profileId';

  // ── Public getters ──────────────────────────────────────────────────

  double get globalDifficulty => _profile.globalDifficulty;
  double get rollingAccuracy => _profile.rollingAccuracy;

  // ── Initialization ──────────────────────────────────────────────────

  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _loadProfile();
  }

  void switchProfile(String profileId) {
    _profileId = profileId;
    _loadProfile();
  }

  void _loadProfile() {
    final json = _prefs.getString(_key);
    if (json != null) {
      try {
        _profile =
            DifficultyProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Failed to load difficulty profile: $e');
        _profile = DifficultyProfile();
      }
    } else {
      _profile = DifficultyProfile();
    }
  }

  Future<void> _save() async {
    _profile.lastUpdated = DateTime.now();
    await _prefs.setString(_key, jsonEncode(_profile.toJson()));
  }

  // ── Event recording ─────────────────────────────────────────────────

  /// Record a gameplay event (correct/wrong + optional response time).
  ///
  /// Call this after every word attempt in adventure mode or mini games.
  void recordEvent({required bool correct, double? responseMs, String? gameId}) {
    // Rolling window of 50
    _profile.recentCorrectness.add(correct);
    if (_profile.recentCorrectness.length > 50) {
      _profile.recentCorrectness.removeAt(0);
    }

    if (responseMs != null) {
      _profile.recentResponseMs.add(responseMs);
      if (_profile.recentResponseMs.length > 50) {
        _profile.recentResponseMs.removeAt(0);
      }
    }

    _updateDifficulty(gameId: gameId);
    _save();
  }

  // ── Difficulty update logic ─────────────────────────────────────────

  void _updateDifficulty({String? gameId}) {
    final accuracy = _profile.rollingAccuracy;
    // Normalize response time: 1000ms = fast (1.0), 5000ms = slow (0.0)
    final speedScore =
        (1.0 - ((_profile.avgResponseMs - 1000) / 4000)).clamp(0.0, 1.0);

    final instantPerformance =
        accuracy * 0.5 + speedScore * 0.3 + (accuracy > 0.8 ? 0.2 : 0.0);

    // Asymmetric EMA: faster up, slower down
    final alpha =
        instantPerformance > _profile.globalDifficulty ? 0.08 : 0.03;
    _profile.globalDifficulty =
        (_profile.globalDifficulty * (1 - alpha) + instantPerformance * alpha)
            .clamp(0.0, 1.0);

    // Per-game difficulty anchored to global +/- 0.15
    if (gameId != null) {
      final gameDiff =
          _profile.perGameDifficulty[gameId] ?? _profile.globalDifficulty;
      final gameAlpha = instantPerformance > gameDiff ? 0.1 : 0.04;
      final newGameDiff =
          (gameDiff * (1 - gameAlpha) + instantPerformance * gameAlpha)
              .clamp(0.0, 1.0);
      _profile.perGameDifficulty[gameId] = newGameDiff
          .clamp(
            _profile.globalDifficulty - 0.15,
            _profile.globalDifficulty + 0.15,
          )
          .clamp(0.0, 1.0);
    }
  }

  // ── Query methods ───────────────────────────────────────────────────

  /// Get difficulty params for a specific mini game.
  GameDifficultyParams getParamsForGame(String gameId) {
    final diff =
        _profile.perGameDifficulty[gameId] ?? _profile.globalDifficulty;
    return GameDifficultyParams.forGame(gameId, diff);
  }

  /// Get the appropriate maximum word level to draw words from,
  /// based on current difficulty and the player's progress.
  int getMaxWordLevel(int highestUnlockedLevel) {
    return (_profile.globalDifficulty * highestUnlockedLevel)
        .ceil()
        .clamp(1, highestUnlockedLevel);
  }
}
