import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/avatar_options.dart';
import '../models/player_profile.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';

/// Full-screen avatar editor with live preview and category-based customization.
///
/// Dark themed using [AppColors], with bounce + glow animations on selection.
/// Locked items display a lock icon and unlock hint.
class AvatarEditorScreen extends StatefulWidget {
  final ProfileService profileService;
  final int wordsMastered;
  final int streakDays;

  const AvatarEditorScreen({
    super.key,
    required this.profileService,
    this.wordsMastered = 0,
    this.streakDays = 0,
  });

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late AvatarConfig _config;
  int _selectedCategory = 0;

  // Compute evolution stage from words mastered (1-5)
  int get _evolutionStage {
    final level = ReadingLevel.forWordCount(widget.wordsMastered);
    return level.index + 1; // 1-based
  }

  static const List<String> _categoryLabels = [
    'Face',
    'Skin',
    'Hair',
    'Color',
    'Eyes',
    'Mouth',
    'Extra',
    'BG',
  ];

  static const List<IconData> _categoryIcons = [
    Icons.face,
    Icons.palette,
    Icons.content_cut,
    Icons.color_lens,
    Icons.visibility,
    Icons.sentiment_satisfied_alt,
    Icons.auto_awesome,
    Icons.circle,
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.profileService.avatar;
  }

  void _updateConfig(AvatarConfig newConfig) {
    setState(() => _config = newConfig);
  }

