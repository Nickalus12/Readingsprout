import 'package:shared_preferences/shared_preferences.dart';

/// Persists player profile settings (name, preferences).
///
/// The player name is used for personalized audio phrases
/// (e.g., "Great job, Emma!") and on-screen messages.
class PlayerSettingsService {
  static const _nameKey = 'player_name';
  static const _setupCompleteKey = 'setup_complete';

  late SharedPreferences _prefs;

  String _playerName = '';
  bool _setupComplete = false;

  /// The player's display name (e.g., "Emma").
  String get playerName => _playerName;

  /// Whether the initial name setup has been completed.
  bool get setupComplete => _setupComplete;

  /// Whether a player name is configured.
  bool get hasName => _playerName.isNotEmpty;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _playerName = _prefs.getString(_nameKey) ?? '';
    _setupComplete = _prefs.getBool(_setupCompleteKey) ?? false;
  }

  /// Save the player's name and mark setup as complete.
  Future<void> setPlayerName(String name) async {
    _playerName = name.trim();
    _setupComplete = true;
    await _prefs.setString(_nameKey, _playerName);
    await _prefs.setBool(_setupCompleteKey, true);
  }

  /// Clear the player name (for resetting).
  Future<void> clearPlayerName() async {
    _playerName = '';
    _setupComplete = false;
    await _prefs.remove(_nameKey);
    await _prefs.remove(_setupCompleteKey);
  }
}
