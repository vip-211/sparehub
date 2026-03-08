import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bcrypt/bcrypt.dart';

import '../models/user.dart';
import '../services/db_universal.dart';
import '../services/email_service.dart';
import '../services/sso_mobile.dart';
import '../services/remote_client.dart';
import '../utils/constants.dart';

class AuthService {
  final DatabaseService _dbService = DatabaseService();
  final EmailService _emailService = EmailService();
  final GoogleSSO _googleSSO = GoogleSSO();
  final RemoteClient _remote = RemoteClient();

  String? _otp;

  Future<SharedPreferences> _prefs() async {
    return await SharedPreferences.getInstance();
  }

  // =============================
  // LOGIN
  // =============================

  Future<User?> login(String email, String password) async {
    try {
      if (Constants.useRemote) {
        final res = await http.post(
          Uri.parse('${Constants.baseUrl}/auth/signin'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );
        if (res.statusCode == 401 || res.statusCode == 403) {
          final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
          final msg = body is Map
              ? (body['message'] ??
                  body['error'] ??
                  'Invalid email or password')
              : 'Invalid email or password';
          throw Exception(msg.toString());
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw 'HTTP ${res.statusCode}: ${res.body}';
        }
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final token = json['token'] ?? json['accessToken'];
        final id = (json['id'] as num).toInt();
        final emailVal = json['email'] as String;
        final name = json['username'] ?? json['name'] ?? emailVal;
        final roles = (json['roles'] as List).map((e) => e.toString()).toList();
        final status = (json['status'] ?? 'ACTIVE').toString();
        if (status != 'ACTIVE') {
          throw Exception('Your account is not active yet.');
        }
        final user = User(
          id: id,
          email: emailVal,
          name: name,
          phone: null,
          token: token.toString(),
          roles: roles,
          address: null,
          shopImagePath: null,
          status: status,
          latitude: null,
          longitude: null,
        );
        final prefs = await _prefs();
        await prefs.setString('user', jsonEncode(user.toJson()));
        return user;
      }

      final db = await _dbService.database;
      final result = await db.query(
        "users",
        where: "email = ?",
        whereArgs: [email],
      );

      if (result.isEmpty) {
        throw "User not found";
      }

      final userData = result.first;
      final storedPassword = userData["password"] as String;

      if (!BCrypt.checkpw(password, storedPassword)) {
        throw "Invalid password";
      }
      final status = (userData["status"] as String?) ?? 'ACTIVE';
      if (status != 'ACTIVE') {
        throw "Your account is not active yet.";
      }

      final user = User(
        id: userData["id"] as int,
        email: userData["email"] as String,
        name: userData["name"] as String?,
        phone: userData["phone"] as String?,
        token: "local-token",
        roles: [userData["role"] as String],
        address: userData["address"] as String?,
        shopImagePath: userData["shopImagePath"] as String?,
        status: status,
        latitude: userData["latitude"] as double?,
        longitude: userData["longitude"] as double?,
      );

      final prefs = await _prefs();
      await prefs.setString("user", jsonEncode(user.toJson()));

      return user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Login error: $e");
      }
      rethrow;
    }
  }

