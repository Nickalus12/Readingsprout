import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../data/phrase_templates.dart';
import 'amplitude_envelope.dart';
import 'deepgram_tts_service.dart';

class AudioService {
  final _rng = Random();
  bool _initialized = false;

  /// The SoLoud singleton instance.
  late final SoLoud _soloud;

  /// Cache of loaded AudioSources keyed by asset path.
  final Map<String, AudioSource> _sourceCache = {};

  /// Optional Deepgram TTS service for runtime-generated phrases.
  DeepgramTtsService? _deepgramTts;

  /// Active profile ID for looking up generated phrase files.
  String? _activeProfileId;

  // ── Amplitude-based lip sync ──────────────────────────────────────
  final AmplitudeEnvelopeCache _envelopeCache = AmplitudeEnvelopeCache();
  final ValueNotifier<double> mouthAmplitude = ValueNotifier(0.0);

  Timer? _amplitudeTimer;
  SoundHandle? _trackedHandle;
  AmplitudeEnvelope? _trackedEnvelope;

  Future<void> init() async {
    _soloud = SoLoud.instance;
    if (!_soloud.isInitialized) {
      await _soloud.init(
        automaticCleanup: false,
      );
    }
    // Allow more simultaneous voices for music + effects + words
    _soloud.setMaxActiveVoiceCount(32);
    _initialized = true;
  }

  /// Load an asset, using cache to avoid reloading.
  Future<AudioSource> _loadAsset(String assetPath) async {
    final fullPath = 'assets/$assetPath';
    if (_sourceCache.containsKey(fullPath)) {
      return _sourceCache[fullPath]!;
    }
    final source = await _soloud.loadAsset(fullPath, mode: LoadMode.memory);
    _sourceCache[fullPath] = source;
    return source;
  }

  /// Load a file from filesystem (for Deepgram-generated audio).
  Future<AudioSource> _loadFile(String filePath) async {
    if (_sourceCache.containsKey(filePath)) {
      return _sourceCache[filePath]!;
    }
    final source = await _soloud.loadFile(filePath, mode: LoadMode.memory);
    _sourceCache[filePath] = source;
    return source;
  }

  /// Play an asset with the given tag behavior. Returns true on success.
  Future<bool> _play(String assetPath, {double volume = 1.0, AmplitudeEnvelope? envelope}) async {
    try {
      final source = await _loadAsset(assetPath);
      final handle = await _soloud.play(source, volume: volume);

      if (envelope != null) {
        _startAmplitudeTracking(handle, envelope);
      }
      return true;
    } catch (e) {
      debugPrint('SoLoud play error ($assetPath): $e');
      return false;
    }
  }

  /// Stop all currently playing instances of a source at the given path.
  Future<void> _stopByPath(String assetPath) async {
    final fullPath = 'assets/$assetPath';
    final source = _sourceCache[fullPath];
    if (source != null && source.handles.isNotEmpty) {
      for (final handle in source.handles.toList()) {
        try {
          await _soloud.stop(handle);
        } catch (_) {}
      }
    }
  }

  void setDeepgramTts(DeepgramTtsService tts) {
    _deepgramTts = tts;
  }

  void setActiveProfile(String? profileId) {
    _activeProfileId = profileId;
  }

  Future<bool> playWord(String word) async {
    if (!_initialized) return false;
    try {
      _stopAmplitudeTracking();
      final path = 'audio/words/${word.toLowerCase()}.mp3';
      await _stopByPath(path);
      final env = await _envelopeCache.load(path);
      return await _play(path, envelope: env);
    } catch (e) {
      debugPrint('Audio error (word: $word): $e');
      return false;
    }
  }

  Future<bool> playLetter(String letter) async {
    if (!_initialized) return false;
    try {
      _stopAmplitudeTracking();
      final path = 'audio/letter_names/${letter.toLowerCase()}.mp3';
      await _stopByPath(path);
      final env = await _envelopeCache.load(path);
      return await _play(path, envelope: env);
    } catch (e) {
      debugPrint('Audio error (letter: $letter): $e');
      return false;
    }
  }

  Future<bool> playLetterPhonics(String letter) async {
    if (!_initialized) return false;
    try {
      _stopAmplitudeTracking();
      final path = 'audio/phonics/${letter.toLowerCase()}.mp3';
      await _stopByPath(path);
      final env = await _envelopeCache.load(path);
      return await _play(path, envelope: env);
    } catch (e) {
      debugPrint('Audio error (letter phonics: $letter): $e');
      return false;
    }
  }

