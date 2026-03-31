import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'remote_client.dart';
import '../utils/constants.dart';

class SettingsService {
  static final _remote = RemoteClient();
  static final StreamController<String> _settingsChangedController =
      StreamController<String>.broadcast();
  static Stream<String> get onSettingsChanged =>
      _settingsChangedController.stream;

  static Future<void> checkAppUpdate(BuildContext context) async {
    try {
      final latestVersion = getCachedRemoteSetting('LATEST_APP_VERSION', '1.0.0');
      final updateUrl = getCachedRemoteSetting('APP_UPDATE_URL', '');
      
      if (updateUrl.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isVersionNewer(currentVersion, latestVersion)) {
        if (!context.mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Update Available'),
            content: Text('A newer version ($latestVersion) of the app is available. Please update to continue using the latest features.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(updateUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('SettingsService: Error checking app update: $e');
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }
    } catch (_) {}
    return false;
  }

  static const _voiceTrainingKey = 'voice_training_enabled';
  static const _aiChatbotKey = 'ai_chatbot_enabled';
  static const _websocketKey = 'websocket_enabled';
  static const _forceLocalOtpKey = 'force_local_otp';
  static const _themeModeKey = 'theme_mode'; // system | light | dark
  static const _themeSeedKey = 'theme_seed_color'; // int value
  static const _textScaleKey = 'text_scale'; // double
  static const _animationSpeedKey = 'animation_speed'; // double multiplier
  static const _batteryPromptKey = 'battery_prompt_shown';

  static Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  static Future<bool> isVoiceTrainingEnabled() async {
    final p = await _prefs();
    return p.getBool(_voiceTrainingKey) ?? true;
  }

  static Future<void> setVoiceTrainingEnabled(bool v) async {
    final p = await _prefs();
    await p.setBool(_voiceTrainingKey, v);
  }

  static Future<bool> isAiChatbotEnabled() async {
    final p = await _prefs();
    return p.getBool(_aiChatbotKey) ?? true;
  }

  static Future<void> setAiChatbotEnabled(bool v) async {
    final p = await _prefs();
    await p.setBool(_aiChatbotKey, v);
  }

  static Future<bool> isWebSocketEnabled() async {
    final p = await _prefs();
    return p.getBool(_websocketKey) ?? false;
  }

  static Future<void> setWebSocketEnabled(bool v) async {
    final p = await _prefs();
    await p.setBool(_websocketKey, v);
  }

  static Future<bool> isForceLocalOtp() async {
    final p = await _prefs();
    return p.getBool(_forceLocalOtpKey) ?? false;
  }

  static Future<void> setForceLocalOtp(bool v) async {
    final p = await _prefs();
    await p.setBool(_forceLocalOtpKey, v);
  }

  static Future<String> getThemeMode() async {
    final p = await _prefs();
    return p.getString(_themeModeKey) ?? 'system';
  }

  static Future<void> setThemeMode(String mode) async {
    final p = await _prefs();
    await p.setString(_themeModeKey, mode);
  }

  static Future<int?> getThemeSeedColor() async {
    final p = await _prefs();
    return p.getInt(_themeSeedKey);
  }

  static Future<void> setThemeSeedColor(int value) async {
    final p = await _prefs();
    await p.setInt(_themeSeedKey, value);
  }

  static Future<double> getTextScale() async {
    final p = await _prefs();
    return p.getDouble(_textScaleKey) ?? 1.0;
  }

  static Future<void> setTextScale(double v) async {
    final p = await _prefs();
    await p.setDouble(_textScaleKey, v);
  }

  static Future<double> getAnimationSpeed() async {
    final p = await _prefs();
    return p.getDouble(_animationSpeedKey) ?? 1.0;
  }

  static Future<void> setAnimationSpeed(double v) async {
    final p = await _prefs();
    await p.setDouble(_animationSpeedKey, v);
  }

  static Future<bool> isBatteryPromptShown() async {
    final p = await _prefs();
    return p.getBool(_batteryPromptKey) ?? false;
  }

  static Future<void> setBatteryPromptShown(bool v) async {
    final p = await _prefs();
    await p.setBool(_batteryPromptKey, v);
  }

  static Map<String, String> _remoteCache = {};

  static Future<void> preloadRemoteSettings() async {
    _remoteCache = await getRemoteSettings();
  }

  static String getCachedRemoteSetting(String key, String defaultValue) {
    return _remoteCache[key] ?? defaultValue;
  }

  static Future<Map<String, String>> getRemoteSettings() async {
    if (!Constants.useRemote) return {};
    try {
      final list = await _remote.getList('/admin/settings');
      final Map<String, String> res = {};
      for (var item in list) {
        final m = item as Map<String, dynamic>;
        res[m['settingKey']] = m['settingValue'];
      }
      return res;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveRemoteSetting(String key, String value) async {
    if (!Constants.useRemote) return;
    try {
      await _remote.postJson('/admin/settings', {
        'settingKey': key,
        'settingValue': value,
      });
      _remoteCache[key] = value;
      _settingsChangedController.add(key);
    } catch (e) {
      debugPrint('SettingsService: Error saving remote setting $key: $e');
    }
  }

  static Future<void> saveRemoteSettingsBulk(Map<String, String> settings) async {
    if (!Constants.useRemote) return;
    try {
      final List<Map<String, String>> payload = settings.entries.map((e) => {
        'settingKey': e.key,
        'settingValue': e.value,
      }).toList();
      
      await _remote.postJson('/admin/settings/bulk', payload);
      _remoteCache.addAll(settings);
      for (var key in settings.keys) {
        _settingsChangedController.add(key);
      }
    } catch (e) {
      debugPrint('SettingsService: Error saving bulk remote settings: $e');
      rethrow;
    }
  }

  static const _lastOtpErrorMsgKey = 'last_otp_error_msg';
  static const _lastOtpErrorAtKey = 'last_otp_error_at';

  static Future<void> setLastOtpFailure(String message) async {
    final p = await _prefs();
    await p.setString(_lastOtpErrorMsgKey, message);
    await p.setInt(_lastOtpErrorAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>?> getLastOtpFailure() async {
    final p = await _prefs();
    final msg = p.getString(_lastOtpErrorMsgKey);
    final at = p.getInt(_lastOtpErrorAtKey);
    if (msg == null || at == null) return null;
    return {'message': msg, 'at': at};
  }

  static Future<void> clearLastOtpFailure() async {
    final p = await _prefs();
    await p.remove(_lastOtpErrorMsgKey);
    await p.remove(_lastOtpErrorAtKey);
  }
}
