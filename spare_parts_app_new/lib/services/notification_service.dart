import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import './db_universal.dart';
import './remote_client.dart';
import '../utils/constants.dart';

class NotificationService {
  final DatabaseService _dbService = DatabaseService();
  final RemoteClient _remote = RemoteClient();

  // ===============================
  // SEND NOTIFICATION
  // ===============================

  Future<void> sendNotification(
    String title,
    String message,
    String targetRole, {
    String? imageUrl,
  }) async {
    try {
      if (Constants.useRemote) {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');

        if (userStr == null) return;

        final user = jsonDecode(userStr);
        final token = user['token'];

        await http.post(
          Uri.parse('${Constants.baseUrl}/notifications'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'title': title,
            'message': message,
            'targetRole': targetRole,
            'imageUrl': imageUrl,
          }),
        );

        return;
      }

      final db = await _dbService.database;

      await db.insert('notifications', {
        'title': title,
        'message': message,
        'targetRole': targetRole,
        'imageUrl': imageUrl,
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': 0,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Send notification error: $e');
      }
    }
  }

  // ===============================
  // GET MY NOTIFICATIONS
  // ===============================

  Future<List<Map<String, dynamic>>> getMyNotifications(String myRole) async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/notifications/my?role=$myRole');
        return list.cast<Map<String, dynamic>>();
      }

      final db = await _dbService.database;

      return await db.query(
        'notifications',
        where: 'targetRole = ? OR targetRole = "ALL"',
        whereArgs: [myRole],
        orderBy: 'createdAt DESC',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Get notifications error: $e');
      }
      return [];
    }
  }

  // ===============================
  // READ ACTIONS
  // ===============================

  Future<void> markAllAsRead() async {
    try {
      if (Constants.useRemote) {
        await _remote.postJson('/notifications/read-all', {});
        return;
      }

      final db = await _dbService.database;
      await db.update('notifications', {'isRead': 1});
    } catch (e) {
      if (kDebugMode) debugPrint('Mark all as read error: $e');
    }
  }

  Future<int> getUnreadCount(String myRole) async {
    try {
      if (Constants.useRemote) {
        final res =
            await _remote.getJson('/notifications/unread-count?role=$myRole');
        if (res != null && res['count'] != null) {
          return (res['count'] as num).toInt();
        }
        return 0;
      }

      final db = await _dbService.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE (targetRole = ? OR targetRole = "ALL") AND isRead = 0',
        [myRole],
      );
      if (result.isEmpty) return 0;
      return (result.first['count'] as num).toInt();
    } catch (e) {
      return 0;
    }
  }
}
