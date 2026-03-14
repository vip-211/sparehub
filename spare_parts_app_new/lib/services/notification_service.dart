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
}
