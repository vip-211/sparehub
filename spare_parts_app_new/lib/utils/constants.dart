class Constants {
  static const String serverHost = 'sparehub-0t47.onrender.com';
  static const String defaultBase = 'https://$serverHost/api';
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
  static const String logoUrl =
      String.fromEnvironment('LOGO_URL', defaultValue: '');
  static const String googleClientId =
      String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '');
  static const String wsEnableOverride =
      String.fromEnvironment('ENABLE_WS', defaultValue: 'false');
  static bool get enableWebSocket => wsEnableOverride.toLowerCase() == 'true';
  static const String localOtpOverride =
      String.fromEnvironment('FORCE_LOCAL_OTP', defaultValue: 'false');
  static bool get forceLocalOtp => localOtpOverride.toLowerCase() == 'true';

  static const String roleRetailer = 'ROLE_RETAILER';
  static const String roleMechanic = 'ROLE_MECHANIC';
  static const String roleWholesaler = 'ROLE_WHOLESALER';
  static const String roleAdmin = 'ROLE_ADMIN';
  static const String roleStaff = 'ROLE_STAFF';
  static const String roleSuperManager = 'ROLE_SUPER_MANAGER';
}
