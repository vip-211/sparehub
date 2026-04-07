import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import '../services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light; // Force light mode
  ThemeMode get themeMode => _mode;
  Color _seed = const Color.fromARGB(255, 231, 162, 226);
  Color get seedColor => _seed;
  double _textScale = 1.0;
  double get textScale => _textScale;
  double _animationSpeed = 1.0;
  double get animationSpeed => _animationSpeed;

  ThemeProvider() {
    _load();
    SettingsService.onSettingsChanged.listen((key) {
      if (key == 'THEME_SEED_COLOR' || key == 'USE_GLOBAL_THEME_COLOR') {
        _load();
      }
    });
  }

  Future<void> _load() async {
    // Ignore saved theme mode and always use light
    _mode = ThemeMode.light;
    final seed = await SettingsService.getThemeSeedColor();
    if (seed != null) _seed = Color(seed);
    try {
      final useGlobal = SettingsService.getCachedRemoteSetting(
              'USE_GLOBAL_THEME_COLOR', 'false') ==
          'true';
      if (useGlobal) {
        final remoteSeedStr =
            SettingsService.getCachedRemoteSetting('THEME_SEED_COLOR', '');
        if (remoteSeedStr.isNotEmpty) {
          final val = int.parse(remoteSeedStr);
          _seed = Color(val);
        }
      }
    } catch (_) {}
    _textScale = await SettingsService.getTextScale();
    _animationSpeed = await SettingsService.getAnimationSpeed();
    timeDilation = _animationSpeed;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    // Do nothing to prevent changing from light mode
  }

  Future<void> setSeedColor(Color color) async {
    _seed = color;
    notifyListeners();
    await SettingsService.setThemeSeedColor(color.value);
  }

  Future<void> setTextScale(double v) async {
    _textScale = v;
    notifyListeners();
    await SettingsService.setTextScale(v);
  }

  Future<void> setAnimationSpeed(double v) async {
    _animationSpeed = v;
    timeDilation = v;
    notifyListeners();
    await SettingsService.setAnimationSpeed(v);
  }

  Future<bool> refreshSeedFromServer() async {
    try {
      await SettingsService.preloadRemoteSettings();
      final useGlobal = SettingsService.getCachedRemoteSetting(
              'USE_GLOBAL_THEME_COLOR', 'false') ==
          'true';
      if (useGlobal) {
        final remoteSeedStr =
            SettingsService.getCachedRemoteSetting('THEME_SEED_COLOR', '');
        if (remoteSeedStr.isEmpty) {
          return false;
        }
        final val = int.parse(remoteSeedStr);
        _seed = Color(val);
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  ThemeMode _strToMode(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