  Future<User?> loginWithOtp(String email, String otp) async {
    try {
      if (Constants.useRemote) {
        final res = await http.post(
          Uri.parse('${Constants.baseUrl}/auth/otp-login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'otp': otp}),
        );
        if (res.statusCode < 200 || res.statusCode >= 300) {
          final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
          final msg = body is Map
              ? (body['message'] ?? body['error'] ?? 'OTP verification failed')
              : 'OTP verification failed';
          throw Exception(msg.toString());
        }
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final token = json['token'] ?? json['accessToken'];
        final id = (json['id'] as num).toInt();
        final emailVal = json['email'] as String;
        final name = json['username'] ?? json['name'] ?? emailVal;
        final roles = (json['roles'] as List).map((e) => e.toString()).toList();
        final status = (json['status'] ?? 'ACTIVE').toString();
        if (status != 'ACTIVE') {
          throw Exception('Your account is not active yet.');
        }
        final user = User(
          id: id,
          email: emailVal,
          name: name,
          phone: null,
          token: token.toString(),
          roles: roles,
          address: null,
          shopImagePath: null,
          status: status,
          latitude: null,
          longitude: null,
        );
        final prefs = await _prefs();
        await prefs.setString('user', jsonEncode(user.toJson()));
        return user;
      } else {
        // Local OTP login not supported in standalone
        throw Exception("OTP login not available in local mode");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("OTP login error: $e");
      }
      rethrow;
    }
  }

  // =============================
  // LOGOUT
  // =============================

  Future<void> logout() async {
    final prefs = await _prefs();
    await prefs.remove("user");

    await _googleSSO.signOut();
  }

  // =============================
  // CURRENT USER
  // =============================

  Future<User?> getCurrentUser() async {
    final prefs = await _prefs();

    final userStr = prefs.getString("user");

    if (userStr == null) return null;

    return User.fromJson(jsonDecode(userStr));
  }

  // =============================
  // REGISTER
  // =============================

  Future<bool> register(
    String name,
    String email,
    String password,
    String role,
    String phone,
    String address, {
    double? latitude,
    double? longitude,
    String? otp,
  }) async {
    if (Constants.useRemote) {
      final body = {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone ?? '',
        'address': address ?? '',
        'role': _mapRoleForBackend(role),
      };
      if (otp != null && otp.isNotEmpty) body['otp'] = otp;

      final res = await http.post(
        Uri.parse('${Constants.baseUrl}/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 400) {
        final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
        final msg = decoded is Map
            ? (decoded['message'] ?? 'Registration failed')
            : res.body;
        throw Exception(msg.toString());
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw 'HTTP ${res.statusCode}: ${res.body}';
      }
      return true;
    }

    final db = await _dbService.database;
    final existing = await db.query(
      "users",
      where: "email = ?",
      whereArgs: [email],
    );

    if (existing.isNotEmpty) {
      throw "User already exists";
    }

    final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

    await db.insert("users", {
      "name": name,
      "email": email,
      "password": hashedPassword,
      "role": role,
      "phone": phone,
      "address": address,
      "status": "ACTIVE",
      "latitude": latitude,
      "longitude": longitude,
    });

    return true;
  }

  String _mapRoleForBackend(String role) {
    if (role == Constants.roleAdmin) return 'admin';
    if (role == Constants.roleWholesaler) return 'wholesaler';
    if (role == Constants.roleRetailer) return 'retailer';
    if (role == Constants.roleMechanic) return 'mechanic';
    if (role == Constants.roleStaff) return 'staff';
    if (role == Constants.roleSuperManager) return 'super_manager';
    return 'mechanic';
  }

  // =============================
  // UPDATE ADDRESS
  // =============================

  Future<void> updateUserAddress(int userId, String address) async {
    final db = await _dbService.database;

    await db.update(
      "users",
      {"address": address},
      where: "id = ?",
      whereArgs: [userId],
    );
  }

  // =============================
  // UPDATE SHOP IMAGE
  // =============================

  Future<void> updateUserShopImage(int userId, String path) async {
    final db = await _dbService.database;

    await db.update(
      "users",
      {"shopImagePath": path},
      where: "id = ?",
      whereArgs: [userId],
    );
  }

  // =============================
  // UPDATE PROFILE
  // =============================

  Future<User> updateUserProfile(
    int userId,
    String name,
    String phone,
    String address,
  ) async {
    final db = await _dbService.database;

    await db.update(
      "users",
      {"name": name, "phone": phone, "address": address},
      where: "id = ?",
      whereArgs: [userId],
    );

    final result = await db.query(
      "users",
      where: "id = ?",
      whereArgs: [userId],
    );

    final updated = result.first;

    final user = User(
      id: updated["id"] as int,
      email: updated["email"] as String,
      name: updated["name"] as String?,
      phone: updated["phone"] as String?,
      token: "local-token",
      roles: [updated["role"] as String],
      address: updated["address"] as String?,
      shopImagePath: updated["shopImagePath"] as String?,
      latitude: updated["latitude"] as double?,
      longitude: updated["longitude"] as double?,
    );

    final prefs = await _prefs();
    await prefs.setString("user", jsonEncode(user.toJson()));

    return user;
  }

  // =============================
  // SEND OTP
  // =============================

  Future<String> sendOtp(
    String email,
    Map<String, dynamic> registrationData,
  ) async {
    if (Constants.useRemote && !Constants.forceLocalOtp) {
      final res = await http.post(
        Uri.parse('${Constants.baseUrl}/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // Fallback to local email if server fails
        _otp = (100000 + Random().nextInt(900000)).toString();
        await _emailService.sendOtp(email, _otp!);
        return 'email';
      }
      _otp = null; // Backend stores OTP, we don't need local
      return 'server';
    }
    _otp = (100000 + Random().nextInt(900000)).toString();
    await _emailService.sendOtp(email, _otp!);
    return 'email';
  }

  Future<void> sendPasswordResetOtp(String email) async {
    if (Constants.useRemote && !Constants.forceLocalOtp) {
      await sendOtp(email, {});
      return;
    }
    _otp = (100000 + Random().nextInt(900000)).toString();
    await _emailService.sendOtp(email, _otp!);
  }

  // =============================
  // VERIFY OTP
  // =============================

  Future<bool> verifyOtp(String otp) async {
    return _otp == otp;
  }

  // =============================
  // RESET PASSWORD
  // =============================

  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    if (_otp != otp) {
      throw "Invalid OTP";
    }

    final db = await _dbService.database;

    final hashed = BCrypt.hashpw(newPassword, BCrypt.gensalt());

    await db.update(
      "users",
      {"password": hashed},
      where: "email = ?",
      whereArgs: [email],
    );
    return true;
  }

  // =============================
  // GOOGLE LOGIN
  // =============================

  Future<User?> signInWithGoogle(String email, String name) async {
    try {
      if (Constants.useRemote) {
        final res = await http.post(
          Uri.parse('${Constants.baseUrl}/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'name': name}),
        );
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw 'Google sign-in failed: ${res.body}';
        }
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final token = json['token'] ?? json['accessToken'];
        final id = (json['id'] as num).toInt();
        final emailVal = json['email'] as String;
        final userName = json['username'] ?? json['name'] ?? name;
        final roles = (json['roles'] as List).map((e) => e.toString()).toList();
        final user = User(
          id: id,
          email: emailVal,
          name: userName,
          phone: null,
          token: token.toString(),
          roles: roles,
          address: null,
          shopImagePath: null,
          status: json['status'],
          latitude: null,
          longitude: null,
        );
        final prefs = await _prefs();
        await prefs.setString('user', jsonEncode(user.toJson()));
        return user;
      }

      final db = await _dbService.database;
      final maps = await db.query(
        "users",
        where: "email = ?",
        whereArgs: [email],
      );

      if (maps.isNotEmpty) {
        final userData = maps.first;
        final user = User(
          id: userData["id"] as int,
          email: userData["email"] as String,
          name: userData["name"] as String?,
          phone: userData["phone"] as String?,
          token: "google-token",
          roles: [userData["role"] as String],
          address: userData["address"] as String?,
          shopImagePath: userData["shopImagePath"] as String?,
          latitude: userData["latitude"] != null
              ? (userData["latitude"] as num).toDouble()
              : null,
          longitude: userData["longitude"] != null
              ? (userData["longitude"] as num).toDouble()
              : null,
        );
        final prefs = await _prefs();
        await prefs.setString("user", jsonEncode(user.toJson()));
        return user;
      }

      final id = await db.insert("users", {
        "name": name,
        "email": email,
        "password": "google_sso",
        "role": Constants.roleRetailer,
        "status": "ACTIVE",
      });

      final user = User(
        id: id,
        email: email,
        name: name,
        phone: null,
        token: "google-token",
        roles: [Constants.roleRetailer],
        latitude: null,
        longitude: null,
      );

      final prefs = await _prefs();
      await prefs.setString("user", jsonEncode(user.toJson()));

      return user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Google login error: $e");
      }
      rethrow;
    }
  }

  // =============================
  // ADMIN ACTIONS
  // =============================

  Future<void> updateUserStatus(int userId, String status) async {
    if (Constants.useRemote) {
      try {
        await _remote.putJson('/admin/users/$userId/status?status=$status', {});
      } catch (e) {
        rethrow;
      }
      return;
    }
    final db = await _dbService.database;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isNotEmpty) {
      final role = rows.first['role'] as String? ?? '';
      if (role == Constants.roleSuperManager) {
        return;
      }
    }
    await db.update(
      "users",
      {"status": status},
      where: "id = ?",
      whereArgs: [userId],
    );
  }

