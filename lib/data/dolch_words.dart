import '../models/word.dart';

/// The 220 Dolch sight words, organized into 22 levels of 10 words.
/// Ordered roughly by difficulty: Pre-Primer → Primer → 1st → 2nd → 3rd grade.
class DolchWords {
  DolchWords._();

  static const List<List<String>> _wordsByLevel = [
    // Level 1 — Pre-Primer (easiest)
    ['a', 'I', 'it', 'is', 'in', 'my', 'me', 'we', 'go', 'to'],
    // Level 2
    ['up', 'no', 'on', 'do', 'he', 'at', 'an', 'am', 'so', 'be'],
    // Level 3
    ['the', 'and', 'see', 'you', 'can', 'not', 'run', 'big', 'red', 'one'],
    // Level 4
    ['for', 'was', 'are', 'but', 'had', 'has', 'his', 'her', 'him', 'how'],
    // Level 5
    ['did', 'get', 'may', 'new', 'now', 'old', 'our', 'out', 'ran', 'say'],
    // Level 6 — Primer
    ['she', 'too', 'all', 'ate', 'came', 'like', 'will', 'yes', 'said', 'good'],
    // Level 7
    ['that', 'they', 'this', 'what', 'with', 'have', 'into', 'want', 'well', 'went'],
    // Level 8
    ['look', 'make', 'play', 'ride', 'must', 'stop', 'help', 'jump', 'find', 'from'],
    // Level 9
    ['come', 'give', 'just', 'know', 'let', 'live', 'over', 'take', 'tell', 'them'],
    // Level 10
    ['then', 'were', 'when', 'here', 'soon', 'open', 'upon', 'once', 'some', 'very'],
    // Level 11 — First Grade
    ['ask', 'any', 'fly', 'try', 'put', 'cut', 'hot', 'got', 'ten', 'sit'],
    // Level 12
    ['after', 'again', 'every', 'going', 'could', 'would', 'think', 'thank', 'round', 'sleep'],
    // Level 13
    ['walk', 'work', 'wash', 'wish', 'which', 'white', 'where', 'there', 'these', 'those'],
    // Level 14
    ['under', 'about', 'never', 'seven', 'eight', 'green', 'brown', 'black', 'clean', 'small'],
    // Level 15
    ['away', 'best', 'both', 'call', 'cold', 'does', 'done', 'draw', 'fall', 'fast'],
    // Level 16 — Second Grade
    ['been', 'read', 'made', 'gave', 'many', 'only', 'pull', 'full', 'keep', 'kind'],
    // Level 17
    ['long', 'much', 'pick', 'show', 'sing', 'warm', 'hold', 'hurt', 'far', 'own'],
    // Level 18
    ['carry', 'today', 'start', 'shall', 'laugh', 'light', 'right', 'write', 'first', 'found'],
    // Level 19
    ['bring', 'drink', 'funny', 'happy', 'their', 'your', 'four', 'five', 'six', 'two'],
    // Level 20 — Third Grade
    ['always', 'around', 'before', 'better', 'please', 'pretty', 'because', 'myself', 'goes', 'together'],
    // Level 21
    ['buy', 'use', 'off', 'its', 'why', 'grow', 'if', 'or', 'as', 'by'],
    // Level 22
    ['three', 'blue', 'eat', 'saw', 'down', 'little', 'who', 'yellow', 'us', 'of'],
  ];

  /// All 220 words as [Word] objects
  static List<Word> get allWords {
    final words = <Word>[];
    for (int level = 0; level < _wordsByLevel.length; level++) {
      for (int i = 0; i < _wordsByLevel[level].length; i++) {
        words.add(Word(
          id: 'dolch_${level + 1}_$i',
          text: _wordsByLevel[level][i],
          level: level + 1,
        ));
      }
    }
    return words;
  }

  /// Words for a specific level (1-based)
  static List<Word> wordsForLevel(int level) {
    if (level < 1 || level > _wordsByLevel.length) return [];
    return _wordsByLevel[level - 1]
        .asMap()
        .entries
        .map((e) => Word(
              id: 'dolch_${level}_${e.key}',
              text: e.value,
              level: level,
            ))
        .toList();
  }

  static int get totalLevels => _wordsByLevel.length;

  /// Level display names
  static String levelName(int level) {
    if (level <= 5) return 'Pre-Primer $level';
    if (level <= 10) return 'Primer ${level - 5}';
    if (level <= 15) return 'First Grade ${level - 10}';
    if (level <= 19) return 'Second Grade ${level - 15}';
    return 'Third Grade ${level - 19}';
  }

  /// All unique words (for TTS generation script)
  static Set<String> get uniqueWords {
    return _wordsByLevel.expand((level) => level).map((w) => w.toLowerCase()).toSet();
  }
}
