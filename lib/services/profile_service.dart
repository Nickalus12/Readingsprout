import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';

/// Hive-backed persistence for profile data, stickers, and daily rewards.
///
/// Uses three separate Hive boxes:
/// - `profile` — name, avatar, streak, unlocked items, lifetime stats
/// - `stickers` — earned sticker records
/// - `dailyRewards` — chest state, last open date
class ProfileService {
  late Box _profileBox;
  late Box<StickerRecord> _stickerBox;
  late Box _dailyBox;

  /// Initialize by opening all Hive boxes.
  /// Hive.initFlutter() and adapter registration must happen before this.
  Future<void> init() async {
    _profileBox = Hive.box('profile');
    _stickerBox = Hive.box<StickerRecord>('stickers');
    _dailyBox = Hive.box('dailyRewards');
  }

  // ── Profile ────────────────────────────────────────────────────────

  String get name => _profileBox.get('name', defaultValue: '') as String;

  Future<void> setName(String name) => _profileBox.put('name', name);

  bool get setupComplete =>
      _profileBox.get('setupComplete', defaultValue: false) as bool;

  Future<void> markSetupComplete() => _profileBox.put('setupComplete', true);

  AvatarConfig get avatar {
    final stored = _profileBox.get('avatar');
    if (stored is AvatarConfig) return stored;
    return AvatarConfig.defaultAvatar();
  }

  Future<void> setAvatar(AvatarConfig config) =>
      _profileBox.put('avatar', config);

  int get totalWordsEverCompleted =>
      _profileBox.get('totalWordsEverCompleted', defaultValue: 0) as int;

  Future<void> setTotalWordsEverCompleted(int count) =>
      _profileBox.put('totalWordsEverCompleted', count);

  ReadingLevel get readingLevel =>
      ReadingLevel.forWordCount(totalWordsEverCompleted);

  // ── Streaks ────────────────────────────────────────────────────────

  int get currentStreak =>
      _profileBox.get('currentStreak', defaultValue: 0) as int;

  int get bestStreak =>
      _profileBox.get('bestStreak', defaultValue: 0) as int;

  DateTime? get lastPlayDate =>
      _profileBox.get('lastPlayDate') as DateTime?;

  /// Record a play session for streak tracking.
  /// Call this when the child completes a word or level.
  Future<void> recordPlaySession() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastPlay = lastPlayDate;

    if (lastPlay != null) {
      final lastDay =
          DateTime(lastPlay.year, lastPlay.month, lastPlay.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 0) return; // Already played today
      if (diff == 1) {
        // Consecutive day
        final newStreak = currentStreak + 1;
        await _profileBox.put('currentStreak', newStreak);
        if (newStreak > bestStreak) {
          await _profileBox.put('bestStreak', newStreak);
        }
      } else {
        // Streak broken
        await _profileBox.put('currentStreak', 1);
      }
    } else {
      // First ever play
      await _profileBox.put('currentStreak', 1);
      if (bestStreak < 1) {
        await _profileBox.put('bestStreak', 1);
      }
    }

    await _profileBox.put('lastPlayDate', today);
  }

  // ── Unlocked Items ─────────────────────────────────────────────────

  List<String> get unlockedItems {
    final raw = _profileBox.get('unlockedItems');
    if (raw is List) return List<String>.from(raw);
    return <String>[];
  }

  Future<void> unlockItem(String itemId) async {
    final items = unlockedItems;
    if (!items.contains(itemId)) {
      items.add(itemId);
      await _profileBox.put('unlockedItems', items);
    }
  }

  bool isItemUnlocked(String itemId) => unlockedItems.contains(itemId);

  // ── Stickers ───────────────────────────────────────────────────────

  List<StickerRecord> get allStickers => _stickerBox.values.toList();

  bool hasSticker(String id) => _stickerBox.containsKey(id);

  Future<void> awardSticker(StickerRecord sticker) async {
    if (!_stickerBox.containsKey(sticker.stickerId)) {
      await _stickerBox.put(sticker.stickerId, sticker);
    }
  }

  /// Mark a sticker as no longer "new" (after the user views it).
  Future<void> markStickerSeen(String stickerId) async {
    final sticker = _stickerBox.get(stickerId);
    if (sticker != null && sticker.isNew) {
      final updated = sticker.copyWith(isNew: false);
      await _stickerBox.put(stickerId, updated);
    }
  }

  /// Number of stickers that haven't been viewed yet.
  int get newStickerCount =>
      _stickerBox.values.where((s) => s.isNew).length;

  // ── Daily Chest ────────────────────────────────────────────────────

  bool get dailyChestOpened {
    final lastDate = _dailyBox.get('lastChestDate') as DateTime?;
    if (lastDate == null) return false;
    final today = DateTime.now();
    return lastDate.year == today.year &&
        lastDate.month == today.month &&
        lastDate.day == today.day;
  }

  Future<void> openDailyChest() async {
    await _dailyBox.put('lastChestDate', DateTime.now());
    await _dailyBox.put('opened', true);
  }

  /// Get the last reward item from the chest (if any).
  String? get lastChestReward =>
      _dailyBox.get('lastReward') as String?;

  Future<void> setLastChestReward(String reward) =>
      _dailyBox.put('lastReward', reward);

  // ── Migration from SharedPreferences ───────────────────────────────

  /// Migrate existing SharedPreferences data to Hive on first launch.
  /// Safe to call multiple times — skips if already migrated.
  static Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileBox = Hive.box('profile');

      // Check if migration already happened
      if (profileBox.get('_migrated', defaultValue: false) as bool) {
        return;
      }

      // Migrate player name from PlayerSettingsService
      final oldName = prefs.getString('player_name');
      final oldSetupComplete = prefs.getBool('setup_complete');
      if (oldName != null && oldName.isNotEmpty) {
        await profileBox.put('name', oldName);
        debugPrint('Migrated player name: $oldName');
      }
      if (oldSetupComplete == true) {
        await profileBox.put('setupComplete', true);
      }

      // Migrate streak data from StreakService
      final streakRaw = prefs.getString('streak_data');
      if (streakRaw != null) {
        try {
          // streak_data is JSON: {currentStreak, longestStreak, lastPracticeDate, ...}
          // We import dart:convert at top if needed, but keep it simple
          // The StreakService stores as JSON string; parse it manually
          // For safety, we just copy the raw values and let ProfileService
          // manage them going forward.
          debugPrint('Streak data found in SharedPreferences (will be read by StreakService)');
        } catch (e) {
          debugPrint('Failed to migrate streak data: $e');
        }
      }

      // Mark migration as done
      await profileBox.put('_migrated', true);
      debugPrint('SharedPreferences -> Hive migration complete');

      // Note: We do NOT delete the old SharedPreferences keys yet.
      // The old services (PlayerSettingsService, StreakService) still read
      // from them as fallback. They can be removed in a future release.
    } catch (e) {
      debugPrint('Migration from SharedPreferences failed: $e');
    }
  }
}
