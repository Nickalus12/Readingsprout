import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/profile_service.dart';
import '../theme/app_theme.dart';

/// The daily treasure chest widget with four states:
/// locked, unlocked, opening, and opened.
class DailyTreasure extends StatefulWidget {
  final ProfileService profileService;
  final int wordsPlayedToday;
  final int currentStreak;

  /// Called when the chest is opened with the reward item name.
  final ValueChanged<String>? onRewardEarned;

  const DailyTreasure({
    super.key,
    required this.profileService,
    required this.wordsPlayedToday,
    required this.currentStreak,
    this.onRewardEarned,
  });

  @override
  State<DailyTreasure> createState() => _DailyTreasureState();
}

enum _ChestState { locked, unlocked, opening, opened }

enum _ChestTier { wooden, silver, golden }

class _DailyTreasureState extends State<DailyTreasure>
    with TickerProviderStateMixin {
  late _ChestState _state;
  String? _rewardItem;
  late AnimationController _wobbleController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _updateState();
  }

  void _updateState() {
    if (widget.profileService.dailyChestOpened) {
      _state = _ChestState.opened;
      _rewardItem = widget.profileService.lastChestReward;
    } else if (widget.wordsPlayedToday >= 5) {
      _state = _ChestState.unlocked;
    } else {
      _state = _ChestState.locked;
    }
  }

  _ChestTier get _tier {
    if (widget.currentStreak >= 7) return _ChestTier.golden;
    if (widget.currentStreak >= 3) return _ChestTier.silver;
    return _ChestTier.wooden;
  }

  Color get _tierColor => switch (_tier) {
        _ChestTier.wooden => AppColors.chestWood,
        _ChestTier.silver => AppColors.chestSilver,
        _ChestTier.golden => AppColors.chestGold,
      };

  String get _tierName => switch (_tier) {
        _ChestTier.wooden => 'Wooden',
        _ChestTier.silver => 'Silver',
        _ChestTier.golden => 'Golden',
      };

  static const List<String> _rewards = [
    'Rainbow Flower',
    'Sparkle Butterfly',
    'Golden Leaf',
    'Magic Mushroom',
    'Star Dust',
    'Crystal Dewdrop',
    'Firefly Lantern',
    'Moon Petal',
  ];

  void _onTap() async {
    switch (_state) {
      case _ChestState.locked:
        // Shake to show it's locked
        _wobbleController.forward(from: 0);
        break;

      case _ChestState.unlocked:
        // Open the chest
        setState(() => _state = _ChestState.opening);

        // Pick a random reward
        final rng = Random();
        final reward = _rewards[rng.nextInt(_rewards.length)];

        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;
        setState(() {
          _state = _ChestState.opened;
          _rewardItem = reward;
        });

        // Persist
        await widget.profileService.openDailyChest();
        await widget.profileService.setLastChestReward(reward);
        widget.onRewardEarned?.call(reward);
        break;

      case _ChestState.opening:
      case _ChestState.opened:
        break;
    }
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Daily Treasure',
            style: GoogleFonts.fredoka(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _tierColor,
            ),
          ),
        ),
        GestureDetector(
          onTap: _onTap,
          child: Container(
            width: double.infinity,
            height: 160,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _tierColor.withValues(alpha: 0.3),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _buildCurrentState(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentState() {
    return switch (_state) {
      _ChestState.locked => _buildLocked(),
      _ChestState.unlocked => _buildUnlocked(),
      _ChestState.opening => _buildOpening(),
      _ChestState.opened => _buildOpened(),
    };
  }

  Widget _buildLocked() {
    return AnimatedBuilder(
      animation: _wobbleController,
      builder: (context, child) {
        final wobble = sin(_wobbleController.value * pi * 4) *
            (1 - _wobbleController.value) *
            0.05;
        return Transform.rotate(angle: wobble, child: child);
      },
      child: Column(
        key: const ValueKey('locked'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Chest icon
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.inventory_2_rounded,
                size: 56,
                color: _tierColor.withValues(alpha: 0.7),
              ),
              Positioned(
                bottom: 0,
                child: Icon(
                  Icons.lock,
                  size: 20,
                  color: AppColors.secondaryText.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$_tierName Chest',
            style: GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _tierColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Play ${5 - widget.wordsPlayedToday} more words to open!',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .rotate(begin: -0.01, end: 0.01, duration: 2000.ms);
  }

  Widget _buildUnlocked() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _tierColor
                    .withValues(alpha: 0.1 + _glowController.value * 0.15),
                blurRadius: 20 + _glowController.value * 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        key: const ValueKey('unlocked'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_rounded,
            size: 56,
            color: _tierColor,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 0.95, end: 1.05, duration: 1000.ms),
          const SizedBox(height: 8),
          Text(
            '$_tierName Chest',
            style: GoogleFonts.fredoka(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _tierColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to open!',
            style: GoogleFonts.fredoka(
              fontSize: 14,
              color: AppColors.starGold,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 600.ms)
              .then()
              .fadeOut(duration: 600.ms),
        ],
      ),
    );
  }

  Widget _buildOpening() {
    return Column(
      key: const ValueKey('opening'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Chest with lid opening
        Stack(
          alignment: Alignment.center,
          children: [
            // Light beams
            ...List.generate(5, (i) {
              final angle = (i - 2) * 0.3;
              return Transform.rotate(
                angle: angle,
                child: Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        _tierColor.withValues(alpha: 0.6),
                        _tierColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              );
            }),
            Icon(
              Icons.inventory_2_rounded,
              size: 56,
              color: _tierColor,
            ),
          ],
        )
            .animate()
            .scaleXY(begin: 1, end: 1.2, duration: 800.ms)
            .then()
            .shakeY(amount: 3, duration: 400.ms),
        const SizedBox(height: 8),
        Text(
          'Opening...',
          style: GoogleFonts.fredoka(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _tierColor,
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms),
      ],
    );
  }

  Widget _buildOpened() {
    return Column(
      key: const ValueKey('opened'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Opened chest
        Icon(
          Icons.card_giftcard_rounded,
          size: 40,
          color: _tierColor.withValues(alpha: 0.5),
        ),
        if (_rewardItem != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _tierColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _tierColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: _tierColor),
                const SizedBox(width: 6),
                Text(
                  _rewardItem!,
                  style: GoogleFonts.fredoka(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _tierColor,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.5, end: 0, duration: 400.ms),
        ],
        const SizedBox(height: 8),
        Text(
          'Come back tomorrow!',
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
