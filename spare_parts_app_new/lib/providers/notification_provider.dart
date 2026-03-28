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
  bool _initialBannerShown = false;

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

  void init(String roles, {int? userId}) {
    if (_isConnected) return;

    NotificationService.subscribeToTopicsForRole(roles);
    NotificationService.rememberIdentity(roles, userId: userId);
    _wsService.connect(
      (data) {
        _notifications.insert(0, data);
        _unreadCount++;
        _showLocalNotification(data);
        notifyListeners();
      },
      role: roles,
      userId: userId,
    );
    _isConnected = true;
    _fetchNotifications(roles, userId: userId);
  }

  Future<void> refresh(String roles, {int? userId}) async {
    await _fetchNotifications(roles, userId: userId);
  }

  Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'spare_parts_channel',
      'Spare Parts Notifications',
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

  Future<void> _fetchNotifications(String roles, {int? userId}) async {
    final list = await _apiService.getMyNotifications(roles, userId: userId);
    _notifications = list;
    _unreadCount = await _apiService.getUnreadCount();
    if (!_initialBannerShown && _notifications.isNotEmpty) {
      final n = _notifications.first;
      final title = (n['title'] ?? '').toString();
      final body = (n['message'] ?? n['body'] ?? '').toString();
      if (title.isNotEmpty || body.isNotEmpty) {
        NotificationService.showInAppMessage(title, body);
        _initialBannerShown = true;
      }
    }
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    await _apiService.markAllAsRead();
    _unreadCount = 0;
    notifyListeners();
  }

  void disconnect() {
    _wsService.disconnect();
    _isConnected = false;
    _initialBannerShown = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }
}
