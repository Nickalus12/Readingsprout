import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../data/music_layers.dart';

/// Manages layered, adaptive background music for Reading Sprout.
///
/// The music system plays zone-themed ambient soundscapes with multiple
/// layers (pad, melody, percussion) that fade in/out based on gameplay
/// intensity. All players are owned by this service — it does NOT share
/// the [AudioPlayerPool] used by [AudioService].
///
/// Key design goals:
/// - **Subtle**: Master volume is low (0.15). This is ambient background
///   music for children, never overpowering speech or sound effects.
/// - **Adaptive**: Layers crossfade based on a 0.0-1.0 intensity value
///   driven by gameplay events (correct answers bump it up, wrong answers
///   dip it down, streaks push it higher).
/// - **Smooth**: All volume transitions are gradual (2-3 second fades)
///   to avoid jarring changes.
/// - **Independent**: Creates its own [AudioPlayer] instances so it can
///   be used alongside the main audio pool without conflicts.
class AdaptiveMusicService {
  // ── Configuration ──────────────────────────────────────────────────

  /// Master volume multiplier. Keeps music ambient and unobtrusive.
  static const double _masterVolume = 0.15;

  /// How long fade-in/out transitions take (in milliseconds).
  static const int _fadeDurationMs = 2500;

  /// Timer interval for volume fade steps.
  static const int _fadeStepMs = 50;

  /// How much a correct answer bumps intensity.
  static const double _correctBump = 0.08;

  /// How much a wrong answer dips intensity.
  static const double _wrongDip = 0.12;

  /// How much a streak milestone bumps intensity.
  static const double _streakBump = 0.15;

  /// Intensity decay per second when no events occur.
  static const double _decayPerSecond = 0.02;

  // ── State ──────────────────────────────────────────────────────────

  /// Active audio players keyed by layer instrument name.
  final Map<String, AudioPlayer> _layerPlayers = {};

  /// Target volumes for each layer (pre-master-volume scaling).
  final Map<String, double> _layerTargetVolumes = {};

  /// Current volumes for each layer (smoothly interpolated).
  final Map<String, double> _layerCurrentVolumes = {};

  /// Dedicated player for stingers (one-shots).
  AudioPlayer? _stingerPlayer;

  /// The currently active zone key (e.g. 'woods', 'shore').
  String? _currentZone;

  /// Current intensity level (0.0 = calm, 1.0 = max energy).
  double _intensity = 0.0;

  /// Whether music is actively playing.
  bool _isPlaying = false;

  /// Whether music is enabled by the user.
  bool _enabled = true;

  /// Timer for smooth volume fading.
  Timer? _fadeTimer;

  /// Timer for intensity decay over time.
  Timer? _decayTimer;

  bool _disposed = false;

  // ── Public API ─────────────────────────────────────────────────────

  /// Whether the music system is currently playing.
  bool get isPlaying => _isPlaying;

  /// Whether music is enabled.
  bool get isEnabled => _enabled;

  /// Current intensity value (0.0-1.0).
  double get intensity => _intensity;

  /// Current zone key, if any.
  String? get currentZone => _currentZone;

  /// Enable or disable music globally.
  set enabled(bool value) {
    _enabled = value;
    if (!value && _isPlaying) {
      stopMusic();
    }
  }

  /// Initialize the service. Call once at app startup.
  Future<void> init() async {
    _stingerPlayer = AudioPlayer();
    await _stingerPlayer!.setReleaseMode(ReleaseMode.stop);
    debugPrint('AdaptiveMusicService initialized');
  }

