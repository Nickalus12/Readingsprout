import 'dart:ui';

/// Stroke templates for all 26 lowercase letters.
///
/// Each letter maps to a list of strokes. Each stroke is a list of points
/// normalized to 0.0–1.0 within the letter bounding box. Simplified,
/// child-friendly stroke orders with 1–3 strokes per letter.
class LetterPaths {
  LetterPaths._();

  /// Raw path data: letter → list of strokes → list of [x, y] points.
  static const Map<String, List<List<List<double>>>> paths = {
    'a': [
      // Bowl: arc from right, around left, back to right
      [
        [0.70, 0.30], [0.60, 0.18], [0.45, 0.15], [0.30, 0.20],
        [0.20, 0.35], [0.20, 0.55], [0.25, 0.70], [0.38, 0.82],
        [0.55, 0.85], [0.70, 0.75],
      ],
      // Stem: straight down on right side
      [[0.70, 0.15], [0.70, 0.85]],
    ],

    'b': [
      // Tall stem down
      [[0.30, 0.00], [0.30, 0.85]],
      // Bowl: right bump
      [
        [0.30, 0.40], [0.45, 0.30], [0.62, 0.32], [0.72, 0.45],
        [0.72, 0.60], [0.68, 0.75], [0.52, 0.85], [0.30, 0.85],
      ],
    ],

    'c': [
      // Open curve from top-right, around left, to bottom-right
      [
        [0.75, 0.25], [0.60, 0.15], [0.42, 0.15], [0.25, 0.25],
        [0.18, 0.42], [0.18, 0.58], [0.25, 0.75], [0.42, 0.85],
        [0.60, 0.85], [0.75, 0.75],
      ],
    ],

    'd': [
      // Bowl: arc from right, around left, back to right
      [
        [0.70, 0.40], [0.55, 0.30], [0.38, 0.30], [0.25, 0.42],
        [0.20, 0.55], [0.22, 0.70], [0.35, 0.82], [0.52, 0.85],
        [0.70, 0.75],
      ],
      // Tall stem on right side
      [[0.70, 0.00], [0.70, 0.85]],
    ],

    'e': [
      // Start at middle, curve right, around the top-left, down and around
      [
        [0.20, 0.50], [0.75, 0.50], [0.75, 0.35], [0.65, 0.20],
        [0.48, 0.15], [0.30, 0.20], [0.20, 0.35], [0.18, 0.55],
        [0.25, 0.72], [0.42, 0.85], [0.60, 0.85], [0.75, 0.78],
      ],
    ],

    'f': [
      // Curve from top-right, down the stem
      [
        [0.65, 0.08], [0.55, 0.02], [0.42, 0.05], [0.35, 0.15],
        [0.35, 0.30], [0.35, 0.50], [0.35, 0.70], [0.35, 0.85],
      ],
      // Crossbar
      [[0.18, 0.38], [0.55, 0.38]],
    ],

    'g': [
      // Bowl: arc from right, around left, back to right
      [
        [0.70, 0.30], [0.58, 0.18], [0.42, 0.15], [0.28, 0.22],
        [0.20, 0.38], [0.20, 0.55], [0.28, 0.70], [0.42, 0.80],
        [0.58, 0.80], [0.70, 0.70],
      ],
      // Descender: stem goes down below baseline then curves left
      [
        [0.70, 0.18], [0.70, 0.85], [0.70, 0.92],
        [0.62, 0.98], [0.45, 1.00], [0.30, 0.95],
      ],
    ],

    'h': [
      // Tall stem down
      [[0.28, 0.00], [0.28, 0.85]],
      // Hump: from stem midway, up and over to the right, down
      [
        [0.28, 0.42], [0.38, 0.28], [0.52, 0.22], [0.65, 0.28],
        [0.72, 0.42], [0.72, 0.60], [0.72, 0.85],
      ],
    ],

    'i': [
      // Dot
      [[0.50, 0.08], [0.50, 0.12]],
      // Stem
      [[0.50, 0.25], [0.50, 0.85]],
    ],

    'j': [
      // Dot
      [[0.55, 0.08], [0.55, 0.12]],
      // Stem going down then curving left below baseline
      [
        [0.55, 0.25], [0.55, 0.50], [0.55, 0.75], [0.55, 0.90],
        [0.48, 0.98], [0.35, 1.00], [0.22, 0.95],
      ],
    ],

    'k': [
      // Tall stem down
      [[0.30, 0.00], [0.30, 0.85]],
      // Diagonal in from upper-right to stem middle
      [[0.68, 0.20], [0.50, 0.38], [0.30, 0.50]],
      // Diagonal out from stem middle to lower-right
      [[0.30, 0.50], [0.50, 0.65], [0.70, 0.85]],
    ],

    'l': [
      // Tall stem down — simple vertical line
      [[0.50, 0.00], [0.50, 0.85]],
    ],

    'm': [
      // Down
      [[0.15, 0.25], [0.15, 0.85]],
      // First hump
      [
        [0.15, 0.38], [0.22, 0.25], [0.35, 0.22], [0.42, 0.30],
        [0.45, 0.45], [0.45, 0.85],
      ],
      // Second hump
      [
        [0.45, 0.38], [0.52, 0.25], [0.65, 0.22], [0.75, 0.30],
        [0.80, 0.45], [0.80, 0.85],
      ],
    ],

    'n': [
      // Down
      [[0.25, 0.25], [0.25, 0.85]],
      // Hump
      [
        [0.25, 0.42], [0.35, 0.28], [0.50, 0.22], [0.65, 0.30],
        [0.72, 0.45], [0.72, 0.85],
      ],
    ],

    'o': [
      // Full circle (oval)
      [
        [0.50, 0.15], [0.32, 0.18], [0.20, 0.32], [0.18, 0.50],
        [0.22, 0.68], [0.35, 0.82], [0.50, 0.85], [0.65, 0.82],
        [0.78, 0.68], [0.80, 0.50], [0.78, 0.32], [0.65, 0.18],
        [0.50, 0.15],
      ],
    ],

    'p': [
      // Stem goes down below baseline
      [[0.30, 0.22], [0.30, 0.50], [0.30, 0.75], [0.30, 1.00]],
      // Bowl: right bump at x-height
      [
        [0.30, 0.22], [0.45, 0.15], [0.62, 0.18], [0.72, 0.32],
        [0.72, 0.50], [0.65, 0.65], [0.48, 0.72], [0.30, 0.68],
      ],
    ],

    'q': [
      // Bowl (like 'd' but mirrored)
      [
        [0.30, 0.30], [0.42, 0.18], [0.58, 0.15], [0.70, 0.25],
        [0.78, 0.42], [0.78, 0.58], [0.70, 0.72], [0.55, 0.80],
        [0.40, 0.78], [0.30, 0.65],
      ],
      // Descender stem on right
      [[0.70, 0.22], [0.70, 0.50], [0.70, 0.75], [0.70, 1.00]],
    ],

    'r': [
      // Stem down
      [[0.32, 0.22], [0.32, 0.85]],
      // Small arch at top
      [
        [0.32, 0.40], [0.40, 0.28], [0.52, 0.20], [0.65, 0.22],
        [0.72, 0.30],
      ],
    ],

    's': [
      // S-curve from top-right, leftward, then right, then left at bottom
      [
        [0.70, 0.22], [0.58, 0.15], [0.42, 0.15], [0.28, 0.22],
        [0.22, 0.32], [0.28, 0.45], [0.45, 0.50], [0.62, 0.55],
        [0.72, 0.65], [0.72, 0.75], [0.62, 0.85], [0.45, 0.88],
        [0.28, 0.82],
      ],
    ],

    't': [
      // Stem from above x-height down
      [[0.45, 0.08], [0.45, 0.50], [0.45, 0.75], [0.45, 0.85]],
      // Crossbar
      [[0.22, 0.30], [0.68, 0.30]],
    ],

    'u': [
      // Down and curve up
      [
        [0.25, 0.22], [0.25, 0.50], [0.25, 0.65], [0.32, 0.78],
        [0.45, 0.85], [0.60, 0.82], [0.70, 0.72],
      ],
      // Right stem down
      [[0.70, 0.22], [0.70, 0.85]],
    ],

    'v': [
      // Diagonal down-right to center bottom
      [[0.18, 0.22], [0.35, 0.52], [0.50, 0.85]],
      // Diagonal up-right from center bottom
      [[0.50, 0.85], [0.65, 0.52], [0.82, 0.22]],
    ],

    'w': [
      // Down-right
      [[0.10, 0.22], [0.25, 0.85]],
      // Up to middle peak
      [[0.25, 0.85], [0.38, 0.45], [0.50, 0.22]],
      // Down again
      [[0.50, 0.22], [0.62, 0.45], [0.75, 0.85]],
      // Final up-right (combined with previous for 2-stroke simplification)
      // Actually keep as part of a connected stroke for kids
    ],

    'x': [
      // Top-left to bottom-right diagonal
      [[0.22, 0.22], [0.50, 0.52], [0.78, 0.85]],
      // Top-right to bottom-left diagonal
      [[0.78, 0.22], [0.50, 0.52], [0.22, 0.85]],
    ],

    'y': [
      // Left arm going down to center
      [[0.22, 0.22], [0.35, 0.42], [0.50, 0.55]],
      // Right arm going down to center, then descender
      [
        [0.78, 0.22], [0.65, 0.42], [0.50, 0.55],
        [0.42, 0.72], [0.35, 0.88], [0.28, 0.98],
      ],
    ],

    'z': [
      // Top horizontal
      [[0.22, 0.22], [0.78, 0.22]],
      // Diagonal
      [[0.78, 0.22], [0.22, 0.85]],
      // Bottom horizontal
      [[0.22, 0.85], [0.78, 0.85]],
    ],
  };

  /// Get path as [List<List<Offset>>] for a letter (strokes of offsets).
  static List<List<Offset>> getPath(String letter) {
    final raw = paths[letter.toLowerCase()];
    if (raw == null) return [];
    return raw
        .map((stroke) => stroke.map((p) => Offset(p[0], p[1])).toList())
        .toList();
  }

  /// Number of strokes for a letter. Returns 0 if unknown.
  static int strokeCount(String letter) {
    return paths[letter.toLowerCase()]?.length ?? 0;
  }
}