  Future<void> _save() async {
    await widget.profileService.setAvatar(_config);
    if (mounted) Navigator.of(context).pop(_config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 8),
            _buildPreview(),
            const SizedBox(height: 16),
            _buildCategoryTabs(),
            const SizedBox(height: 8),
            Expanded(child: _buildOptionsGrid()),
            _buildDoneButton(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.primaryText),
            iconSize: 28,
          ),
          Expanded(
            child: Text(
              'Create Your Look',
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ),
          const SizedBox(width: 48), // balance close button
        ],
      ),
    );
  }

  // ── Live Preview ──────────────────────────────────────────────────

  Widget _buildPreview() {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.border,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AvatarWidget(config: _config, size: 136.0)
                  .animate(key: ValueKey(_config.hashCode))
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.0, 1.0),
                    duration: 300.ms,
                    curve: Curves.elasticOut,
                  ),
      ),
    );
  }

  // ── Category Tabs ─────────────────────────────────────────────────

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categoryLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final selected = index == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.violet.withValues(alpha: 0.3)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.violet : AppColors.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _categoryIcons[index],
                    size: 18,
                    color: selected ? AppColors.violet : AppColors.secondaryText,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _categoryLabels[index],
                    style: GoogleFonts.fredoka(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? AppColors.violet : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Options Grid ──────────────────────────────────────────────────

  Widget _buildOptionsGrid() {
    switch (_selectedCategory) {
      case 0:
        return _buildFaceShapeOptions();
      case 1:
        return _buildSkinToneOptions();
      case 2:
        return _buildHairStyleOptions();
      case 3:
        return _buildHairColorOptions();
      case 4:
        return _buildEyeStyleOptions();
      case 5:
        return _buildMouthStyleOptions();
      case 6:
        return _buildAccessoryOptions();
      case 7:
        return _buildBgColorOptions();
      default:
        return const SizedBox.shrink();
    }
  }

  // Face shape
  Widget _buildFaceShapeOptions() {
    return _optionGrid(
      itemCount: faceShapeOptions.length,
      selectedIndex: _config.faceShape,
      builder: (index) {
        final opt = faceShapeOptions[index];
        final r = opt.borderRadius * 30;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: opt.index == 2 ? 42 : 36, // oval is taller
              decoration: BoxDecoration(
                color: AppColors.skinTones[_config.skinTone.clamp(0, 5)],
                borderRadius: BorderRadius.circular(r),
              ),
            ),
            const SizedBox(height: 4),
            Text(opt.label, style: _optLabelStyle),
          ],
        );
      },
      onTap: (index) => _updateConfig(_config.copyWith(faceShape: index)),
    );
  }

  // Skin tone
  Widget _buildSkinToneOptions() {
    return _optionGrid(
      itemCount: skinToneOptions.length,
      selectedIndex: _config.skinTone,
      builder: (index) {
        final opt = skinToneOptions[index];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: opt.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(opt.label, style: _optLabelStyle, overflow: TextOverflow.ellipsis),
          ],
        );
      },
      onTap: (index) => _updateConfig(_config.copyWith(skinTone: index)),
    );
  }

  // Hair style
  Widget _buildHairStyleOptions() {
    return _optionGrid(
      itemCount: hairStyleOptions.length,
      selectedIndex: _config.hairStyle,
      builder: (index) {
        final opt = hairStyleOptions[index];
        // Show a mini avatar preview with this hair
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: AvatarWidget(
                config: _config.copyWith(hairStyle: index),
                size: 40,
                showBackground: false,
              ),
            ),
            const SizedBox(height: 4),
            Text(opt.label, style: _optLabelStyle),
          ],
        );
      },
      onTap: (index) => _updateConfig(_config.copyWith(hairStyle: index)),
    );
  }

  // Hair color
  Widget _buildHairColorOptions() {
    return _optionGrid(
      itemCount: hairColorOptions.length,
      selectedIndex: _config.hairColor,
      builder: (index) {
        final opt = hairColorOptions[index];
        final locked = opt.isLocked &&
            !isUnlocked(
              requirement: opt.unlock,
              wordsMastered: widget.wordsMastered,
              evolutionStage: _evolutionStage,
              streakDays: widget.streakDays,
            );
        return _OptionTileContent(
          locked: locked,
          hint: opt.unlock?.hint,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: locked ? opt.color.withValues(alpha: 0.3) : opt.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(opt.label, style: _optLabelStyle),
            ],
          ),
        );
      },
      onTap: (index) {
        final opt = hairColorOptions[index];
        final locked = opt.isLocked &&
            !isUnlocked(
              requirement: opt.unlock,
              wordsMastered: widget.wordsMastered,
              evolutionStage: _evolutionStage,
              streakDays: widget.streakDays,
            );
        if (!locked) _updateConfig(_config.copyWith(hairColor: index));
      },
    );
  }

  // Eye style
  Widget _buildEyeStyleOptions() {
    return _optionGrid(
      itemCount: eyeStyleOptions.length,
      selectedIndex: _config.eyeStyle,
      builder: (index) {
        final opt = eyeStyleOptions[index];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 20,
              child: CustomPaint(
                painter: _EyePreviewPainter(style: index),
              ),
            ),
            const SizedBox(height: 6),
            Text(opt.label, style: _optLabelStyle),
          ],
        );
      },
      onTap: (index) => _updateConfig(_config.copyWith(eyeStyle: index)),
    );
  }

  // Mouth style
  Widget _buildMouthStyleOptions() {
    return _optionGrid(
      itemCount: mouthStyleOptions.length,
      selectedIndex: _config.mouthStyle,
      builder: (index) {
        final opt = mouthStyleOptions[index];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 16,
              child: CustomPaint(
                painter: _MouthPreviewPainter(style: index),
              ),
            ),
            const SizedBox(height: 6),
            Text(opt.label, style: _optLabelStyle),
          ],
        );
      },
      onTap: (index) => _updateConfig(_config.copyWith(mouthStyle: index)),
    );
  }

  // Accessories
  Widget _buildAccessoryOptions() {
    return _optionGrid(
      itemCount: accessoryOptions.length,
      selectedIndex: _config.accessory,
      builder: (index) {
        final opt = accessoryOptions[index];
        final locked = opt.isLocked &&
            !isUnlocked(
              requirement: opt.unlock,
              wordsMastered: widget.wordsMastered,
              evolutionStage: _evolutionStage,
              streakDays: widget.streakDays,
            );
        return _OptionTileContent(
          locked: locked,
          hint: opt.unlock?.hint,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (index == 0)
                Icon(Icons.block, size: 28, color: AppColors.secondaryText.withValues(alpha: 0.5))
              else
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AvatarWidget(
                    config: _config.copyWith(accessory: index),
                    size: 40,
                    showBackground: false,
                  ),
                ),
              const SizedBox(height: 4),
              Text(opt.label, style: _optLabelStyle),
            ],
          ),
        );
      },
      onTap: (index) {
        final opt = accessoryOptions[index];
        final locked = opt.isLocked &&
            !isUnlocked(
              requirement: opt.unlock,
              wordsMastered: widget.wordsMastered,
              evolutionStage: _evolutionStage,
              streakDays: widget.streakDays,
            );
        if (!locked) _updateConfig(_config.copyWith(accessory: index));
      },
    );
  }

  // Background color
  Widget _buildBgColorOptions() {
    return _optionGrid(
      itemCount: bgColorOptions.length,
      selectedIndex: _config.bgColor,
      builder: (index) {
        final opt = bgColorOptions[index];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: opt.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(opt.label, style: _optLabelStyle),
          ],
        );
      },
      onTap: (index) => _updateConfig(_config.copyWith(bgColor: index)),
    );
  }

  // ── Shared option grid builder ────────────────────────────────────

  Widget _optionGrid({
    required int itemCount,
    required int selectedIndex,
    required Widget Function(int index) builder,
    required void Function(int index) onTap,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final selected = index == selectedIndex;
        return GestureDetector(
          onTap: () => onTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.violet.withValues(alpha: 0.2)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.violet : AppColors.border,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.violet.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? builder(index)
                    .animate()
                    .scale(
                      begin: const Offset(0.85, 0.85),
                      end: const Offset(1.0, 1.0),
                      duration: 350.ms,
                      curve: Curves.elasticOut,
                    )
                : builder(index),
          ),
        );
      },
    );
  }

  // ── Done Button ───────────────────────────────────────────────────

  Widget _buildDoneButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.violet,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
          child: Text(
            'Done',
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 300.ms)
        .slideY(begin: 0.2, end: 0, duration: 300.ms);
  }

  TextStyle get _optLabelStyle => GoogleFonts.fredoka(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: AppColors.secondaryText,
      );
}

