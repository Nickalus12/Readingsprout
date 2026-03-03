import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/name_setup_screen.dart';
import 'services/progress_service.dart';
import 'services/audio_service.dart';
import 'services/player_settings_service.dart';
import 'widgets/floating_hearts_bg.dart';

class SightWordsApp extends StatefulWidget {
  const SightWordsApp({super.key});

  @override
  State<SightWordsApp> createState() => _SightWordsAppState();
}

class _SightWordsAppState extends State<SightWordsApp> {
  late final ProgressService _progressService;
  late final AudioService _audioService;
  late final PlayerSettingsService _settingsService;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _progressService = ProgressService();
    _audioService = AudioService();
    _settingsService = PlayerSettingsService();
    await _progressService.init();
    await _audioService.init();
    await _settingsService.init();
    setState(() => _initialized = true);
  }

  void _onNameSubmitted(String name) async {
    await _settingsService.setPlayerName(name);
    setState(() {});
  }

  void _onChangeName() {
    // Show the name setup screen again
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NameSetupScreen(
          onNameSubmitted: (name) {
            _onNameSubmitted(name);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sight Words',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!_initialized) {
      return const _SplashScreen();
    }

    // Show name setup on first launch
    if (!_settingsService.setupComplete) {
      return NameSetupScreen(onNameSubmitted: _onNameSubmitted);
    }

    return HomeScreen(
      progressService: _progressService,
      audioService: _audioService,
      playerName: _settingsService.playerName,
      onChangeName: _onChangeName,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.background, AppColors.backgroundEnd],
              ),
            ),
          ),

          // Floating hearts — even the splash is alive
          const Positioned.fill(
            child: FloatingHeartsBackground(cloudZoneHeight: 0.18),
          ),

          // Loading indicator
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.electricBlue,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: GoogleFonts.fredoka(
                    fontSize: 24,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