  Future<bool> playLetterName(String letter) => playLetter(letter);

  Future<String?> playPhrase(String category, String playerName) async {
    if (!_initialized || playerName.isEmpty) return null;

    final List<String> templates;
    switch (category) {
      case 'word_complete':
        templates = PhraseTemplates.wordComplete;
      case 'level_complete':
        templates = PhraseTemplates.levelComplete;
      case 'welcome':
        templates = PhraseTemplates.welcome;
      default:
        return null;
    }

    final index = _rng.nextInt(templates.length);
    final text = templates[index].replaceAll('{name}', playerName);

    try {
      // Check for runtime-generated file first
      if (_deepgramTts != null && _activeProfileId != null) {
        final localFile = _deepgramTts!.phraseFile(_activeProfileId!, category, index);
        if (localFile.existsSync()) {
          _stopAmplitudeTracking();
          final source = await _loadFile(localFile.path);
          await _soloud.play(source);
          return text;
        }
      }

      // Fall back to bundled asset
      final path = 'audio/phrases/${category}_$index.mp3';
      final env = await _envelopeCache.load(path);
      _stopAmplitudeTracking();
      await _play(path, envelope: env);
    } catch (e) {
      debugPrint('Audio error (phrase: ${category}_$index): $e');
    }

    return text;
  }

  Future<String?> playWelcome(String playerName) async {
    if (_rng.nextDouble() < 0.4 || playerName.isEmpty) {
      const genericFiles = [
        'welcome_generic_1', 'welcome_generic_2', 'welcome_generic_3',
        'welcome_generic_4', 'welcome_generic_5', 'welcome_generic_6',
        'welcome_generic_7', 'welcome_generic_8', 'welcome_generic_9',
        'welcome_generic_10', 'welcome_generic_11', 'welcome_generic_12',
        'welcome_generic_13',
      ];
      final file = genericFiles[_rng.nextInt(genericFiles.length)];
      try {
        _stopAmplitudeTracking();
        final path = 'audio/words/$file.mp3';
        final env = await _envelopeCache.load(path);
        await _play(path, envelope: env);
      } catch (e) {
        debugPrint('Audio error (generic welcome: $file): $e');
      }
      return file.replaceAll('_', ' ');
    }
    return playPhrase('welcome', playerName);
  }

  Future<String?> playWordComplete(String playerName) => playPhrase('word_complete', playerName);
  Future<String?> playLevelComplete(String playerName) => playPhrase('level_complete', playerName);

  Future<void> playSuccess() async {
    if (!_initialized) return;
    try { await _play('audio/effects/success.mp3'); } catch (e) { debugPrint('Audio error (success): $e'); }
  }

  Future<void> playError() async {
    if (!_initialized) return;
    try { await _play('audio/effects/error.mp3'); } catch (e) { debugPrint('Audio error (error): $e'); }
  }

  Future<void> playLevelCompleteEffect() async {
    if (!_initialized) return;
    try { await _play('audio/effects/level_complete.mp3'); } catch (e) { debugPrint('Audio error (level_complete): $e'); }
  }

  // ── Amplitude tracking with Timer-based position polling ────────

  void _startAmplitudeTracking(SoundHandle handle, AmplitudeEnvelope? env) {
    _stopAmplitudeTracking();
    if (env == null) return;

    _trackedHandle = handle;
    _trackedEnvelope = env;

    // Poll position every 20ms (matches envelope frame rate)
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      final h = _trackedHandle;
      final e = _trackedEnvelope;
      if (h == null || e == null) {
        _stopAmplitudeTracking();
        return;
      }
      try {
        if (!_soloud.getIsValidVoiceHandle(h)) {
          mouthAmplitude.value = 0.0;
          _stopAmplitudeTracking();
          return;
        }
        final position = _soloud.getPosition(h);
        mouthAmplitude.value = e.getAmplitude(position);
      } catch (_) {
        mouthAmplitude.value = 0.0;
        _stopAmplitudeTracking();
      }
    });
  }

  void _stopAmplitudeTracking() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _trackedHandle = null;
    _trackedEnvelope = null;
  }

  Future<void> preloadEnvelopes(List<String> words) async {
    await _envelopeCache.preloadWords(words);
  }

  void dispose() {
    _stopAmplitudeTracking();
    mouthAmplitude.dispose();
    // Dispose all cached sources
    for (final source in _sourceCache.values) {
      try { _soloud.disposeSource(source); } catch (_) {}
    }
    _sourceCache.clear();
    if (_soloud.isInitialized) {
      _soloud.deinit();
    }
  }
}
