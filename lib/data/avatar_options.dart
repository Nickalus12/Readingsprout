import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Metadata for all avatar customization options: labels, colors, and unlock conditions.

// ── Face Shapes ───────────────────────────────────────────────────────

class FaceShapeOption {
  final int index;
  final String label;
  final double borderRadius; // fraction of size (0.0 = square, 0.5 = circle)

  const FaceShapeOption(this.index, this.label, this.borderRadius);
}

const List<FaceShapeOption> faceShapeOptions = [
  FaceShapeOption(0, 'Circle', 0.5),
  FaceShapeOption(1, 'Square', 0.3),
  FaceShapeOption(2, 'Oval', 0.45),
];

// ── Skin Tones ────────────────────────────────────────────────────────

class SkinToneOption {
  final int index;
  final String label;
  final Color color;

  const SkinToneOption(this.index, this.label, this.color);
}

final List<SkinToneOption> skinToneOptions = [
  SkinToneOption(0, 'Light', AppColors.skinTones[0]),
  SkinToneOption(1, 'Light-Medium', AppColors.skinTones[1]),
  SkinToneOption(2, 'Medium', AppColors.skinTones[2]),
  SkinToneOption(3, 'Medium-Dark', AppColors.skinTones[3]),
  SkinToneOption(4, 'Dark', AppColors.skinTones[4]),
  SkinToneOption(5, 'Deep', AppColors.skinTones[5]),
];

// ── Hair Styles ───────────────────────────────────────────────────────

class HairStyleOption {
  final int index;
  final String label;

  const HairStyleOption(this.index, this.label);
}

const List<HairStyleOption> hairStyleOptions = [
  HairStyleOption(0, 'Short'),
  HairStyleOption(1, 'Long'),
  HairStyleOption(2, 'Curly'),
  HairStyleOption(3, 'Braids'),
  HairStyleOption(4, 'Ponytail'),
  HairStyleOption(5, 'Buzz'),
  HairStyleOption(6, 'Afro'),
  HairStyleOption(7, 'Bun'),
];

// ── Hair Colors ───────────────────────────────────────────────────────

class HairColorOption {
  final int index;
  final String label;
  final Color color;
  final UnlockRequirement? unlock;

  const HairColorOption(this.index, this.label, this.color, [this.unlock]);

  bool get isLocked => unlock != null;
  String get unlockId => 'hair_color_$index';
}

final List<HairColorOption> hairColorOptions = [
  const HairColorOption(0, 'Black', Color(0xFF1A1A2E)),
  const HairColorOption(1, 'Brown', Color(0xFF6B4226)),
  const HairColorOption(2, 'Blonde', Color(0xFFE8C872)),
  const HairColorOption(3, 'Red', Color(0xFFB5332E)),
  const HairColorOption(4, 'Auburn', Color(0xFF8B4513)),
  const HairColorOption(5, 'Strawberry', Color(0xFFE0926A)),
  const HairColorOption(
    6,
    'Blue',
    Color(0xFF4A90D9),
    UnlockRequirement(type: UnlockType.wordsMastered, threshold: 25, hint: '25 words!'),
  ),
  const HairColorOption(
    7,
    'Purple',
    Color(0xFF9B59B6),
    UnlockRequirement(type: UnlockType.wordsMastered, threshold: 50, hint: '50 words!'),
  ),
];

// ── Eye Styles ────────────────────────────────────────────────────────

class EyeStyleOption {
  final int index;
  final String label;

  const EyeStyleOption(this.index, this.label);
}

const List<EyeStyleOption> eyeStyleOptions = [
  EyeStyleOption(0, 'Round'),
  EyeStyleOption(1, 'Star'),
  EyeStyleOption(2, 'Hearts'),
  EyeStyleOption(3, 'Happy'),
  EyeStyleOption(4, 'Sparkle'),
];

// ── Mouth Styles ──────────────────────────────────────────────────────

class MouthStyleOption {
  final int index;
  final String label;

  const MouthStyleOption(this.index, this.label);
}

const List<MouthStyleOption> mouthStyleOptions = [
  MouthStyleOption(0, 'Smile'),
  MouthStyleOption(1, 'Big Grin'),
  MouthStyleOption(2, 'Tongue Out'),
  MouthStyleOption(3, 'Surprised'),
];

// ── Accessories ───────────────────────────────────────────────────────

class AccessoryOption {
  final int index;
  final String label;
  final UnlockRequirement? unlock;

  const AccessoryOption(this.index, this.label, [this.unlock]);

  bool get isLocked => unlock != null;
  String get unlockId => 'accessory_$index';
}

const List<AccessoryOption> accessoryOptions = [
  AccessoryOption(0, 'None'),
  AccessoryOption(1, 'Glasses'),
  AccessoryOption(2, 'Crown'),
  AccessoryOption(3, 'Flower'),
  AccessoryOption(4, 'Bow'),
  AccessoryOption(5, 'Cap'),
  AccessoryOption(
    6,
    'Wizard Hat',
    UnlockRequirement(type: UnlockType.evolutionStage, threshold: 3, hint: 'Word Wizard!'),
  ),
  AccessoryOption(
    7,
    'Wings',
    UnlockRequirement(type: UnlockType.evolutionStage, threshold: 4, hint: 'Word Champion!'),
  ),
  AccessoryOption(
    8,
    'Royal Crown',
    UnlockRequirement(type: UnlockType.evolutionStage, threshold: 5, hint: 'Reading Superstar!'),
  ),
];

// ── Background Colors ─────────────────────────────────────────────────

class BgColorOption {
  final int index;
  final String label;
  final Color color;

  const BgColorOption(this.index, this.label, this.color);
}

final List<BgColorOption> bgColorOptions = [
  BgColorOption(0, 'Peach', AppColors.avatarBgColors[0]),
  BgColorOption(1, 'Mint', AppColors.avatarBgColors[1]),
  BgColorOption(2, 'Sky', AppColors.avatarBgColors[2]),
  BgColorOption(3, 'Lavender', AppColors.avatarBgColors[3]),
  BgColorOption(4, 'Honey', AppColors.avatarBgColors[4]),
  BgColorOption(5, 'Coral', AppColors.avatarBgColors[5]),
  BgColorOption(6, 'Aqua', AppColors.avatarBgColors[6]),
  BgColorOption(7, 'Mauve', AppColors.avatarBgColors[7]),
];

// ── Unlock System ─────────────────────────────────────────────────────

enum UnlockType {
  wordsMastered,
  evolutionStage,
  streakDays,
}

class UnlockRequirement {
  final UnlockType type;
  final int threshold;
  final String hint;

  const UnlockRequirement({
    required this.type,
    required this.threshold,
    required this.hint,
  });
}

/// Check whether a lockable item is unlocked given the player's progress.
bool isUnlocked({
  required UnlockRequirement? requirement,
  required int wordsMastered,
  required int evolutionStage,
  required int streakDays,
}) {
  if (requirement == null) return true;
  switch (requirement.type) {
    case UnlockType.wordsMastered:
      return wordsMastered >= requirement.threshold;
    case UnlockType.evolutionStage:
      return evolutionStage >= requirement.threshold;
    case UnlockType.streakDays:
      return streakDays >= requirement.threshold;
  }
}
