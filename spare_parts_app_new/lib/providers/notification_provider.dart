import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final WebSocketService _wsService = WebSocketService();
  final NotificationService _apiService = NotificationService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _notifications = [];
  bool _isConnected = false;
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isConnected => _isConnected;
  int get unreadCount => _unreadCount;

  NotificationProvider() {
    _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotifications.initialize(initializationSettings);
  }

  void init(String role) {
    if (_isConnected) return;

    _wsService.connect((data) {
      _notifications.insert(0, data);
      _unreadCount++;
      _showLocalNotification(data);
      notifyListeners();
    });
    _isConnected = true;
    _fetchNotifications(role);
  }

  Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sparehub_notifications',
      'SpareHub Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      DateTime.now().millisecond,
      data['title'] ?? 'New Notification',
      data['message'] ?? '',
      platformChannelSpecifics,
    );
  }

  Future<void> _fetchNotifications(String role) async {
    final list = await _apiService.getMyNotifications(role);
    _notifications = list;
    _unreadCount = await _apiService.getUnreadCount(role);
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _apiService.markAllAsRead();
    _unreadCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }
}
