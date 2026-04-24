import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'remote_client.dart';

class NotificationService {
  static const String _fcmConfigVersion = '2'; // Increment this to force token refresh
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navKey;
  static final RemoteClient _remote = RemoteClient();
  static Map<String, String?>? _pendingNav;

  static void configureNavigationKey(GlobalKey<NavigatorState> key) {
    _navKey = key;
  }

  static Future<void> initialize() async {
    // 1. Configure local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        const InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (_navKey != null && payload != null) {
          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            final route = data['route'] as String?;
            final offerType = data['offerType'] as String?;
            final role = data['role'] as String?;
            _navigateByRoleThenOffers(role, offerType, route);
          } catch (_) {
            _navKey!.currentState?.pushNamed('/offers');
          }
        }
      },
    );
    final androidSpecific =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidSpecific?.createNotificationChannel(
      const AndroidNotificationChannel(
        'spare_parts_channel',
        'Spare Parts Notifications',
        description: 'Order updates and promotional offers',
        importance: Importance.high,
      ),
    );
    await Permission.notification.request();
    // Android 13+ permission prompt will be handled by the system when needed.

    // 2. Request FCM permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) debugPrint('User granted notification permission');
    }

    // 2b. Handle FCM token refresh (e.g., app reinstall, token rotation)
    _fcm.onTokenRefresh.listen((token) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastUserId = prefs.getInt('last_user_id');
        final lastRolesJson = prefs.getString('last_roles');
        final lastRoleLegacy = prefs.getString('last_role');
        List<String> roles = [];
        if (lastRolesJson != null && lastRolesJson.isNotEmpty) {
          try {
            final decoded = jsonDecode(lastRolesJson);
            if (decoded is List) {
              roles = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {}
        } else if (lastRoleLegacy != null && lastRoleLegacy.isNotEmpty) {
          roles = lastRoleLegacy.split(',').map((e) => e.trim()).toList();
        }
        if (lastUserId != null) {
          await updateTokenOnServer(lastUserId, token);
        }
        if (roles.isNotEmpty) {
          await subscribeToTopicsForRoles(roles);
        }
        if (kDebugMode) {
          debugPrint(
              'FCM token refreshed and synced. Roles=${roles.join(',')} User=$lastUserId');
        }
      } catch (e) {
        debugPrint('Failed handling token refresh: $e');
      }
    });

    // 3. Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        String? route = message.data['route'];
        String? offerType = message.data['offerType'];
        String? role = message.data['role'];
        final String? orderId = message.data['orderId'];
        final String? title =
            message.data['title'] ?? message.notification!.title;
        final String? msg =
            message.data['message'] ?? message.notification!.body;
        final String? imageUrl = message.data['imageUrl'];
        String payloadStr;
        if (route != null) {
          payloadStr = jsonEncode({
            'route': route,
            'offerType': offerType,
            'role': role,
            'orderId': orderId,
            'title': title,
            'message': msg,
            'imageUrl': imageUrl
          });
        } else {
          payloadStr = jsonEncode({
            'route': 'offers',
            'role': role,
            'offerType': offerType,
            'orderId': orderId,
            'title': title,
            'message': msg,
            'imageUrl': imageUrl
          });
        }
        showLocalNotification(
          title ?? 'New Notification',
          msg ?? '',
          payload: payloadStr,
        );
      }
    });

    // 4. Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      String? route = message.data['route'] ?? 'offers';
      String? offerType = message.data['offerType'];
      String? role = message.data['role'];
      final String? orderId = message.data['orderId'];
      final String? title =
          message.data['title'] ?? message.notification?.title;
      final String? msg = message.data['message'] ?? message.notification?.body;
      final String? imageUrl = message.data['imageUrl'];
      _queueOrNavigate(role, offerType, route,
          title: title, message: msg, imageUrl: imageUrl, orderId: orderId);
    });

    // 5. If app was terminated and opened via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      String? route = initialMessage.data['route'] ?? 'offers';
      String? offerType = initialMessage.data['offerType'];
      String? role = initialMessage.data['role'];
      final String? orderId = initialMessage.data['orderId'];
      final String? title =
          initialMessage.data['title'] ?? initialMessage.notification?.title;
      final String? msg =
          initialMessage.data['message'] ?? initialMessage.notification?.body;
      final String? imageUrl = initialMessage.data['imageUrl'];

      _queueOrNavigate(role, offerType, route,
          title: title, message: msg, imageUrl: imageUrl, orderId: orderId);
    }
  }

  static void _queueOrNavigate(String? role, String? offerType, String? route,
      {String? title, String? message, String? imageUrl, String? orderId}) {
    final nav = _navKey?.currentState;
    if (nav == null) {
      _pendingNav = {
        'role': role,
        'offerType': offerType,
        'route': route,
        'title': title,
        'message': message,
        'imageUrl': imageUrl,
        'orderId': orderId,
      };
      return;
    }
    _navigateByRoleThenOffers(role, offerType, route,
        title: title, message: message, imageUrl: imageUrl, orderId: orderId);
  }

  static void tryConsumePendingNavigation() {
    final nav = _navKey?.currentState;
    if (nav == null || _pendingNav == null) return;
    final p = _pendingNav!;
    _pendingNav = null;
    _navigateByRoleThenOffers(
      p['role'],
      p['offerType'],
      p['route'],
      title: p['title'],
      message: p['message'],
      imageUrl: p['imageUrl'],
      orderId: p['orderId'],
    );
  }

  static bool get hasPendingNavigation => _pendingNav != null;

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentVersion = prefs.getString('fcm_config_version');
      
      if (currentVersion != _fcmConfigVersion) {
        if (kDebugMode) debugPrint("NotificationService: Config version mismatch (old: $currentVersion, new: $_fcmConfigVersion). Regenerating token.");
        try {
          await _fcm.deleteToken();
        } catch (e) {
          debugPrint("Error deleting old token: $e");
        }
        await prefs.setString('fcm_config_version', _fcmConfigVersion);
      }
      
      return await _fcm.getToken();
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
      return null;
    }
  }

  static Future<void> updateTokenOnServer(int userId, String token) async {
    try {
      if (kDebugMode)
        debugPrint('NotificationService: Updating FCM token for user $userId');
      final res = await _remote.postJson('/auth/update-fcm-token', {
        'userId': userId,
        'token': token,
      });
      if (res != null) {
        if (kDebugMode)
          debugPrint('NotificationService: FCM token updated successfully');
      } else {
        debugPrint(
            'NotificationService: Failed to update FCM token (null response)');
      }
    } catch (e) {
      debugPrint('NotificationService: Error updating FCM token: $e');
    }
  }

  static void showLocalNotification(String title, String body,
      {String? payload}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'spare_parts_channel',
      'Spare Parts Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotifications.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
    await _saveNotificationLocally(title, body);
  }

  static Future<void> _saveNotificationLocally(
      String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications =
        prefs.getStringList('local_notifications') ?? [];
    Map<String, dynamic> data = {
      'title': title,
      'body': body,
      'createdAt': DateTime.now().toIso8601String(),
    };
    notifications.add(jsonEncode(data));
    await prefs.setStringList('local_notifications', notifications);
  }

  static Future<List<Map<String, dynamic>>> getLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications =
        prefs.getStringList('local_notifications') ?? [];
    return notifications
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList()
        .reversed
        .toList();
  }

  static Future<List<dynamic>> fetchRemoteHistory() async {
    try {
      final res = await _remote.getJson("/notifications/my");
      if (res is List) {
        return res;
      }
    } catch (e) {
      debugPrint("Failed to fetch remote history: $e");
    }
    return [];
  }

  static void _navigateByRoleThenOffers(
      String? role, String? offerType, String? route,
      {String? title, String? message, String? imageUrl, String? orderId}) {
    if (_navKey == null) return;
    final nav = _navKey!.currentState;
    if (nav == null) return;

    // First handle order navigation
    if (route == 'orders' && orderId != null && orderId.isNotEmpty) {
      nav.pushNamed('/orders', arguments: {'orderId': orderId});
      return;
    }

    if (title != null || message != null) {
      final ctx = _navKey!.currentContext;
      if (ctx != null) {
        final text = [if (title != null) title, if (message != null) message]
            .where((e) => e != null && e.isNotEmpty)
            .join(' — ');
        if (text.isNotEmpty) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(text),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
    String? targetRoute = route;
    if ((targetRoute == null || targetRoute.isEmpty) && role != null) {
      targetRoute = 'offers';
    }
    if (role != null) {
      String r = role.toUpperCase();
      if (r.startsWith('ROLE_')) r = r.substring(5);
      if (r == 'RETAILER') {
        nav.pushNamed('/dashboard/retailer', arguments: {
          'offerType': offerType,
          'title': title,
          'message': message,
          'imageUrl': imageUrl
        });
      } else if (r == 'MECHANIC') {
        nav.pushNamed('/dashboard/mechanic', arguments: {
          'offerType': offerType,
          'title': title,
          'message': message,
          'imageUrl': imageUrl
        });
      } else if (r == 'WHOLESALER') {
        nav.pushNamed('/dashboard/wholesaler', arguments: {
          'offerType': offerType,
          'title': title,
          'message': message,
          'imageUrl': imageUrl
        });
      } else if (r == 'ADMIN' || r == 'SUPER_MANAGER') {
        nav.pushNamed('/dashboard/admin', arguments: {
          'offerType': offerType,
          'title': title,
          'message': message,
          'imageUrl': imageUrl
        });
      } else if (r == 'STAFF') {
        nav.pushNamed('/dashboard/staff', arguments: {
          'offerType': offerType,
          'title': title,
          'message': message,
          'imageUrl': imageUrl
        });
      }
    }
    if (targetRoute == 'offers') {
      nav.pushNamed('/offers', arguments: {
        'offerType': offerType,
        'title': title,
        'message': message,
        'imageUrl': imageUrl
      });
    }
  }

  // Compatibility methods for NotificationProvider
  Future<List<Map<String, dynamic>>> getMyNotifications(String role,
      {int? userId}) async {
    final remote = await fetchRemoteHistory();
    final local = await getLocalHistory();
    return [...remote.map((e) => e as Map<String, dynamic>), ...local];
  }

  static Future<void> rememberIdentity(String role, {int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_role', role);
      // Also store normalized roles array for multiple roles
      final roles = role
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await prefs.setString('last_roles', jsonEncode(roles));
      if (userId != null) {
        await prefs.setInt('last_user_id', userId);
      }
    } catch (_) {}
  }

  static Future<void> attemptPendingFcmSync({int? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingUser = prefs.getInt('pending_fcm_user');
      final pendingToken = prefs.getString('pending_fcm_token');
      if (pendingToken != null && (pendingUser != null || userId != null)) {
        final uid = userId ?? pendingUser!;
        await updateTokenOnServer(uid, pendingToken);
      }
    } catch (_) {}
  }

  static Future<void> subscribeToTopicsForRole(String role) async {
    try {
      final r = role.trim();
      if (r.contains(',')) {
        final list = r
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        await subscribeToTopicsForRoles(list);
        return;
      }
      await _fcm.subscribeToTopic('all-users');
      await _fcm.subscribeToTopic('role-$r');
    } catch (e) {
      debugPrint('Error subscribing to topics: $e');
    }
  }

  static Future<void> subscribeToTopicsForRoles(List<String> roles) async {
    try {
      await _fcm.subscribeToTopic('all-users');
      for (final r in roles) {
        if (r.isNotEmpty) {
          // Normalize role name: remove ROLE_ prefix if present and convert to uppercase for consistency
          String topicName = r.replaceAll('ROLE_', '').toUpperCase();

          // Subscribe to both formats just in case backend uses different ones
          await _fcm.subscribeToTopic('role-$r');
          await _fcm.subscribeToTopic('role-$topicName');

          if (kDebugMode) {
            debugPrint('Subscribed to topics: role-$r and role-$topicName');
          }
        }
      }
    } catch (e) {
      debugPrint('Error subscribing to multi-role topics: $e');
    }
  }

  static void showInAppMessage(String title, String body) {
    if (_navKey == null) return;
    final ctx = _navKey!.currentContext;
    if (ctx == null) return;
    final text = [if (title.isNotEmpty) title, if (body.isNotEmpty) body]
        .where((e) => e.isNotEmpty)
        .join(' — ');
    if (text.isEmpty) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _remote.getJson("/notifications/unread-count");
      return (res as num).toInt();
    } catch (e) {
      debugPrint("Failed to get unread count: $e");
    }
    return 0;
  }

  Future<void> markAllAsRead() async {
    try {
      await _remote.postJson("/notifications/mark-all-read", {});
    } catch (e) {
      debugPrint("Failed to mark all as read: $e");
    }
  }

  Future<void> sendNotification(String title, String message, String targetRole,
      {String? imageUrl, String? offerType, String route = 'offers'}) async {
    try {
      String endpoint = targetRole == 'ALL'
          ? "/notifications/send/broadcast"
          : "/notifications/send/role/$targetRole";

      await _remote.postJson(endpoint, {
        "title": title,
        "message": message,
        "route": route,
        if (offerType != null) "offerType": offerType,
        if (imageUrl != null) "imageUrl": imageUrl,
      });
    } catch (e) {
      debugPrint("Failed to send notification: $e");
    }
  }
}
