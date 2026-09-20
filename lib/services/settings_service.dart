import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'audio_service.dart';

class SettingsService extends ChangeNotifier {
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _musicEnabledKey = 'music_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _gameSpeedKey = 'game_speed';
  static const String _gridSizeKey = 'grid_size';
  static const String _controlTypeKey = 'control_type';
  static const String _highScoreKey = 'high_score';
  static const String _gamesPlayedKey = 'games_played_offline';
  static const String _trophiesKey = 'player_trophies';
  static const String _serverUrlKey = 'custom_server_url';

  SharedPreferences? _prefs;

  static const int speedNormal = 280;
  static const int speedFast = 200;
  static const int speedVeryFast = 140;
  static const int speedUltraFast = 95;
  static const int speedHyperFast = 65;
  static const int speedInsane = 45;

  static const List<int> speedProgressionLevels = [
    speedNormal,
    speedFast,
    speedVeryFast,
    speedUltraFast,
    speedHyperFast,
    speedInsane,
  ];

  static const List<String> speedLevelNames = [
    'Normal',
    'Rápido',
    'Muito Rápido',
    'Ultra Rápido',
    'Hiper Rápido',
    'Velocidade Insana',
  ];

  static int getSpeedForStage(int initialSpeedIndex, int stage) {
    final targetIndex = (initialSpeedIndex + stage).clamp(0, speedProgressionLevels.length - 1);
    return speedProgressionLevels[targetIndex];
  }

  static String getSpeedNameForStage(int initialSpeedIndex, int stage) {
    final targetIndex = (initialSpeedIndex + stage).clamp(0, speedLevelNames.length - 1);
    return speedLevelNames[targetIndex];
  }

  // Settings values
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _vibrationEnabled = true;
  int _gameSpeed = speedNormal; // milliseconds
  int _gridSize = 20;
  ControlType _controlType = ControlType.swipe;
  int _highScore = 0;
  int _gamesPlayed = 0;
  int _trophies = 0;
  static const String defaultServerUrl = 'https://snake-online-server-uxpy.onrender.com';
  String _serverUrl = defaultServerUrl;

  // Getters
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  int get gameSpeed => _gameSpeed;
  int get gridSize => _gridSize;
  ControlType get controlType => _controlType;
  int get highScore => _highScore;
  int get gamesPlayed => _gamesPlayed;
  int get trophies => _trophies;
  String get serverUrl => _serverUrl;

  void addTrophies(int delta) {
    _trophies = (_trophies + delta).clamp(0, 999999);
    _prefs?.setInt(_trophiesKey, _trophies);
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url.trim();
    await _prefs?.setString(_serverUrlKey, _serverUrl);
    notifyListeners();
  }

  // Initialize settings
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  // Load all settings from SharedPreferences
  void _loadSettings() {
    if (_prefs == null) return;

    if (!_prefs!.containsKey(_musicEnabledKey)) {
      _prefs!.setBool(_musicEnabledKey, true);
    }
    _soundEnabled = _prefs!.getBool(_soundEnabledKey) ?? true;
    _musicEnabled = _prefs!.getBool(_musicEnabledKey) ?? true;
    _vibrationEnabled = _prefs!.getBool(_vibrationEnabledKey) ?? true;
    _gameSpeed = _prefs!.getInt(_gameSpeedKey) ?? speedNormal;
    _gridSize = _prefs!.getInt(_gridSizeKey) ?? 20;
    final savedControl = _prefs!.getInt(_controlTypeKey) ?? 0;
    _controlType = (savedControl >= 0 && savedControl < ControlType.values.length)
        ? ControlType.values[savedControl]
        : ControlType.swipe;
    _highScore = _prefs!.getInt(_highScoreKey) ?? 0;
    _gamesPlayed = _prefs!.getInt(_gamesPlayedKey) ?? 0;
    _trophies = _prefs!.getInt(_trophiesKey) ?? 0;
    final savedUrl = _prefs!.getString(_serverUrlKey);
    if (savedUrl == null || savedUrl.contains('localhost') || savedUrl.contains('192.168.') || savedUrl.contains('10.0.2.2')) {
      _serverUrl = defaultServerUrl;
    } else {
      _serverUrl = savedUrl;
    }

    notifyListeners();
  }

  // Sound settings
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _prefs?.setBool(_soundEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    await _prefs?.setBool(_musicEnabledKey, enabled);
    
    // Control background music based on setting
    if (enabled) {
      // Start background music when enabled
      AudioService().startBackgroundMusic();
    } else {
      // Stop background music when disabled
      AudioService().stopBackgroundMusic();
    }
    
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _prefs?.setBool(_vibrationEnabledKey, enabled);
    notifyListeners();
  }

