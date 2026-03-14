import 'package:shared_preferences/shared_preferences.dart';
import 'remote_client.dart';
import '../utils/constants.dart';

class SettingsService {
  static final _remote = RemoteClient();
  static const _voiceTrainingKey = 'voice_training_enabled';
  static const _aiChatbotKey = 'ai_chatbot_enabled';
  static const _websocketKey = 'websocket_enabled';
  static const _forceLocalOtpKey = 'force_local_otp';

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
    } catch (_) {}
  }
}
