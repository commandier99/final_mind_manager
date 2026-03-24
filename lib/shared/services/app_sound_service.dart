import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSoundService {
  AppSoundService._();

  static const String _enabledKey = 'app_sounds_enabled';
  static final AppSoundService instance = AppSoundService._();
  AudioPlayer? _player;

  bool? _cachedEnabled;
  bool _pluginUnavailable = false;

  Future<bool> isEnabled() async {
    final cached = _cachedEnabled;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? true;
    _cachedEnabled = enabled;
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    _cachedEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> playTap() => _playAsset('sounds/tap.wav');
  Future<void> playSuccess() => _playAsset('sounds/success.wav');
  Future<void> playAlert() => _playAsset('sounds/alert.wav');

  Future<void> _playAsset(String assetPath) async {
    if (!await isEnabled()) return;
    if (_pluginUnavailable) {
      await _playFallback();
      return;
    }

    try {
      final player = await _ensurePlayer();
      await player.stop();
      await player.play(AssetSource(assetPath));
    } on MissingPluginException {
      _pluginUnavailable = true;
      await _playFallback();
    } on PlatformException {
      await _playFallback();
    }
  }

  Future<AudioPlayer> _ensurePlayer() async {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer();
    await created.setReleaseMode(ReleaseMode.stop);
    _player = created;
    return created;
  }

  Future<void> _playFallback() async {
    await SystemSound.play(SystemSoundType.alert);
  }
}
