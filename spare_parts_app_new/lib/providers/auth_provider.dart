import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/remote_client.dart';

import 'package:spare_parts_app/services/auth_exceptions.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  bool _sessionWasExpired = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get sessionWasExpired => _sessionWasExpired;

  AuthProvider() {
    RemoteClient.onUnauthorized = handleUnauthorized;
    _isLoading = true;
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      _user = await _authService.getCurrentUser();
      if (_user != null) {
        _updateFcmToken();
      }
    } catch (e) {
      debugPrint('AuthProvider: Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateFcmToken() async {
    if (_user != null) {
      final token = await NotificationService.getToken();
      if (token != null) {
        await NotificationService.updateTokenOnServer(_user!.id, token);
        await NotificationService.attemptPendingFcmSync(userId: _user!.id);
      }
    }
  }

  Future<void> refreshUser() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.getCurrentUser();
      if (_user != null) {
        _updateFcmToken();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    _user = await _authService.login(email, password);
    if (_user != null) {
      _updateFcmToken();
    }
    _isLoading = false;
    notifyListeners();

    return _user != null;
  }

  Future<bool> loginWithOtp(String email, String otp) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.loginWithOtp(email, otp);
      if (_user != null) {
        _updateFcmToken();
      }
      return _user != null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyPhone(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String errorMessage) onError,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.verifyPhoneNumber(
        phoneNumber,
        onCodeSent: (verId) {
          _isLoading = false;
          notifyListeners();
          onCodeSent(verId);
        },
        onError: (err) {
          _isLoading = false;
          notifyListeners();
          onError(err);
        },
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.toString());
    }
  }

  Future<String?> verifyPhoneCodeAndGetToken(String smsCode) async {
    return await _authService.verifyPhoneCodeAndGetToken(smsCode);
  }

  Future<bool> loginWithPhoneCode(String smsCode, String phoneNumber) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.loginWithPhoneCode(smsCode, phoneNumber);
      if (_user != null) {
        _updateFcmToken();
      }
      return _user != null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void handleUnauthorized() {
    if (_user != null) {
      debugPrint('AuthProvider: Handling 401 Unauthorized - logging out');
      _sessionWasExpired = true;
      logout();
    }
  }

  void clearExpiredFlag() {
    _sessionWasExpired = false;
    notifyListeners();
  }

  Future<void> updateAddress(String newAddress) async {
    if (_user != null) {
      await _authService.updateUserAddress(_user!.id, newAddress);
      // Refresh user locally
      _user = await _authService.getCurrentUser();
      notifyListeners();
    }
  }

  Future<void> updateShopImage(String path) async {
    if (_user != null) {
      await _authService.updateUserShopImage(_user!.id, path);
      // Refresh user locally
      _user = await _authService.getCurrentUser();
      notifyListeners();
    }
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    if (_user != null) {
      _isLoading = true;
      notifyListeners();
      try {
        await _authService.updateUserLocation(_user!.id, latitude, longitude);
        _user = await _authService.getCurrentUser();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    if (_user != null) {
      _isLoading = true;
      notifyListeners();
      try {
        await _authService.changePassword(
            _user!.id, currentPassword, newPassword);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> verifyPhoneNumber(String otp) async {
    if (_user != null) {
      _isLoading = true;
      notifyListeners();
      try {
        final success = await _authService.verifyPhoneOtpServer(_user!.id, otp);
        if (success) {
          _user = await _authService.getCurrentUser();
        }
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> sendVerificationOtp() async {
    if (_user != null && _user!.phone != null) {
      _isLoading = true;
      notifyListeners();
      try {
        await _authService.sendVerificationOtp(_user!.email, _user!.phone!);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> updateProfile(String name, String phone, String address) async {
    if (_user != null) {
      _isLoading = true;
      notifyListeners();
      try {
        _user = await _authService.updateUserProfile(
          _user!.id,
          name,
          phone,
          address,
        );
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

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
    String? firebaseToken,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _authService.register(
        name,
        email,
        password,
        role,
        phone,
        address,
        latitude: latitude,
        longitude: longitude,
        otp: otp,
        firebaseToken: firebaseToken,
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String> sendOtp(
    String email,
    Map<String, dynamic> registrationData,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final source = await _authService.sendOtp(email, registrationData);
      return source;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String otp) async {
    try {
      return await _authService.verifyOtp(otp);
    } on EmailAlreadyRegisteredException {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.signInWithGoogle();
      return _user;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetOtp(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.sendPasswordResetOtp(email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _authService.resetPassword(email, otp, newPassword);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMobileOtp(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.sendMobileOtp(phoneNumber);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyMobileOtp(String phoneNumber, String otp) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _authService.verifyMobileOtp(phoneNumber, otp);
      return success;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserStatus(int userId, String status) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.updateUserStatus(userId, status);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserRole(int userId, String role) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.updateUserRole(userId, role);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<User>> getAllUsers() async {
    return await _authService.getAllUsers();
  }
}
