import '../models/word.dart';

/// Bonus sight words beyond the 220 Dolch words.
///
/// These are common, kid-friendly words organized by theme.
/// All words have pre-generated TTS audio (via generate_tts_gemini.py).
///
/// To add more words:
/// 1. Add them to the appropriate category below
/// 2. Add the same words to BONUS_WORDS in scripts/generate_tts_gemini.py
/// 3. Re-run the TTS script to generate audio
class BonusWords {
  BonusWords._();

  static const Map<String, List<String>> _categories = {
    'Family': ['mom', 'dad', 'baby', 'love', 'family'],
    'Animals': ['dog', 'cat', 'fish', 'bird', 'bear', 'frog'],
    'Home & Play': ['home', 'food', 'book', 'ball', 'game', 'toy'],
    'My Body': ['hand', 'head', 'eyes', 'feet'],
    'Nature': ['sun', 'moon', 'star', 'tree', 'rain', 'snow'],
    'School': ['school', 'teacher', 'friend', 'learn'],
    'More Colors': ['pink', 'purple', 'orange'],
    'More Numbers': ['nine', 'zero'],
    'Feelings': ['nice', 'hard', 'soft', 'dark', 'tall', 'loud', 'quiet'],
  };

  /// All bonus words organized by category.
  static Map<String, List<String>> get categories => _categories;

  /// All bonus words as a flat list.
  static List<String> get allWords {
    return _categories.values.expand((words) => words).toList();
  }

  /// All bonus words as [Word] objects (level 0 = bonus).
  static List<Word> get allWordObjects {
    final words = <Word>[];
    int i = 0;
    for (final word in allWords) {
      words.add(Word(
        id: 'bonus_$i',
        text: word,
        level: 0, // 0 = bonus, not part of Dolch levels
      ));
      i++;
    }
    return words;
  }

  /// Create a Word object for a custom word (like the player's name).
  static Word customWord(String text) {
    return Word(
      id: 'custom_${text.toLowerCase()}',
      text: text.toLowerCase(),
      level: 0,
      isCustom: true,
    );
  }
}
