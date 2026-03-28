import '../services/settings_service.dart';

class Constants {
  static String get serverHost => SettingsService.getCachedRemoteSetting(
      'SERVER_HOST', 'sparehub-production.up.railway.app');

  static String get defaultBase => 'https://$serverHost/api';
  static const String baseOverride =
      String.fromEnvironment('BASE_URL', defaultValue: '');
  static String get baseUrl {
    final raw = baseOverride.isNotEmpty ? baseOverride : defaultBase;
    final trimmed = raw.trim();
    final unquoted =
        trimmed.replaceAll(RegExp(r'''^[`'"]+|[`'"]+$'''), '').trim();
    final withoutTrailingSlash = unquoted.endsWith('/')
        ? unquoted.substring(0, unquoted.length - 1)
        : unquoted;
    return withoutTrailingSlash;
  }

  static String get serverUrl {
    final base = baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https'
        ? 'wss'
        : (uri.scheme == 'http' ? 'ws' : uri.scheme);
    final segments = [...uri.pathSegments];
    if (segments.isNotEmpty && segments.first == 'api') {
      segments[0] = 'ws';
    } else if (!segments.contains('ws')) {
      segments.insert(0, 'ws');
    }
    if (segments.isEmpty || segments.last != 'websocket') {
      segments.add('websocket');
    }
    final wsUri = uri.replace(
      scheme: scheme,
      pathSegments: segments,
      query: null,
      fragment: null,
    );
    return wsUri.toString();
  }

  static const bool useRemote = true; // Use remote for Play Store deployment
  static const bool useStandalone =
      false; // Disable standalone mode for real app functionality

  static String get logoUrl => SettingsService.getCachedRemoteSetting(
      'LOGO_URL', String.fromEnvironment('LOGO_URL', defaultValue: ''));

  static String get googleClientId => SettingsService.getCachedRemoteSetting(
      'GOOGLE_CLIENT_ID',
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: ''));

  static bool get enableWebSocket =>
      SettingsService.getCachedRemoteSetting('WS_ENABLED',
          String.fromEnvironment('ENABLE_WS', defaultValue: 'true')) ==
      'true';

  static bool get forceLocalOtp =>
      SettingsService.getCachedRemoteSetting('FORCE_LOCAL_OTP',
          String.fromEnvironment('FORCE_LOCAL_OTP', defaultValue: 'false')) ==
      'true';

  // -------------------------
  // Configurable Auth Paths
  // -------------------------
  static String get resetPasswordPath => SettingsService.getCachedRemoteSetting(
      'RESET_PASSWORD_PATH', '/auth/reset-password');
  static String get altResetPasswordPath =>
      SettingsService.getCachedRemoteSetting(
          'ALT_RESET_PASSWORD_PATH', '/auth/password/reset');
  static String get changePasswordPath =>
      SettingsService.getCachedRemoteSetting(
          'CHANGE_PASSWORD_PATH', '/auth/change-password');
  static String get otpLoginPath => SettingsService.getCachedRemoteSetting(
      'OTP_LOGIN_PATH', '/auth/otp-login');

  static String get locationIdPath => SettingsService.getCachedRemoteSetting(
      'LOCATION_ID_PATH', '/admin/users/{id}/location');
  static String get locationBodyPath => SettingsService.getCachedRemoteSetting(
      'LOCATION_BODY_PATH', '/admin/users/update-location');

  static const String roleRetailer = 'ROLE_RETAILER';
  static const String roleMechanic = 'ROLE_MECHANIC';
  static const String roleWholesaler = 'ROLE_WHOLESALER';
  static const String roleAdmin = 'ROLE_ADMIN';
  static const String roleStaff = 'ROLE_STAFF';
  static const String roleSuperManager = 'ROLE_SUPER_MANAGER';
}
