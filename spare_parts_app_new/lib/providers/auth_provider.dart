import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

import 'package:spare_parts_app/services/auth_exceptions.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _isLoading = true;
    _loadUser();

    // Maximum loading time of 10 seconds to avoid permanent hang
    Future.delayed(const Duration(seconds: 10), () {
      if (_isLoading) {
        if (kDebugMode) {
          debugPrint('AuthProvider: Loading timed out after 10s');
        }
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUser() async {
    if (kDebugMode) {
      debugPrint('AuthProvider: _loadUser started');
    }
    try {
      if (kDebugMode) {
        debugPrint('AuthProvider: calling getCurrentUser');
      }
      _user = await _authService.getCurrentUser();
      if (kDebugMode) {
        debugPrint('AuthProvider: user loaded: ${_user?.email}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AuthProvider: Error loading user: $e');
      }
    } finally {
      if (kDebugMode) {
        debugPrint('AuthProvider: setting isLoading = false');
      }
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        debugPrint('AuthProvider: notifyListeners called');
      }
    }
  }

  Future<void> refreshUser() async {
    _user = await _authService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    _user = await _authService.login(email, password);
    _isLoading = false;
    notifyListeners();

    return _user != null;
  }

  Future<bool> loginWithOtp(String email, String otp) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.loginWithOtp(email, otp);
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

  Future<void> changePassword(String currentPassword, String newPassword) async {
    if (_user != null) {
      _isLoading = true;
      notifyListeners();
      try {
        await _authService.changePassword(_user!.id, currentPassword, newPassword);
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
        final success = await _authService.verifyPhoneNumber(_user!.id, otp);
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

  Future<User?> signInWithGoogle(String email, String name) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.signInWithGoogle(email, name);
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