  /// Start playing zone-themed music.
  ///
  /// [zoneKey] is one of: 'woods', 'shore', 'peaks', 'sky', 'crown'.
  /// If music is already playing for this zone, this is a no-op.
  /// If a different zone is playing, it crossfades to the new zone.
  Future<void> startZoneMusic(String zoneKey) async {
    if (_disposed || !_enabled) return;

    // Already playing this zone — just resume if paused
    if (_currentZone == zoneKey && _isPlaying) return;

    // Different zone or first start — stop current and start new
    if (_currentZone != null && _currentZone != zoneKey) {
      await _stopLayerPlayers();
    }

    final zoneMusic = MusicLayers.zones[zoneKey];
    if (zoneMusic == null) {
      debugPrint('AdaptiveMusic: Unknown zone "$zoneKey"');
      return;
    }

    _currentZone = zoneKey;
    _intensity = 0.0;

    // Create a player for each layer
    for (final layer in zoneMusic.layers) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.0); // Start silent, fade in
      _layerPlayers[layer.instrument] = player;
      _layerCurrentVolumes[layer.instrument] = 0.0;
      _layerTargetVolumes[layer.instrument] = 0.0;

      try {
        await player.play(AssetSource(layer.assetPath));
      } catch (e) {
        debugPrint('AdaptiveMusic: Failed to play ${layer.instrument}: $e');
      }
    }

    _isPlaying = true;
    _updateTargetVolumes();
    _startFadeTimer();
    _startDecayTimer();

    debugPrint('AdaptiveMusic: Started zone "$zoneKey"');
  }

  /// Stop all music with a fade-out.
  Future<void> stopMusic() async {
    if (!_isPlaying) return;

    // Set all targets to 0, let fade handle it
    for (final key in _layerTargetVolumes.keys) {
      _layerTargetVolumes[key] = 0.0;
    }

    // Wait for fade to mostly complete, then clean up
    await Future<void>.delayed(const Duration(milliseconds: _fadeDurationMs));
    await _stopLayerPlayers();

    _isPlaying = false;
    _currentZone = null;
    _intensity = 0.0;
    _stopFadeTimer();
    _stopDecayTimer();

    debugPrint('AdaptiveMusic: Stopped');
  }

  /// Update the intensity based on gameplay difficulty.
  ///
  /// [difficulty] is a normalized 0.0-1.0 value. Higher values
  /// activate more layers and increase tempo slightly.
  void updateIntensity(double difficulty) {
    _intensity = difficulty.clamp(0.0, 1.0);
    _updateTargetVolumes();
  }

  /// Play a short stinger sound effect.
  ///
  /// [name] is one of: 'correct', 'streak', 'combo'.
  Future<void> playStinger(String name) async {
    if (_disposed || !_enabled) return;

    final stinger = MusicLayers.stingers[name];
    if (stinger == null) return;

    try {
      final player = _stingerPlayer;
      if (player == null) return;
      await player.setVolume(stinger.baseVolume * _masterVolume);
      await player.play(AssetSource(stinger.assetPath));
    } catch (e) {
      debugPrint('AdaptiveMusic: Stinger error ($name): $e');
    }
  }

  /// Called when the player answers correctly.
  void onCorrectAnswer() {
    _intensity = (_intensity + _correctBump).clamp(0.0, 1.0);
    _updateTargetVolumes();
    // Play the correct chime stinger
    playStinger('correct');
  }

  /// Called when the player answers incorrectly.
  void onWrongAnswer() {
    _intensity = (_intensity - _wrongDip).clamp(0.0, 1.0);
    _updateTargetVolumes();
  }

  /// Called when the player reaches a streak milestone.
  void onStreakReached(int streak) {
    _intensity = (_intensity + _streakBump).clamp(0.0, 1.0);
    _updateTargetVolumes();
    // Play streak chime for milestones
    if (streak >= 5) {
      playStinger('streak');
    } else if (streak >= 3) {
      playStinger('combo');
    }
  }

  /// Called when a streak is broken.
  void onStreakBroken() {
    _intensity = (_intensity * 0.5).clamp(0.0, 1.0);
    _updateTargetVolumes();
  }

  /// Pause music playback (e.g. when app goes to background).
  Future<void> pause() async {
    if (!_isPlaying) return;
    for (final player in _layerPlayers.values) {
      try {
        await player.pause();
      } catch (_) {}
    }
    _stopFadeTimer();
    _stopDecayTimer();
  }

  /// Resume music playback after pause.
  Future<void> resume() async {
    if (!_isPlaying || !_enabled) return;
    for (final player in _layerPlayers.values) {
      try {
        await player.resume();
      } catch (_) {}
    }
    _startFadeTimer();
    _startDecayTimer();
  }

  /// Dispose all resources. Call when the service is no longer needed.
  Future<void> dispose() async {
    _disposed = true;
    _stopFadeTimer();
    _stopDecayTimer();
    await _stopLayerPlayers();
    try {
      await _stingerPlayer?.dispose();
    } catch (_) {}
    _stingerPlayer = null;
    debugPrint('AdaptiveMusicService disposed');
  }

  // ── Internal helpers ───────────────────────────────────────────────

  /// Recalculate target volumes for all layers based on current intensity.
  void _updateTargetVolumes() {
    if (_currentZone == null) return;

    final zoneMusic = MusicLayers.zones[_currentZone!];
    if (zoneMusic == null) return;

    for (final layer in zoneMusic.layers) {
      double targetVol;
      if (_intensity >= layer.minIntensity) {
        // Layer is active — ramp volume based on how far above threshold
        final ramp = layer.minIntensity > 0
            ? ((_intensity - layer.minIntensity) / (1.0 - layer.minIntensity))
                .clamp(0.0, 1.0)
            : 1.0;
        // Pad always at base volume; melody/perc ramp up
        if (layer.instrument == 'pad') {
          targetVol = layer.baseVolume;
        } else {
          targetVol = layer.baseVolume * ramp;
        }
      } else {
        targetVol = 0.0;
      }

      _layerTargetVolumes[layer.instrument] = targetVol;
    }

    // Tempo modulation: slight speed changes based on intensity
    _updatePlaybackRates();
  }

  /// Adjust playback rate for subtle tempo modulation.
  void _updatePlaybackRates() {
    // Map intensity to playback rate: 0.95x at low, 1.05x at high
    final rate = 0.95 + (_intensity * 0.10);
    for (final entry in _layerPlayers.entries) {
      try {
        entry.value.setPlaybackRate(rate);
      } catch (_) {}
    }
  }

  /// Start the periodic fade timer that smoothly interpolates volumes.
  void _startFadeTimer() {
    _stopFadeTimer();
    _fadeTimer = Timer.periodic(
      const Duration(milliseconds: _fadeStepMs),
      (_) => _fadeStep(),
    );
  }

  void _stopFadeTimer() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  /// One step of the volume fade interpolation.
  void _fadeStep() {
    if (_disposed) return;

    const stepFraction = _fadeStepMs / _fadeDurationMs;

    for (final instrument in _layerPlayers.keys) {
      final current = _layerCurrentVolumes[instrument] ?? 0.0;
      final target = _layerTargetVolumes[instrument] ?? 0.0;

      if ((current - target).abs() < 0.005) {
        // Close enough — snap to target
        _layerCurrentVolumes[instrument] = target;
      } else {
        // Interpolate towards target
        final delta = (target - current) * stepFraction * 3;
        _layerCurrentVolumes[instrument] = current + delta;
      }

      // Apply master volume and set on player
      final effectiveVol =
          (_layerCurrentVolumes[instrument]! * _masterVolume).clamp(0.0, 1.0);
      try {
        _layerPlayers[instrument]?.setVolume(effectiveVol);
      } catch (_) {}
    }
  }

  /// Start the intensity decay timer (slowly reduces intensity over time).
  void _startDecayTimer() {
    _stopDecayTimer();
    _decayTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_disposed || !_isPlaying) return;
        _intensity = (_intensity - _decayPerSecond).clamp(0.0, 1.0);
        _updateTargetVolumes();
      },
    );
  }

  void _stopDecayTimer() {
    _decayTimer?.cancel();
    _decayTimer = null;
  }

  /// Stop and dispose all layer players.
  Future<void> _stopLayerPlayers() async {
    for (final player in _layerPlayers.values) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
    _layerPlayers.clear();
    _layerCurrentVolumes.clear();
    _layerTargetVolumes.clear();
  }
}
