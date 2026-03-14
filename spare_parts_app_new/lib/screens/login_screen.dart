// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/constants.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../services/sso_mobile.dart'
    if (dart.library.html) '../services/sso_web.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  final bool showAppBar;
  final bool minimal;
  const LoginScreen({super.key, this.showAppBar = true, this.minimal = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isOtpLogin = false;
  bool _otpSent = false;
  String? _otpSource; // 'server' or 'email'

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('last_email') ?? '';
    final password = prefs.getString('last_password') ?? '';
    if (mounted && (email.isNotEmpty || password.isNotEmpty)) {
      setState(() {
        _emailController.text = email;
        _passwordController.text = password;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_email', _emailController.text);
    await prefs.setString('last_password', _passwordController.text);
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outlined : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showFeedback('Please enter your email.', isError: true);
      return;
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showFeedback('Please enter a valid email address.', isError: true);
      return;
    }

    if (_isOtpLogin) {
      if (_otpController.text.trim().isEmpty) {
        _showFeedback('Please enter the OTP.', isError: true);
        return;
      }
    } else {
      if (_passwordController.text.isEmpty) {
        _showFeedback('Please enter your password.', isError: true);
        return;
      }
      if (_passwordController.text.length < 6) {
        _showFeedback('Password must be at least 6 characters.', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      bool success;
      if (_isOtpLogin) {
        success =
            await authProvider.loginWithOtp(email, _otpController.text.trim());
      } else {
        success = await authProvider.login(email, _passwordController.text);
      }

      if (success) {
        if (!_isOtpLogin) await _saveCredentials();
        final userName = authProvider.user?.name ?? 'User';
        _showFeedback('Welcome $userName! Login successful.');
      } else {
        _showFeedback(
          _isOtpLogin
              ? 'Invalid OTP. Please try again.'
              : 'Invalid email or password. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('HTTP 401') || errorMessage.contains('401')) {
        errorMessage = 'Invalid email or password. Please try again.';
      } else if (errorMessage.contains('HTTP 403') ||
          errorMessage.contains('403')) {
        errorMessage = 'Your account is pending approval or access is denied.';
      } else if (errorMessage.contains('HTTP 404') ||
          errorMessage.contains('404')) {
        errorMessage = 'User not found with this email.';
      } else if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }

      // Attempt to extract message from JSON if it's a server error
      if (errorMessage.contains('{')) {
        try {
          final jsonStart = errorMessage.indexOf('{');
          final jsonStr = errorMessage.substring(jsonStart);
          final decoded = jsonDecode(jsonStr);
          if (decoded['message'] != null) {
            errorMessage = decoded['message'];
          } else if (decoded['error'] != null) {
            errorMessage = decoded['error'];
          }
        } catch (_) {}
      }

      _showFeedback(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showFeedback('Please enter a valid email address.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final source = await authProvider.sendOtp(email, {});
      setState(() => _otpSource = source);
      setState(() => _otpSent = true);
      final via = source == 'server' ? 'server' : 'email';
      _showFeedback('OTP sent via $via.');
      _promptEnterOtp(email);
    } catch (e) {
      _showFeedback('Failed to send OTP: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _promptEnterOtp(String email) {
    final tempOtpController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        bool verifying = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Enter OTP to Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_otpSource != null)
                      Text(
                        _otpSource == 'server' ? 'via server' : 'via email',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tempOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-Digit OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: verifying
                            ? null
                            : () async {
                                final ap = Provider.of<AuthProvider>(context, listen: false);
                                final src = await ap.sendOtp(email, {});
                                setSheet(() => _otpSource = src);
                                final via = src == 'server' ? 'server' : 'email';
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('OTP resent via $via'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        child: const Text('Resend'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: verifying
                            ? null
                            : () async {
                                final otp = tempOtpController.text.trim();
                                if (otp.length != 6) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter a valid 6-digit OTP'),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                setSheet(() => verifying = true);
                                try {
                                  final ap = Provider.of<AuthProvider>(context, listen: false);
                                  final ok = await ap.loginWithOtp(email, otp);
                                  if (ok && mounted) {
                                    Navigator.pop(ctx); // Close sheet
                                    _showFeedback('Login successful!');
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Invalid OTP. Please try again.'),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('OTP login failed: $e')),
                                    );
                                  }
                                } finally {
                                  setSheet(() => verifying = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: verifying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Verify & Login'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final sso = GoogleSSO();
      final data = await sso.signIn();
      if (data != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = await authProvider.signInWithGoogle(
          data['email']!,
          data['name']!,
        );
        if (user != null) {
          _showFeedback('Welcome ${user.name}! Google Sign-In successful.');
        }
      }
    } catch (error) {
      _showFeedback('Google Sign-In failed: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => lp.toggleLanguage(),
            child: Text(
              lp.isHindi ? 'English' : 'हिन्दी',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Section
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Constants.logoUrl.isNotEmpty
                        ? Image.network(
                            Constants.logoUrl,
                            height: 80,
                            errorBuilder: (ctx, error, stack) => const Icon(
                              Icons.settings_suggest,
                              size: 80,
                              color: Colors.green,
                            ),
                          )
                        : const Icon(
                            Icons.settings_suggest,
                            size: 80,
                            color: Colors.green,
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // Header Text
                Text(
                  lp.translate('login_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lp.translate('login_welcome'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),

                // Form Fields
                _buildTextField(
                  controller: _emailController,
                  label: lp.translate('login_email'),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                if (_isOtpLogin) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _otpController,
                          label: '6-Digit OTP',
                          icon: Icons.onetwothree_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(_otpSent ? 'Resend' : 'Send'),
                          ),
                          if (_otpSource != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _otpSource == 'server'
                                    ? 'via server'
                                    : 'via email',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ] else
                  _buildTextField(
                    controller: _passwordController,
                    label: lp.translate('login_password'),
                    icon: Icons.lock_outlined,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),

                // Forgot Password & Toggle Login Mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isOtpLogin = !_isOtpLogin;
                          _otpSent = false;
                          _otpController.clear();
                        });
                      },
                      child: Text(
                        _isOtpLogin
                            ? lp.translate('login_pass_switch')
                            : lp.translate('login_otp_switch'),
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_isOtpLogin)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: Text(
                          lp.translate('login_forgot_pass'),
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: Colors.green.withOpacity(0.5),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isOtpLogin
                              ? 'Verify & Login'
                              : lp.translate('login_button'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 32),

                // Social Login Section
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR CONTINUE WITH',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialIconButton(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      _handleGoogleSignIn,
                    ),
                    const SizedBox(width: 20),
                    _socialIconButton(
                      'https://upload.wikimedia.org/wikipedia/commons/0/05/Facebook_Logo_2023.png',
                      () {}, // Facebook
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Register Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      lp.translate('login_no_account').split('?').first + '? ',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        lp.translate('login_no_account').split('?').last.trim(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.green.shade600, size: 22),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _socialIconButton(String imageUrl, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: 28,
          width: 28,
          child: imageUrl.toLowerCase().endsWith('.svg')
              ? SvgPicture.network(
                  imageUrl,
                  height: 28,
                  width: 28,
                  placeholderBuilder: (ctx) => const Icon(
                    Icons.g_mobiledata,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                )
              : Image.network(
                  imageUrl,
                  height: 28,
                  width: 28,
                  errorBuilder: (ctx, error, stack) => const Icon(
                    Icons.facebook,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
        ),
      ),
    );
  }
}
