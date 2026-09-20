import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'settings_service.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _eatSoundPlayer = AudioPlayer();
  final AudioPlayer _hitSoundPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();
  
  SettingsService? _settings;
  bool _initialized = false;
  bool _musicPlaying = false;

  void initialize(SettingsService settings) {
    _settings = settings;
    _initialized = true;
  }

  // Sound Effects
  Future<void> playEatFood() async {
    if (!_initialized || !(_settings?.soundEnabled ?? false)) return;
    
    try {
      print('🎵 Attempting to play eat sound');
      await _eatSoundPlayer.play(AssetSource('sounds/eat.wav'));
      print('✅ Successfully played eat sound');
    } catch (e) {
      print('❌ Failed to play eat.wav: $e');
      // Multiple fallback attempts
      try {
        // Try system sound fallback
        await SystemSound.play(SystemSoundType.click);
        print('🔄 Used system sound fallback');
      } catch (e2) {
        print('❌ All audio methods failed: $e2');
        // At least provide haptic feedback as audio substitute
        if (_settings?.vibrationEnabled ?? false) {
          await HapticFeedback.lightImpact();
        }
      }
    }
    
    // Add vibration feedback regardless of audio success
    if (_settings?.vibrationEnabled ?? false) {
      await _vibrate(duration: 50);
    }
  }



  Future<void> playGameOver() async {
    if (!_initialized || !(_settings?.soundEnabled ?? false)) return;
    
    try {
      print('🎵 Attempting to play hit.mp3');
      await _hitSoundPlayer.play(AssetSource('sounds/hit.mp3'));
      print('✅ Successfully played hit.mp3');
    } catch (e) {
      print('❌ Failed to play hit.mp3: $e');
      // Fallback to system sound if file not found
      try {
        SystemSound.play(SystemSoundType.alert);
        print('🔄 Used system sound fallback');
      } catch (e2) {
        print('❌ System sound also failed: $e2');
      }
    }
    
    // Stronger vibration for game over
    if (_settings?.vibrationEnabled ?? false) {
      await _vibrate(duration: 200);
    }
  }

  Future<void> playButtonClick() async {
    if (!_initialized || !(_settings?.soundEnabled ?? false)) return;
    
    try {
      // Use eat sound for button clicks or just haptic feedback
      // Light haptic feedback for button presses
      if (_settings?.vibrationEnabled ?? false) {
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Fallback to system sound if file not found
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> playDirectionChange() async {
    if (!_initialized || !(_settings?.soundEnabled ?? false)) return;
    
    try {
      // Very subtle feedback for direction changes
      if (_settings?.vibrationEnabled ?? false) {
        await HapticFeedback.selectionClick();
      }
    } catch (e) {
      print('Audio error (direction change): $e');
    }
  }

  Future<void> playPause() async {
    if (!_initialized || !(_settings?.soundEnabled ?? false)) return;
    
    try {
      // Just haptic feedback for pause
      if (_settings?.vibrationEnabled ?? false) {
        await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Fallback to system sound if file not found
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> playVictory() async {
    if (!_initialized || !(_settings?.soundEnabled ?? false)) return;
    try {
      if (_settings?.vibrationEnabled ?? false) {
        await HapticFeedback.heavyImpact();
      }
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      // Fallback
    }
  }

  // Background Music
  Future<void> startBackgroundMusic() async {
    if (!_initialized || !(_settings?.musicEnabled ?? false) || _musicPlaying) return;
    
    try {
      print('🎵 Attempting to play backg1.mp3');
      await _musicPlayer.play(AssetSource('sounds/backg1.mp3'));
      await _musicPlayer.setReleaseMode(ReleaseMode.loop); // Loop the background music
      _musicPlaying = true;
      print('✅ Successfully started background music');
    } catch (e) {
      print('❌ Failed to play backg2.mp3: $e');
      _musicPlaying = false;
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      _musicPlaying = false;
    } catch (e) {
      // Silent failure
      _musicPlaying = false;
    }
  }

  Future<void> pauseBackgroundMusic() async {
    if (!_musicPlaying) return;
    
    try {
      await _musicPlayer.pause();
    } catch (e) {
      // Silent failure
    }
  }

  Future<void> resumeBackgroundMusic() async {
    if (!_initialized || !(_settings?.musicEnabled ?? false) || !_musicPlaying) return;
    
    try {
      await _musicPlayer.resume();
    } catch (e) {
      // Silent failure
    }
  }

  // Vibration helpers - using haptic feedback for now
  Future<void> _vibrate({int duration = 100}) async {
    if (!(_settings?.vibrationEnabled ?? false)) return;
    
    try {
      // Use haptic feedback as vibration substitute for now
      if (duration > 150) {
        await HapticFeedback.heavyImpact();
      } else if (duration > 75) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      print('Haptic error: $e');
    }
  }

  // Haptic feedback wrappers (they respect vibration setting)
  Future<void> lightHaptic() async {
    if (_settings?.vibrationEnabled ?? false) {
      try {
        await HapticFeedback.lightImpact();
      } catch (e) {
        print('Haptic error: $e');
      }
    }
  }

  Future<void> mediumHaptic() async {
    if (_settings?.vibrationEnabled ?? false) {
      try {
        await HapticFeedback.mediumImpact();
      } catch (e) {
        print('Haptic error: $e');
      }
    }
  }

  Future<void> heavyHaptic() async {
    if (_settings?.vibrationEnabled ?? false) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (e) {
        print('Haptic error: $e');
      }
    }
  }

  Future<void> selectionHaptic() async {
    if (_settings?.vibrationEnabled ?? false) {
      try {
        await HapticFeedback.selectionClick();
      } catch (e) {
        print('Haptic error: $e');
      }
    }
  }

  // Cleanup
  void dispose() {
    _eatSoundPlayer.dispose();
    _hitSoundPlayer.dispose();
    _musicPlayer.dispose();
  }
}