  Future<void> updateUserRole(int userId, String role) async {
    if (Constants.useRemote) {
      final roleName = role.startsWith('ROLE_')
          ? role
          : 'ROLE_${_mapRoleForBackend(role).toUpperCase()}';
      await _remote.putJson('/admin/users/$userId/role?roleName=$roleName', {});
      return;
    }
    final db = await _dbService.database;
    await db.update(
      "users",
      {"role": role},
      where: "id = ?",
      whereArgs: [userId],
    );
  }

  Future<List<User>> getAllUsers() async {
    if (Constants.useRemote) {
      final list = await _remote.getList('/admin/users');
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        final role = m['role'];
        String roleStr = Constants.roleRetailer;
        if (role is Map && role['name'] != null) {
          roleStr = role['name'].toString();
        } else if (role is String) {
          roleStr = role;
        }
        return User(
          id: (m['id'] as num).toInt(),
          email: m['email'] ?? '',
          name: m['name'],
          phone: m['phone'],
          token: 'remote',
          roles: [roleStr],
          address: m['address'],
          shopImagePath: null,
          status: m['status'],
          latitude:
              m['latitude'] != null ? (m['latitude'] as num).toDouble() : null,
          longitude: m['longitude'] != null
              ? (m['longitude'] as num).toDouble()
              : null,
        );
      }).toList();
    }
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query("users");
    return List.generate(maps.length, (i) {
      return User(
        id: maps[i]["id"] as int,
        email: maps[i]["email"] as String,
        name: maps[i]["name"] as String?,
        phone: maps[i]["phone"] as String?,
        token: "local-token",
        roles: [maps[i]["role"] as String],
        address: maps[i]["address"] as String?,
        shopImagePath: maps[i]["shopImagePath"] as String?,
        status: maps[i]["status"] as String?,
        latitude: maps[i]["latitude"] as double?,
        longitude: maps[i]["longitude"] as double?,
      );
    });
  }

  Future<bool> deleteUser(int userId) async {
    if (Constants.useRemote) {
      await _remote.delete('/admin/users/$userId');
      return true;
    }
    final db = await _dbService.database;
    final count =
        await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    return count > 0;
  }

  Future<void> deleteUsersBulk(List<int> ids) async {
    if (ids.isEmpty) return;
    if (Constants.useRemote) {
      await _remote.postJson('/admin/users/delete-bulk', ids);
      return;
    }
    final db = await _dbService.database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('users', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // Future<void> logout() async {
  //   final prefs = await _prefs();
  //   await prefs.remove("user");
  // }
}