// ── Locked option overlay ───────────────────────────────────────────

class _OptionTileContent extends StatelessWidget {
  final bool locked;
  final String? hint;
  final Widget child;

  const _OptionTileContent({
    required this.locked,
    this.hint,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;

    return Stack(
      children: [
        Opacity(opacity: 0.3, child: child),
        Positioned.fill(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 20,
                color: AppColors.secondaryText.withValues(alpha: 0.7),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: GoogleFonts.fredoka(
                    fontSize: 9,
                    color: AppColors.starGold.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Mini preview painters for eyes / mouth in editor tiles ──────────

class _EyePreviewPainter extends CustomPainter {
  final int style;
  _EyePreviewPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final leftC = Offset(w * 0.3, h * 0.5);
    final rightC = Offset(w * 0.7, h * 0.5);
    final r = w * 0.1;

    switch (style) {
      case 0: // Round
        canvas.drawCircle(leftC, r, Paint()..color = Colors.white);
        canvas.drawCircle(rightC, r, Paint()..color = Colors.white);
        canvas.drawCircle(leftC, r * 0.55, Paint()..color = const Color(0xFF1A1A2E));
        canvas.drawCircle(rightC, r * 0.55, Paint()..color = const Color(0xFF1A1A2E));

      case 1: // Star
        _drawStar(canvas, leftC, r, Paint()..color = AppColors.starGold);
        _drawStar(canvas, rightC, r, Paint()..color = AppColors.starGold);

      case 2: // Hearts
        _drawHeart(canvas, leftC, r, Paint()..color = const Color(0xFFFF4D6A));
        _drawHeart(canvas, rightC, r, Paint()..color = const Color(0xFFFF4D6A));

      case 3: // Happy crescents
        final paint = Paint()
          ..color = const Color(0xFF1A1A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCircle(center: leftC, radius: r), 0.2, 2.7, false, paint);
        canvas.drawArc(Rect.fromCircle(center: rightC, radius: r), 0.2, 2.7, false, paint);

      case 4: // Sparkle
        final bigR = r * 1.3;
        canvas.drawCircle(leftC, bigR, Paint()..color = Colors.white);
        canvas.drawCircle(rightC, bigR, Paint()..color = Colors.white);
        canvas.drawCircle(leftC, bigR * 0.6, Paint()..color = const Color(0xFF6366F1));
        canvas.drawCircle(rightC, bigR * 0.6, Paint()..color = const Color(0xFF6366F1));
        canvas.drawCircle(leftC.translate(bigR * 0.25, -bigR * 0.2), bigR * 0.25, Paint()..color = Colors.white);
        canvas.drawCircle(rightC.translate(bigR * 0.25, -bigR * 0.2), bigR * 0.25, Paint()..color = Colors.white);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      final ox = center.dx + r * cos(outerAngle);
      final oy = center.dy + r * sin(outerAngle);
      final ix = center.dx + r * 0.4 * cos(innerAngle);
      final iy = center.dy + r * 0.4 * sin(innerAngle);
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double r, Paint paint) {
    final x = center.dx;
    final y = center.dy;
    final path = Path();
    path.moveTo(x, y + r * 0.5);
    path.cubicTo(x - r * 1.2, y - r * 0.3, x - r * 0.5, y - r * 1.0, x, y - r * 0.3);
    path.cubicTo(x + r * 0.5, y - r * 1.0, x + r * 1.2, y - r * 0.3, x, y + r * 0.5);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_EyePreviewPainter old) => old.style != style;
}

class _MouthPreviewPainter extends CustomPainter {
  final int style;
  _MouthPreviewPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (style) {
      case 0: // Smile
        final paint = Paint()
          ..color = const Color(0xFF1A1A2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.06
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromLTWH(w * 0.1, -h * 0.3, w * 0.8, h * 1.2),
          0.3, 2.5, false, paint,
        );

      case 1: // Big Grin
        final path = Path()
          ..moveTo(w * 0.05, h * 0.1)
          ..quadraticBezierTo(w * 0.5, h * 1.2, w * 0.95, h * 0.1)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF1A1A2E));
        canvas.drawRect(
          Rect.fromLTWH(w * 0.3, h * 0.1, w * 0.4, h * 0.2),
          Paint()..color = Colors.white,
        );

      case 2: // Tongue Out
        final path = Path()
          ..moveTo(w * 0.1, h * 0.1)
          ..quadraticBezierTo(w * 0.5, h * 1.0, w * 0.9, h * 0.1)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF1A1A2E));
        canvas.drawOval(
          Rect.fromCenter(center: Offset(w * 0.5, h * 0.7), width: w * 0.3, height: h * 0.5),
          Paint()..color = const Color(0xFFFF6B8A),
        );

      case 3: // Surprised O
        canvas.drawOval(
          Rect.fromCenter(center: Offset(w * 0.5, h * 0.5), width: w * 0.4, height: h * 0.8),
          Paint()..color = const Color(0xFF1A1A2E),
        );
    }
  }

  @override
  bool shouldRepaint(_MouthPreviewPainter old) => old.style != style;
}
