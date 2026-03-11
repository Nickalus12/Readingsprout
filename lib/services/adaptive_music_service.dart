import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../data/music_layers.dart';

/// Manages layered, adaptive background music for Reading Sprout.
///
/// The music system plays zone-themed ambient soundscapes with multiple
/// layers (pad, melody, percussion) that fade in/out based on gameplay
/// intensity. Uses [SoLoud.instance] (shared singleton with [AudioService]).
///
/// Key design goals:
/// - **Subtle**: Master volume is low (0.15). This is ambient background
///   music for children, never overpowering speech or sound effects.
/// - **Adaptive**: Layers crossfade based on a 0.0-1.0 intensity value
///   driven by gameplay events (correct answers bump it up, wrong answers
///   dip it down, streaks push it higher).
/// - **Smooth**: All volume transitions are gradual (2-3 second fades)
///   to avoid jarring changes.
/// - **Zone-themed filters**: Each zone applies global audio filters
///   (reverb, echo) for unique atmospheres.
class AdaptiveMusicService {
  // ── Configuration ──────────────────────────────────────────────────

  /// Master volume multiplier. Keeps music ambient and unobtrusive.
  static const double _masterVolume = 0.15;

  /// How much a correct answer bumps intensity.
  static const double _correctBump = 0.08;

  /// How much a wrong answer dips intensity.
  static const double _wrongDip = 0.12;

  /// How much a streak milestone bumps intensity.
  static const double _streakBump = 0.15;

  /// Intensity decay per second when no events occur.
  static const double _decayPerSecond = 0.02;

  // ── State ──────────────────────────────────────────────────────────

  late final SoLoud _soloud;

  /// Loaded music sources keyed by asset path.
  final Map<String, AudioSource> _sources = {};

  /// Active handles for each layer instrument.
  final Map<String, SoundHandle> _layerHandles = {};

  /// Target volumes for each layer.
  final Map<String, double> _layerTargetVolumes = {};

  /// Current volumes for smooth interpolation.
  final Map<String, double> _layerCurrentVolumes = {};

  /// Stinger sources (pre-loaded).
  final Map<String, AudioSource> _stingerSources = {};

