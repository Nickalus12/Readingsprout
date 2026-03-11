import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A pooled [AudioPlayer] wrapper that tracks its usage state.
class PooledPlayer {
  final AudioPlayer player;
  String? tag;
  DateTime? acquiredAt;
  bool isActive = false;

  PooledPlayer(this.player);
}

/// An object pool of [AudioPlayer] instances that pre-creates players and
/// reuses them to avoid latency from repeated construction/destruction.
///
/// Players are acquired with a [tag] indicating their purpose (e.g. 'word',
/// 'effect'). When no idle player is available, the pool steals the
/// lowest-priority active player (oldest first), never stealing from a
/// higher-priority tag than the requester.
///
/// Priority order (highest first): effect > phrase > word > letterName = letter > music
class AudioPlayerPool {
  final int poolSize;
  final List<PooledPlayer> _players = [];

  /// Priority map — higher value = higher priority.
  static const _priority = {
    'effect': 5,
    'phrase': 4,
    'word': 3,
    'letterName': 2,
    'letter': 2,
    'music': 0,
  };

  AudioPlayerPool({this.poolSize = 12});

  /// Create and initialize all pooled players.
  Future<void> init() async {
    for (int i = 0; i < poolSize; i++) {
      final p = AudioPlayer();
      try {
        await p.setReleaseMode(ReleaseMode.stop);
      } catch (e) {
        debugPrint('AudioPlayerPool setReleaseMode error: $e');
      }
      _players.add(PooledPlayer(p));
    }
  }

  /// Acquire an idle player. If none idle, steal lowest-priority active player.
  /// Never steal from a higher-priority tag than [tag].
  PooledPlayer acquire({String? tag}) {
    // First try an idle player
    for (final p in _players) {
      if (!p.isActive) {
        p.tag = tag;
        p.acquiredAt = DateTime.now();
        p.isActive = true;
        return p;
      }
    }

    // Steal lowest priority, oldest first
    final currentPriority = _priority[tag] ?? 1;
    PooledPlayer? victim;
    for (final p in _players) {
      final pPriority = _priority[p.tag] ?? 1;
      if (pPriority <= currentPriority) {
        if (victim == null ||
            pPriority < (_priority[victim.tag] ?? 1) ||
            (pPriority == (_priority[victim.tag] ?? 1) &&
                p.acquiredAt != null &&
                victim.acquiredAt != null &&
                p.acquiredAt!.isBefore(victim.acquiredAt!))) {
          victim = p;
        }
      }
    }
    if (victim != null) {
      victim.player.stop();
      victim.tag = tag;
      victim.acquiredAt = DateTime.now();
      victim.isActive = true;
      return victim;
    }

    // Absolute fallback: steal oldest regardless of priority
    final sorted = List<PooledPlayer>.from(_players)
      ..sort((a, b) =>
          (a.acquiredAt ?? DateTime(0)).compareTo(b.acquiredAt ?? DateTime(0)));
    final fallback = sorted.first;
    fallback.player.stop();
    fallback.tag = tag;
    fallback.acquiredAt = DateTime.now();
    fallback.isActive = true;
    return fallback;
  }

  /// Release a player back to the idle pool.
  void release(PooledPlayer p) {
    p.isActive = false;
    p.tag = null;
    p.acquiredAt = null;
  }

  /// Stop all active players and release them.
  Future<void> stopAll() async {
    for (final p in _players) {
      if (p.isActive) {
        await p.player.stop();
        release(p);
      }
    }
  }

  /// Stop all players with a specific [tag] and release them.
  Future<void> stopByTag(String tag) async {
    for (final p in _players) {
      if (p.isActive && p.tag == tag) {
        await p.player.stop();
        release(p);
      }
    }
  }

  /// Dispose all players. The pool cannot be used after this.
  Future<void> dispose() async {
    for (final p in _players) {
      await p.player.dispose();
    }
    _players.clear();
  }
}
