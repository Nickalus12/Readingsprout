/// Defines the layered music assets available for each zone.
///
/// The adaptive music system crossfades between layers based on gameplay
/// intensity (difficulty, streak, combo). Each zone has a pad (ambient drone),
/// melody (pentatonic loop), and optional percussion. Stingers are short
/// one-shot sounds for events like correct answers and streaks.
class MusicLayer {
  /// Path relative to `assets/` (SoLoud prepends `assets/` when loading).
  final String assetPath;

  /// Layer type: 'pad', 'melody', 'percussion', 'stinger'.
  final String instrument;

  /// Minimum intensity (0.0-1.0) at which this layer becomes audible.
  /// Pad plays at 0.0 (always), melody at 0.3, percussion at 0.6.
  final double minIntensity;

  /// Base volume for this layer (0.0-1.0). Actual volume is scaled by
  /// the master volume and intensity ramp.
  final double baseVolume;

  const MusicLayer({
    required this.assetPath,
    required this.instrument,
    this.minIntensity = 0.0,
    this.baseVolume = 0.5,
  });
}

/// Music configuration for a single zone.
class ZoneMusic {
  final String zoneKey;
  final List<MusicLayer> layers;

  const ZoneMusic({required this.zoneKey, required this.layers});
}

/// All music layers indexed by zone key and stinger name.
class MusicLayers {
  MusicLayers._();

  // ── Zone music ──────────────────────────────────────────────────

  static const Map<String, ZoneMusic> zones = {
    'woods': ZoneMusic(
      zoneKey: 'woods',
      layers: [
        MusicLayer(
          assetPath: 'audio/music/woods_pad.wav',
          instrument: 'pad',
          minIntensity: 0.0,
          baseVolume: 0.5,
        ),
        MusicLayer(
          assetPath: 'audio/music/woods_melody.wav',
          instrument: 'melody',
          minIntensity: 0.3,
          baseVolume: 0.45,
        ),
        MusicLayer(
          assetPath: 'audio/music/perc_gentle.wav',
          instrument: 'percussion',
          minIntensity: 0.6,
          baseVolume: 0.3,
        ),
      ],
    ),
    'shore': ZoneMusic(
      zoneKey: 'shore',
      layers: [
        MusicLayer(
          assetPath: 'audio/music/shore_pad.wav',
          instrument: 'pad',
          minIntensity: 0.0,
          baseVolume: 0.5,
        ),
        MusicLayer(
          assetPath: 'audio/music/shore_melody.wav',
          instrument: 'melody',
          minIntensity: 0.3,
          baseVolume: 0.45,
        ),
        MusicLayer(
          assetPath: 'audio/music/perc_gentle.wav',
          instrument: 'percussion',
          minIntensity: 0.6,
          baseVolume: 0.3,
        ),
      ],
    ),
    'peaks': ZoneMusic(
      zoneKey: 'peaks',
      layers: [
        MusicLayer(
          assetPath: 'audio/music/peaks_pad.wav',
          instrument: 'pad',
          minIntensity: 0.0,
          baseVolume: 0.5,
        ),
        MusicLayer(
          assetPath: 'audio/music/peaks_melody.wav',
          instrument: 'melody',
          minIntensity: 0.3,
          baseVolume: 0.45,
        ),
        MusicLayer(
          assetPath: 'audio/music/perc_medium.wav',
          instrument: 'percussion',
          minIntensity: 0.6,
          baseVolume: 0.3,
        ),
      ],
    ),
    'sky': ZoneMusic(
      zoneKey: 'sky',
      layers: [
        MusicLayer(
          assetPath: 'audio/music/sky_pad.wav',
          instrument: 'pad',
          minIntensity: 0.0,
          baseVolume: 0.5,
        ),
        MusicLayer(
          assetPath: 'audio/music/sky_melody.wav',
          instrument: 'melody',
          minIntensity: 0.3,
          baseVolume: 0.45,
        ),
        MusicLayer(
          assetPath: 'audio/music/perc_medium.wav',
          instrument: 'percussion',
          minIntensity: 0.6,
          baseVolume: 0.3,
        ),
      ],
    ),
    'crown': ZoneMusic(
      zoneKey: 'crown',
      layers: [
        MusicLayer(
          assetPath: 'audio/music/crown_pad.wav',
          instrument: 'pad',
          minIntensity: 0.0,
          baseVolume: 0.5,
        ),
        MusicLayer(
          assetPath: 'audio/music/crown_melody.wav',
          instrument: 'melody',
          minIntensity: 0.3,
          baseVolume: 0.45,
        ),
        MusicLayer(
          assetPath: 'audio/music/perc_energetic.wav',
          instrument: 'percussion',
          minIntensity: 0.6,
          baseVolume: 0.3,
        ),
      ],
    ),
  };

  // ── Stingers ────────────────────────────────────────────────────

  static const Map<String, MusicLayer> stingers = {
    'correct': MusicLayer(
      assetPath: 'audio/music/correct_chime.wav',
      instrument: 'stinger',
      baseVolume: 0.35,
    ),
    'streak': MusicLayer(
      assetPath: 'audio/music/streak_chime.wav',
      instrument: 'stinger',
      baseVolume: 0.4,
    ),
    'combo': MusicLayer(
      assetPath: 'audio/music/combo_chime.wav',
      instrument: 'stinger',
      baseVolume: 0.35,
    ),
  };

  /// Map zone names from [DolchWords.zones] to music zone keys.
  static String zoneKeyFromName(String zoneName) {
    final lower = zoneName.toLowerCase();
    if (lower.contains('woods') || lower.contains('whisper')) return 'woods';
    if (lower.contains('shore') || lower.contains('shimmer')) return 'shore';
    if (lower.contains('peaks') || lower.contains('crystal')) return 'peaks';
    if (lower.contains('sky') || lower.contains('kingdom')) return 'sky';
    if (lower.contains('crown') || lower.contains('celestial')) return 'crown';
    return 'woods'; // fallback
  }

  /// Get zone key from a 0-based zone index.
  static String zoneKeyFromIndex(int zoneIndex) {
    const keys = ['woods', 'shore', 'peaks', 'sky', 'crown'];
    if (zoneIndex < 0 || zoneIndex >= keys.length) return 'woods';
    return keys[zoneIndex];
  }
}