  String? _currentZone;
  double _intensity = 0.0;
  bool _isPlaying = false;
  bool _enabled = true;
  bool _disposed = false;
  Timer? _fadeTimer;
  Timer? _decayTimer;

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
    if (!value && _isPlaying) stopMusic();
  }

  /// Initialize the service. Call once at app startup.
  Future<void> init() async {
    _soloud = SoLoud.instance;
    // SoLoud may already be initialized by AudioService
    if (!_soloud.isInitialized) {
      await _soloud.init(automaticCleanup: false);
    }

    // Pre-load stinger sources
    for (final entry in MusicLayers.stingers.entries) {
      try {
        _stingerSources[entry.key] = await _soloud.loadAsset(
          'assets/${entry.value.assetPath}',
          mode: LoadMode.memory,
        );
      } catch (e) {
        debugPrint('AdaptiveMusic: Failed to load stinger ${entry.key}: $e');
      }
    }

    debugPrint('AdaptiveMusicService initialized (SoLoud)');
  }

  /// Start playing zone-themed music.
  ///
  /// [zoneKey] is one of: 'woods', 'shore', 'peaks', 'sky', 'crown'.
  /// If music is already playing for this zone, this is a no-op.
  /// If a different zone is playing, it crossfades to the new zone.
  Future<void> startZoneMusic(String zoneKey) async {
    if (_disposed || !_enabled) return;
    if (_currentZone == zoneKey && _isPlaying) return;

    if (_currentZone != null && _currentZone != zoneKey) {
      await _stopLayerHandles();
      _removeZoneFilters();
    }

    final zoneMusic = MusicLayers.zones[zoneKey];
    if (zoneMusic == null) {
      debugPrint('AdaptiveMusic: Unknown zone "$zoneKey"');
      return;
    }

    _currentZone = zoneKey;
    _intensity = 0.0;

    // Load and start each layer
    for (final layer in zoneMusic.layers) {
      try {
        final assetPath = 'assets/${layer.assetPath}';
        if (!_sources.containsKey(assetPath)) {
          _sources[assetPath] = await _soloud.loadAsset(assetPath, mode: LoadMode.memory);
        }
        final source = _sources[assetPath]!;
        final handle = await _soloud.play(source, volume: 0.0, looping: true);
        _layerHandles[layer.instrument] = handle;
        _layerCurrentVolumes[layer.instrument] = 0.0;
        _layerTargetVolumes[layer.instrument] = 0.0;
      } catch (e) {
        debugPrint('AdaptiveMusic: Failed to play ${layer.instrument}: $e');
      }
    }

    _applyZoneFilters(zoneKey);
    _isPlaying = true;
    _updateTargetVolumes();
    _startFadeTimer();
    _startDecayTimer();

    debugPrint('AdaptiveMusic: Started zone "$zoneKey"');
  }

  /// Apply zone-specific global audio filters for unique atmosphere.
  void _applyZoneFilters(String zoneKey) {
    try {
      switch (zoneKey) {
        case 'woods':
          _soloud.filters.freeverbFilter.activate();
          _soloud.filters.freeverbFilter.wet.value = 0.12;
          _soloud.filters.freeverbFilter.roomSize.value = 0.6;
        case 'shore':
          _soloud.filters.echoFilter.activate();
          _soloud.filters.echoFilter.delay.value = 0.25;
          _soloud.filters.echoFilter.decay.value = 0.3;
        case 'peaks':
          _soloud.filters.freeverbFilter.activate();
          _soloud.filters.freeverbFilter.wet.value = 0.08;
          _soloud.filters.freeverbFilter.roomSize.value = 0.4;
        case 'sky':
          _soloud.filters.freeverbFilter.activate();
          _soloud.filters.freeverbFilter.wet.value = 0.20;
          _soloud.filters.freeverbFilter.roomSize.value = 0.8;
        case 'crown':
          _soloud.filters.freeverbFilter.activate();
          _soloud.filters.freeverbFilter.wet.value = 0.25;
          _soloud.filters.freeverbFilter.roomSize.value = 0.9;
      }
    } catch (e) {
      debugPrint('AdaptiveMusic: Filter setup error: $e');
    }
  }

  /// Remove all zone-specific global filters.
  void _removeZoneFilters() {
    try {
      _soloud.filters.freeverbFilter.deactivate();
    } catch (_) {}
    try {
      _soloud.filters.echoFilter.deactivate();
    } catch (_) {}
  }

  /// Stop all music with a fade-out.
  Future<void> stopMusic() async {
    if (!_isPlaying) return;

    // Fade out all layers
    for (final entry in _layerHandles.entries) {
      try {
        _soloud.fadeVolume(entry.value, 0.0, const Duration(milliseconds: 2000));
        _soloud.scheduleStop(entry.value, const Duration(milliseconds: 2100));
      } catch (_) {}
    }

    _stopFadeTimer();
    _stopDecayTimer();

    // Wait for fade then clean up
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    _layerHandles.clear();
    _layerCurrentVolumes.clear();
    _layerTargetVolumes.clear();
    _removeZoneFilters();

    _isPlaying = false;
    _currentZone = null;
    _intensity = 0.0;

    debugPrint('AdaptiveMusic: Stopped');
  }

  /// Update the intensity based on gameplay difficulty.
  void updateIntensity(double difficulty) {
    _intensity = difficulty.clamp(0.0, 1.0);
    _updateTargetVolumes();
  }

  /// Play a short stinger sound effect.
  Future<void> playStinger(String name) async {
    if (_disposed || !_enabled) return;
    final source = _stingerSources[name];
    if (source == null) return;
    final stingerLayer = MusicLayers.stingers[name];
    if (stingerLayer == null) return;
    try {
      await _soloud.play(source, volume: stingerLayer.baseVolume * _masterVolume);
    } catch (e) {
      debugPrint('AdaptiveMusic: Stinger error ($name): $e');
    }
  }

  /// Called when the player answers correctly.
  void onCorrectAnswer() {
    _intensity = (_intensity + _correctBump).clamp(0.0, 1.0);
    _updateTargetVolumes();
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
    for (final handle in _layerHandles.values) {
      try { _soloud.setPause(handle, true); } catch (_) {}
    }
    _stopFadeTimer();
    _stopDecayTimer();
  }

  /// Resume music playback after pause.
  Future<void> resume() async {
    if (!_isPlaying || !_enabled) return;
    for (final handle in _layerHandles.values) {
      try { _soloud.setPause(handle, false); } catch (_) {}
    }
    _startFadeTimer();
    _startDecayTimer();
  }

  /// Dispose all resources. Call when the service is no longer needed.
  Future<void> dispose() async {
    _disposed = true;
    _stopFadeTimer();
    _stopDecayTimer();
    await _stopLayerHandles();
    _removeZoneFilters();
    for (final source in _sources.values) {
      try { _soloud.disposeSource(source); } catch (_) {}
    }
    for (final source in _stingerSources.values) {
      try { _soloud.disposeSource(source); } catch (_) {}
    }
    _sources.clear();
    _stingerSources.clear();
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
        final ramp = layer.minIntensity > 0
            ? ((_intensity - layer.minIntensity) / (1.0 - layer.minIntensity)).clamp(0.0, 1.0)
            : 1.0;
        targetVol = layer.instrument == 'pad' ? layer.baseVolume : layer.baseVolume * ramp;
      } else {
        targetVol = 0.0;
      }
      _layerTargetVolumes[layer.instrument] = targetVol;
    }
    _updatePlaybackRates();
  }

  /// Adjust playback rate for subtle tempo modulation.
  void _updatePlaybackRates() {
    final rate = 0.95 + (_intensity * 0.10);
    for (final handle in _layerHandles.values) {
      try { _soloud.setRelativePlaySpeed(handle, rate); } catch (_) {}
    }
  }

  /// Start the periodic fade timer that smoothly interpolates volumes.
  void _startFadeTimer() {
    _stopFadeTimer();
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _fadeStep());
  }

  void _stopFadeTimer() { _fadeTimer?.cancel(); _fadeTimer = null; }

  /// One step of the volume fade interpolation.
  void _fadeStep() {
    if (_disposed) return;
    const stepFraction = 50 / 2500;
    for (final instrument in _layerHandles.keys) {
      final current = _layerCurrentVolumes[instrument] ?? 0.0;
      final target = _layerTargetVolumes[instrument] ?? 0.0;
      double newVol;
      if ((current - target).abs() < 0.005) {
        newVol = target;
      } else {
        newVol = current + (target - current) * stepFraction * 3;
      }
      _layerCurrentVolumes[instrument] = newVol;
      final effectiveVol = (newVol * _masterVolume).clamp(0.0, 1.0);
      final handle = _layerHandles[instrument];
      if (handle != null) {
        try { _soloud.setVolume(handle, effectiveVol); } catch (_) {}
      }
    }
  }

  /// Start the intensity decay timer (slowly reduces intensity over time).
  void _startDecayTimer() {
    _stopDecayTimer();
    _decayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || !_isPlaying) return;
      _intensity = (_intensity - _decayPerSecond).clamp(0.0, 1.0);
      _updateTargetVolumes();
    });
  }

  void _stopDecayTimer() { _decayTimer?.cancel(); _decayTimer = null; }

  /// Stop all active layer handles.
  Future<void> _stopLayerHandles() async {
    for (final handle in _layerHandles.values) {
      try { await _soloud.stop(handle); } catch (_) {}
    }
    _layerHandles.clear();
    _layerCurrentVolumes.clear();
    _layerTargetVolumes.clear();
  }
}
