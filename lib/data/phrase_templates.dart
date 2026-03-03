import 'dart:math';

/// Pre-defined encouragement phrase templates with {name} placeholders.
///
/// These match the TTS script's PHRASE_TEMPLATES exactly — each phrase
/// maps to a pre-generated audio file at:
///   assets/audio/phrases/{category}_{index}.mp3
///
/// When no pre-generated audio exists, the text is shown on screen
/// and can optionally be spoken via device TTS as a fallback.
class PhraseTemplates {
  PhraseTemplates._();

  static final _rng = Random();

  // ── Word complete phrases (played randomly after spelling a word) ─────

  static const wordComplete = [
    'Great job, {name}!',
    'Way to go, {name}!',
    'Awesome, {name}!',
    'You got it, {name}!',
    'Super, {name}!',
    'Nice work, {name}!',
    'Perfect, {name}!',
    'Keep it up, {name}!',
  ];

  // ── Level complete phrases (played when finishing all words in a level) ─

  static const levelComplete = [
    'Congratulations, {name}!',
    '{name}, you\'re a superstar!',
    'Incredible, {name}! Level complete!',
    'You did it, {name}!',
    'Amazing work, {name}!',
  ];

  // ── Welcome phrases (played on app open or returning) ─────────────────

  static const welcome = [
    'Welcome, {name}!',
    'Hi, {name}! Let\'s learn!',
    'Ready to play, {name}?',
    'Let\'s go, {name}!',
  ];

  // ── Generic fallback praises (no name, used if name not set) ──────────

  static const genericPraises = [
    'Great job!',
    'Awesome!',
    'You got it!',
    'Super!',
    'Wow!',
    'Perfect!',
    'Nice work!',
  ];

  /// Get a random phrase from a category, filled with the player's name.
  /// If [name] is empty, returns a generic praise instead.
  static String randomWordComplete(String name) {
    if (name.isEmpty) return genericPraises[_rng.nextInt(genericPraises.length)];
    final template = wordComplete[_rng.nextInt(wordComplete.length)];
    return template.replaceAll('{name}', name);
  }

  static String randomLevelComplete(String name) {
    if (name.isEmpty) return 'Level Complete!';
    final template = levelComplete[_rng.nextInt(levelComplete.length)];
    return template.replaceAll('{name}', name);
  }

  static String randomWelcome(String name) {
    if (name.isEmpty) return 'Welcome!';
    final template = welcome[_rng.nextInt(welcome.length)];
    return template.replaceAll('{name}', name);
  }

  /// Get the audio asset path for a specific phrase.
  /// Returns the path like 'audio/phrases/word_complete_3.mp3'.
  static String? audioPath(String category, int index) {
    return 'audio/phrases/${category}_$index.mp3';
  }

  /// Get a random phrase index + its audio path for a category.
  static ({int index, String text, String audioPath}) randomWithAudio(
    String category,
    String name,
  ) {
    final List<String> templates;
    switch (category) {
      case 'word_complete':
        templates = wordComplete;
      case 'level_complete':
        templates = levelComplete;
      case 'welcome':
        templates = welcome;
      default:
        templates = genericPraises;
    }

    final index = _rng.nextInt(templates.length);
    final text = templates[index].replaceAll('{name}', name);
    final path = 'audio/phrases/${category}_$index.mp3';

    return (index: index, text: text, audioPath: path);
  }
}