  // Game settings
  Future<void> setGameSpeed(int speed) async {
    if (speed < 50 || speed > 1000) return; // Validate speed range
    _gameSpeed = speed;
    await _prefs?.setInt(_gameSpeedKey, speed);
    notifyListeners();
  }

  int get speedIndex {
    if (_gameSpeed <= 160) return 2;
    if (_gameSpeed <= 240) return 1;
    return 0;
  }

  Future<void> setSpeedByIndex(int index) async {
    switch (index) {
      case 2:
        await setGameSpeed(speedVeryFast);
        break;
      case 1:
        await setGameSpeed(speedFast);
        break;
      case 0:
      default:
        await setGameSpeed(speedNormal);
        break;
    }
  }

  Future<void> setGridSize(int size) async {
    if (size < 10 || size > 30) return; // Validate grid size range
    _gridSize = size;
    await _prefs?.setInt(_gridSizeKey, size);
    notifyListeners();
  }

  Future<void> setControlType(ControlType type) async {
    _controlType = type;
    await _prefs?.setInt(_controlTypeKey, type.index);
    notifyListeners();
  }

  // Score tracking
  Future<void> updateHighScore(int score) async {
    if (score > _highScore) {
      _highScore = score;
      await _prefs?.setInt(_highScoreKey, score);
      notifyListeners();
    }
  }

  Future<void> incrementGamesPlayed() async {
    _gamesPlayed++;
    await _prefs?.setInt(_gamesPlayedKey, _gamesPlayed);
    notifyListeners();
  }

  // Reset all settings
  Future<void> resetSettings() async {
    _soundEnabled = true;
    _musicEnabled = true;
    _vibrationEnabled = true;
    _gameSpeed = speedNormal;
    _gridSize = 20;
    _controlType = ControlType.swipe;

    await Future.wait([
      _prefs?.setBool(_soundEnabledKey, _soundEnabled) ?? Future.value(),
      _prefs?.setBool(_musicEnabledKey, _musicEnabled) ?? Future.value(),
      _prefs?.setBool(_vibrationEnabledKey, _vibrationEnabled) ?? Future.value(),
      _prefs?.setInt(_gameSpeedKey, _gameSpeed) ?? Future.value(),
      _prefs?.setInt(_gridSizeKey, _gridSize) ?? Future.value(),
      _prefs?.setInt(_controlTypeKey, _controlType.index) ?? Future.value(),
    ]);

    notifyListeners();
  }

  // Reset game statistics (not settings)
  Future<void> resetGameStats() async {
    _highScore = 0;
    _gamesPlayed = 0;
    _trophies = 0;

    await Future.wait([
      _prefs?.setInt(_highScoreKey, 0) ?? Future.value(),
      _prefs?.setInt(_gamesPlayedKey, 0) ?? Future.value(),
      _prefs?.setInt(_trophiesKey, 0) ?? Future.value(),
    ]);

    notifyListeners();
  }

  // Get speed label for UI
  String get speedLabel {
    if (_gameSpeed <= 160) return 'Muito Rápido';
    if (_gameSpeed <= 240) return 'Rápido';
    return 'Normal';
  }

  // Get difficulty based on speed setting
  GameDifficulty get difficulty {
    if (_gameSpeed <= 160) return GameDifficulty.veryHard;
    if (_gameSpeed <= 240) return GameDifficulty.hard;
    return GameDifficulty.normal;
  }
}

enum ControlType {
  swipe,
  buttons,
}

enum GameDifficulty {
  normal,
  hard,
  veryHard,
}

extension GameDifficultyExtension on GameDifficulty {
  String get displayName {
    switch (this) {
      case GameDifficulty.normal:
        return 'Normal';
      case GameDifficulty.hard:
        return 'Difícil';
      case GameDifficulty.veryHard:
        return 'Muito Difícil';
    }
  }
}

extension ControlTypeExtension on ControlType {
  String get displayName {
    switch (this) {
      case ControlType.swipe:
        return 'Gestos (deslizar)';
      case ControlType.buttons:
        return 'Botões';
    }
  }

  String get description {
    switch (this) {
      case ControlType.swipe:
        return 'Arraste o dedo na lousa para controlar';
      case ControlType.buttons:
        return 'Use botões direcionais na tela';
    }
  }
}
