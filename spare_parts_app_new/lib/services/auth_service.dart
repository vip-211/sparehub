import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
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
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;

  String? _otp;
  String? _verificationId;

  Future<SharedPreferences> _prefs() async {
    return await SharedPreferences.getInstance();
  }

  // =============================
  // FIREBASE PHONE AUTH
  // =============================

  Future<void> verifyPhoneNumber(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb_auth.PhoneAuthCredential credential) async {
          // Auto-verification (rare on Android, not possible on iOS)
          // For now we just let the manual code entry handle it
        },
        verificationFailed: (fb_auth.FirebaseAuthException e) {
          onError(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verId, int? resendToken) {
          _verificationId = verId;
          onCodeSent(verId);
        },
        codeAutoRetrievalTimeout: (String verId) {
          _verificationId = verId;
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<User?> loginWithPhoneCode(String smsCode, String phoneNumber) async {
    try {
      if (_verificationId == null) throw 'Verification ID is missing';

      final credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final fbUser = userCredential.user;

      if (fbUser != null) {
        // Successfully verified by Firebase
        if (Constants.useRemote) {
          // Get the ID token to verify on backend
          final idToken = await fbUser.getIdToken();

          // Call backend to login/fetch user by phone
          final json = await _remote.postJson('/auth/phone-login', {
            'phoneNumber': phoneNumber,
            'firebaseToken': idToken,
          });

          return _parseUserJson(json);
        } else {
          // Local DB fallback
          return await _loginLocallyByPhone(phoneNumber);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Phone login error: $e");
      rethrow;
    }
  }

  Future<User?> _loginLocallyByPhone(String phone) async {
    final db = await _dbService.database;
    final result = await db.query(
      "users",
      where: "phone = ?",
      whereArgs: [phone],
      limit: 1,
    );
    if (result.isEmpty) throw "User not found with this phone number";
    final userData = result.first;
    final user = User(
      id: userData["id"] as int,
      email: userData["email"] as String,
      name: userData["name"] as String?,
      phone: userData["phone"] as String?,
      token: "local-phone-token",
      roles: [userData["role"] as String],
      status: userData["status"] as String? ?? 'ACTIVE',
    );
    final prefs = await _prefs();
    await prefs.setString('user', jsonEncode(user.toJson()));
    return user;
  }

  User _parseUserJson(Map<String, dynamic> json) {
    final token = json['token'] ?? json['accessToken'];
    final id = (json['id'] as num).toInt();
    final emailVal = json['email'] as String;
    final name = json['username'] ?? json['name'] ?? emailVal;

    final roles = (json['roles'] as List).map((e) {
      if (e is Map && e['name'] != null) return e['name'].toString();
      return e.toString();
    }).toList();

    return User(
      id: id,
      email: emailVal,
      name: name,
      phone: json['phone'],
      token: token.toString(),
      roles: roles,
      address: json['address'],
      shopImagePath: json['shopImagePath'],
      status: (json['status'] ?? 'ACTIVE').toString(),
      phoneVerified: true,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  // =============================
  // LOGIN
  // =============================

  Future<User?> login(String identifier, String password) async {
    try {
      if (Constants.useRemote) {
        final json = await _remote.postJson('/auth/signin', {
          'email': identifier,
          'password': password,
        });

        final token = json['token'] ?? json['accessToken'];
        final id = (json['id'] as num).toInt();
        final emailVal = json['email'] as String;
        final name = json['username'] ?? json['name'] ?? emailVal;

        // Backend roles might be objects like {id: 1, name: "ROLE_MECHANIC"} or just strings
        final roles = (json['roles'] as List).map((e) {
          if (e is Map && e['name'] != null) return e['name'].toString();
          return e.toString();
        }).toList();

        final status = (json['status'] ?? 'ACTIVE').toString();
        if (status != 'ACTIVE') {
          throw Exception('Your account is not active yet.');
        }
        final user = User(
          id: id,
          email: emailVal,
          name: name,
          phone: json['phone'],
          token: token.toString(),
          roles: roles,
          address: json['address'],
          shopImagePath: json['shopImagePath'],
          status: status,
          phoneVerified:
              json['phoneVerified'] == true || json['phone_verified'] == 1,
          latitude: json['latitude'] != null
              ? (json['latitude'] as num).toDouble()
              : null,
          longitude: json['longitude'] != null
              ? (json['longitude'] as num).toDouble()
              : null,
        );
        final prefs = await _prefs();
        await prefs.setString('user', jsonEncode(user.toJson()));
        return user;
      }

      final db = await _dbService.database;
      final result = await db.query(
        "users",
        where: "email = ? OR phone = ?",
        whereArgs: [identifier, identifier],
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
        phoneVerified: userData["phone_verified"] == 1,
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

  Future<User?> loginWithOtp(String identifier, String otp) async {
    try {
      if (Constants.useRemote) {
        final json = await _remote.postJson(Constants.otpLoginPath, {
          'email': identifier,
          'otp': otp,
        });

        final token = json['token'] ?? json['accessToken'];
        final id = (json['id'] as num).toInt();
        final emailVal = json['email'] as String;
        final name = json['username'] ?? json['name'] ?? emailVal;

        // Backend roles might be objects like {id: 1, name: "ROLE_MECHANIC"} or just strings
        final roles = (json['roles'] as List).map((e) {
          if (e is Map && e['name'] != null) return e['name'].toString();
          return e.toString();
        }).toList();

        final status = (json['status'] ?? 'ACTIVE').toString();
        if (status != 'ACTIVE') {
          throw Exception('Your account is not active yet.');
        }
        final user = User(
          id: id,
          email: emailVal,
          name: name,
          phone: json['phone'],
          token: token.toString(),
          roles: roles,
          address: json['address'],
          shopImagePath: json['shopImagePath'],
          status: status,
          phoneVerified:
              json['phoneVerified'] == true || json['phone_verified'] == 1,
          latitude: json['latitude'] != null
              ? (json['latitude'] as num).toDouble()
              : null,
          longitude: json['longitude'] != null
              ? (json['longitude'] as num).toDouble()
              : null,
        );
        final prefs = await _prefs();
        await prefs.setString('user', jsonEncode(user.toJson()));
        return user;
      }
      if (_otp != otp) {
        throw Exception('Invalid OTP');
      }
      final db = await _dbService.database;
      final result = await db.query(
        "users",
        where: "email = ? OR phone = ?",
        whereArgs: [identifier, identifier],
        limit: 1,
      );
      if (result.isEmpty) throw Exception('User not found');
      final userData = result.first;
      final user = User(
        id: userData["id"] as int,
        email: userData["email"] as String,
        name: userData["name"] as String?,
        phone: userData["phone"] as String?,
        token: "local-otp",
        roles: [userData["role"] as String],
        address: userData["address"] as String?,
        shopImagePath: userData["shopImagePath"] as String?,
        status: userData["status"] as String?,
        phoneVerified: true,
        latitude: userData["latitude"] != null
            ? (userData["latitude"] as num).toDouble()
            : null,
        longitude: userData["longitude"] != null
            ? (userData["longitude"] as num).toDouble()
            : null,
      );
      final prefs = await _prefs();
      await prefs.setString('user', jsonEncode(user.toJson()));
      return user;
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
        'phone': phone,
        'address': address,
        'role': _mapRoleForBackend(role),
      };
      if (otp != null && otp.isNotEmpty) body['otp'] = otp;

      await _remote.postJson('/auth/signup', body);
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
    if (role == Constants.roleSuperManager) return 'supermanager';
    return 'mechanic';
  }

  // =============================
  // CHANGE PASSWORD
  // =============================

  Future<void> changePassword(
    int userId,
    String currentPassword,
    String newPassword,
  ) async {
    if (Constants.useRemote) {
      await _remote.postJson('/auth/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      return;
    }

    final db = await _dbService.database;
    final result = await db.query(
      "users",
      where: "id = ?",
      whereArgs: [userId],
    );

    if (result.isEmpty) throw "User not found";

    final storedPassword = result.first["password"] as String;
    if (!BCrypt.checkpw(currentPassword, storedPassword)) {
      throw "Current password is incorrect";
    }

    final hashed = BCrypt.hashpw(newPassword, BCrypt.gensalt());
    await db.update(
      "users",
      {"password": hashed},
      where: "id = ?",
      whereArgs: [userId],
    );
  }

  // =============================
  // PHONE VERIFICATION
  // =============================

  Future<void> sendVerificationOtp(String email, String phone) async {
    if (Constants.useRemote) {
      await _remote.postJson('/auth/send-verification-otp', {
        'email': email,
        'phone': phone,
      });
      return;
    }
    _otp = (100000 + Random().nextInt(900000)).toString();
    await _emailService.sendOtp(email, _otp!);
  }

  Future<bool> verifyPhoneOtpServer(int userId, String otp) async {
    if (Constants.useRemote) {
      final res = await _remote.postJson('/auth/verify-phone', {'otp': otp});
      return res != null;
    }

    if (_otp != otp) throw "Invalid OTP";

    final db = await _dbService.database;
    await db.update(
      "users",
      {"phone_verified": 1},
      where: "id = ?",
      whereArgs: [userId],
    );
    return true;
  }

  // =============================
  // UPDATE ADDRESS
  // =============================

  Future<void> updateUserAddress(int userId, String address) async {
    if (Constants.useRemote) {
      await _remote.putJson('/users/address', {'address': address});
      final prefs = await _prefs();
      final current = await getCurrentUser();
      if (current != null && current.id == userId) {
        final updated = User(
          id: current.id,
          email: current.email,
          name: current.name,
          phone: current.phone,
          token: current.token,
          roles: current.roles,
          address: address,
          shopImagePath: current.shopImagePath,
          status: current.status,
          phoneVerified: current.phoneVerified,
          latitude: current.latitude,
          longitude: current.longitude,
        );
        await prefs.setString('user', jsonEncode(updated.toJson()));
      }
      return;
    }
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
    if (Constants.useRemote) {
      final res = await _remote.putJson('/users/profile', {
        'name': name,
        'phone': phone,
        'address': address,
      });

      final current = await getCurrentUser();
      final Map<String, dynamic> userData = Map.from(res);
      if (current != null) {
        userData['token'] = current.token;
      } else {
        userData['token'] = '';
      }

      final updated = User.fromJson(userData);
      final prefs = await _prefs();
      await prefs.setString('user', jsonEncode(updated.toJson()));
      return updated;
    }

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
      phoneVerified: updated["phone_verified"] == 1,
      latitude: updated["latitude"] as double?,
      longitude: updated["longitude"] as double?,
    );

    final prefs = await _prefs();
    await prefs.setString("user", jsonEncode(user.toJson()));

    return user;
  }

  // =============================
  // UPDATE LOCATION
  // =============================

  Future<void> updateUserLocation(
    int userId,
    double latitude,
    double longitude,
  ) async {
    if (Constants.useRemote) {
      try {
        final path =
            Constants.locationIdPath.replaceAll('{id}', userId.toString());
        await _remote.putJson(path, {
          'latitude': latitude,
          'longitude': longitude,
        });
      } catch (e) {
        try {
          await _remote.putJson(Constants.locationBodyPath, {
            'userId': userId,
            'latitude': latitude,
            'longitude': longitude,
          });
        } catch (_) {}
      }
      final prefs = await _prefs();
      final current = await getCurrentUser();
      if (current != null) {
        final updated = User(
          id: current.id,
          email: current.email,
          name: current.name,
          phone: current.phone,
          token: current.token,
          roles: current.roles,
          address: current.address,
          shopImagePath: current.shopImagePath,
          status: current.status,
          phoneVerified: current.phoneVerified,
          latitude: latitude,
          longitude: longitude,
        );
        await prefs.setString('user', jsonEncode(updated.toJson()));
      }
      return;
    }
    final db = await _dbService.database;
    await db.update(
      "users",
      {"latitude": latitude, "longitude": longitude},
      where: "id = ?",
      whereArgs: [userId],
    );
    final result = await db.query(
      "users",
      where: "id = ?",
      whereArgs: [userId],
    );
    if (result.isNotEmpty) {
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
        status: updated["status"] as String?,
        phoneVerified: updated["phone_verified"] == 1,
        latitude: updated["latitude"] != null
            ? (updated["latitude"] as num).toDouble()
            : null,
        longitude: updated["longitude"] != null
            ? (updated["longitude"] as num).toDouble()
            : null,
      );
      final prefs = await _prefs();
      await prefs.setString("user", jsonEncode(user.toJson()));
    }
  }

  // =============================
  // SEND OTP
  // =============================

  Future<String> sendOtp(
    String identifier,
    Map<String, dynamic> registrationData,
  ) async {
    final isEmail = identifier.contains('@');

    if (Constants.useRemote && !Constants.forceLocalOtp) {
      try {
        if (kDebugMode) {
          debugPrint('AuthService: Requesting remote OTP for $identifier...');
        }
        final body = {
          'email': identifier,
          'purpose': (registrationData.isNotEmpty ? 'signup' : 'login'),
        };
        await _remote.postJson('/auth/send-otp', body);

        _otp = null; // Backend stores OTP
        return 'server';
      } catch (e) {
        if (kDebugMode) {
          debugPrint('AuthService: Remote OTP failed: $e');
        }
        if (registrationData.isNotEmpty) {
          // Signup: allow local fallback
          if (kDebugMode) {
            debugPrint('Remote OTP failed, falling back (signup): $e');
          }
        } else {
          // Login/reset: do not fallback; propagate error
          rethrow;
        }
      }
    }

    // Local Fallback
    _otp = (100000 + Random().nextInt(900000)).toString();

    if (isEmail) {
      try {
        await _emailService.sendOtp(identifier, _otp!);
        return 'email';
      } catch (e) {
        if (kDebugMode) debugPrint('Local Email OTP failed: $e');
        // If real email fails, we still set _otp so user can "guess" or we can see it in logs
        return 'debug';
      }
    } else {
      // For mobile, in a real app you'd use Twilio/Firebase Auth
      // Here we simulate it by printing to console and returning success
      if (kDebugMode) {
        debugPrint('=========================================');
        debugPrint('MOBILE OTP FOR $identifier: $_otp');
        debugPrint('=========================================');
      }
      return 'sms_simulated';
    }
  }

  Future<void> sendPasswordResetOtp(String email) async {
    try {
      if (Constants.useRemote && !Constants.forceLocalOtp) {
        final body = {'email': email, 'purpose': 'reset'};
        await _remote.postJson('/auth/send-otp', body);
        _otp = null;
      } else {
        _otp = (100000 + Random().nextInt(900000)).toString();
        await _emailService.sendOtp(email, _otp!);
      }
    } catch (e) {
      rethrow;
    }
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
    if (Constants.useRemote) {
      final res = await _remote.postJson('/auth/reset-password', {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
      });
      return res != null;
    }
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

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSSO.signIn();
      if (googleUser == null) return null; // User cancelled

      final String googleEmail = googleUser['email'] ?? '';
      final String googleName = googleUser['name'] ?? '';

      if (Constants.useRemote) {
        final json = await _remote.postJson('/auth/google', {
          'email': googleEmail,
          'name': googleName,
        });

        final token = json['token'] ?? json['accessToken'];
        final id = (json['id'] as num).toInt();
        final emailVal = json['email'] as String;
        final userName = json['username'] ?? json['name'] ?? googleName;
        final roles = (json['roles'] as List).map((e) => e.toString()).toList();
        final user = User(
          id: id,
          email: emailVal,
          name: userName,
          phone: json['phone'],
          token: token.toString(),
          roles: roles,
          address: json['address'],
          shopImagePath: json['shopImagePath'],
          status: (json['status'] ?? 'ACTIVE').toString(),
          phoneVerified:
              json['phoneVerified'] == true || json['phone_verified'] == 1,
          latitude: json['latitude'] != null
              ? (json['latitude'] as num).toDouble()
              : null,
          longitude: json['longitude'] != null
              ? (json['longitude'] as num).toDouble()
              : null,
        );
        final prefs = await _prefs();
        await prefs.setString('user', jsonEncode(user.toJson()));
        return user;
      }

      final db = await _dbService.database;
      final maps = await db.query(
        "users",
        where: "email = ?",
        whereArgs: [googleEmail],
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
          phoneVerified: userData["phone_verified"] == 1,
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
        "name": googleName,
        "email": googleEmail,
        "password": "google_sso",
        "role": Constants.roleRetailer,
        "status": "ACTIVE",
      });

      final user = User(
        id: id,
        email: googleEmail,
        name: googleName,
        phone: null,
        token: "google-token",
        roles: [Constants.roleRetailer],
        latitude: null,
        longitude: null,
        status: "ACTIVE",
      );

      final prefs = await _prefs();
      await prefs.setString("user", jsonEncode(user.toJson()));

      return user;
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Google sign-in error: $e");
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
    final List<Map<String, dynamic>> maps =
        await db.query("users", where: "deleted = 0");
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
    final count = await db.update("users", {"deleted": 1},
        where: "id = ?", whereArgs: [userId]);
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
      batch.update('users', {'deleted': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getDeletedUsers() async {
    if (Constants.useRemote) {
      final list = await _remote.getList('/admin/recycle-bin/users');
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return {
          'id': (m['id'] as num).toInt(),
          'email': m['email'] ?? '',
          'name': m['name'],
          'role': m['role'] is Map ? m['role']['name'] : m['role'],
        };
      }).toList();
    }
    final db = await _dbService.database;
    return db.query('users', where: 'deleted = 1');
  }

  Future<bool> restoreUser(int userId) async {
    if (Constants.useRemote) {
      await _remote.postJson('/admin/recycle-bin/users/$userId/restore', {});
      return true;
    }
    final db = await _dbService.database;
    final count = await db.update('users', {'deleted': 0},
        where: 'id = ?', whereArgs: [userId]);
    return count > 0;
  }

  // Future<void> logout() async {
  //   final prefs = await _prefs();
  //   await prefs.remove("user");
  // }
}
