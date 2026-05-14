// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool showAppBar;
  final bool minimal;
  const LoginScreen({super.key, this.showAppBar = false, this.minimal = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final identifier = prefs.getString('last_identifier') ?? prefs.getString('last_email') ?? '';
    if (mounted && identifier.isNotEmpty) {
      setState(() {
        _identifierController.text = identifier;
      });
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _navigateToDashboard() {
    final ap = Provider.of<AuthProvider>(context, listen: false);
    final user = ap.user;
    if (user == null) return;
    String route = '/dashboard/mechanic';
    if (user.roles.contains(Constants.roleRetailer)) {
      route = '/dashboard/retailer';
    } else if (user.roles.contains(Constants.roleMechanic)) {
      route = '/dashboard/mechanic';
    } else if (user.roles.contains(Constants.roleWholesaler)) {
      route = '/dashboard/wholesaler';
    } else if (user.roles.contains(Constants.roleAdmin) ||
        user.roles.contains(Constants.roleSuperManager)) {
      route = '/dashboard/admin';
    } else if (user.roles.contains(Constants.roleStaff)) {
      route = '/dashboard/staff';
    }
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  void _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showFeedback('Please enter both identifier and password.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await Provider.of<AuthProvider>(context, listen: false)
          .login(identifier, password);

      if (success) {
        if (_rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_identifier', identifier);
        }
        _navigateToDashboard();
      } else {
        _showFeedback('Invalid credentials. Please try again.', isError: true);
      }
    } catch (e) {
      _showFeedback(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Gradient and Logo
            Container(
              height: MediaQuery.of(context).size.height * 0.35,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(80),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        width: 80,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.settings_suggest, size: 60, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    child: Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInLeft(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'Login to your account',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.charcoalBlack,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Identifier Input
                  FadeInLeft(
                    delay: const Duration(milliseconds: 300),
                    child: TextField(
                      controller: _identifierController,
                      decoration: InputDecoration(
                        hintText: 'Email or Mobile Number',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password Input
                  FadeInLeft(
                    delay: const Duration(milliseconds: 400),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Remember Me & Forgot Password
                  FadeInLeft(
                    delay: const Duration(milliseconds: 500),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? true),
                              activeColor: AppTheme.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            const Text('Remember Me', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Login Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: AppTheme.primaryBlue.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'LOGIN',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Divider
                  FadeIn(
                    delay: const Duration(milliseconds: 700),
                    child: Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Social Login
                  FadeInUp(
                    delay: const Duration(milliseconds: 800),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialButton(
                          icon: Icons.phone_android_rounded,
                          color: AppTheme.secondaryAmber,
                          onTap: () {
                            // Toggle to OTP login UI or navigate
                          },
                        ),
                        const SizedBox(width: 20),
                        _socialButton(
                          icon: Icons.g_mobiledata_rounded,
                          color: Colors.redAccent,
                          onTap: () {
                            // Google Sign In
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Sign Up Link
                  FadeInUp(
                    delay: const Duration(milliseconds: 900),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}
