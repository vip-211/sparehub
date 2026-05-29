import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'remote_client.dart';

class UserActivityService {
  static final UserActivityService _instance = UserActivityService._internal();
  factory UserActivityService() => _instance;
  UserActivityService._internal();

  final RemoteClient _client = RemoteClient();
  int? _currentSessionId;
  bool _isTracking = false;

  Future<void> startSession() async {
    if (_isTracking) return;
    
    try {
      final deviceInfo = await _getDeviceInfo();
      final packageInfo = await PackageInfo.fromPlatform();
      
      final response = await _client.postJson(
        '/user-activities/start-session',
        null,
        queryParameters: {
          'deviceInfo': deviceInfo,
          'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
        },
      );
      
      if (response != null && response['id'] != null) {
        _currentSessionId = response['id'];
        _isTracking = true;
      }
    } catch (e) {
      print('UserActivityService: Failed to start session: $e');
    }
  }

  Future<void> endSession() async {
    if (!_isTracking || _currentSessionId == null) return;
    
    try {
      await _client.putJson(
        '/user-activities/end-session/$_currentSessionId',
        null,
      );
    } catch (e) {
      print('UserActivityService: Failed to end session: $e');
    } finally {
      _currentSessionId = null;
      _isTracking = false;
    }
  }

  Future<String> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String info = '';
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      info = 'Android ${androidInfo.version.release} - ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      info = 'iOS ${iosInfo.systemVersion} - ${iosInfo.utsname.machine}';
    } else if (Platform.isWindows) {
      final windowsInfo = await deviceInfoPlugin.windowsInfo;
      info = 'Windows ${windowsInfo.productName}';
    } else if (Platform.isMacOS) {
      final macOsInfo = await deviceInfoPlugin.macOsInfo;
      info = 'macOS ${macOsInfo.osRelease}';
    } else if (Platform.isLinux) {
      final linuxInfo = await deviceInfoPlugin.linuxInfo;
      info = 'Linux ${linuxInfo.name}';
    }
    
    return info;
  }
}
