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
    final identifier = _emailController.text.trim();
    if (identifier.isEmpty) {
      _showFeedback('Please enter your email or mobile number.', isError: true);
      return;
    }

    final isEmail = identifier.contains('@');
    if (isEmail) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(identifier)) {
        _showFeedback('Please enter a valid email address.', isError: true);
        return;
      }
    } else {
      if (identifier.length < 10) {
        _showFeedback('Please enter a valid mobile number.', isError: true);
        return;
      }
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
        success = await authProvider.loginWithOtp(
            identifier, _otpController.text.trim());
      } else {
        success =
            await authProvider.login(identifier, _passwordController.text);
      }

      if (success) {
        if (!_isOtpLogin) await _saveCredentials();
        final userName = authProvider.user?.name ?? 'User';
        _showFeedback('Welcome $userName! Login successful.');
      } else {
        _showFeedback(
          _isOtpLogin
              ? 'Invalid OTP. Please try again.'
              : 'Invalid credentials. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('HTTP 401') || errorMessage.contains('401')) {
        errorMessage = 'Invalid credentials. Please try again.';
      } else if (errorMessage.contains('HTTP 403') ||
          errorMessage.contains('403')) {
        errorMessage = 'Your account is pending approval or access is denied.';
      } else if (errorMessage.contains('HTTP 404') ||
          errorMessage.contains('404')) {
        errorMessage = 'User not found.';
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
    final identifier = _emailController.text.trim();
    if (identifier.isEmpty) {
      _showFeedback('Please enter your email or mobile number.', isError: true);
      return;
    }

    final isEmail = identifier.contains('@');
    if (isEmail) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(identifier)) {
        _showFeedback('Please enter a valid email address.', isError: true);
        return;
      }
    } else {
      if (identifier.length < 10) {
        _showFeedback('Please enter a valid mobile number.', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!isEmail) {
        // Firebase Phone Auth
        await authProvider.verifyPhone(
          identifier,
          onCodeSent: (verId) {
            setState(() => _otpSource = 'firebase');
            setState(() => _otpSent = true);
            _showFeedback('OTP sent to your phone via Firebase.');
            _promptEnterOtp(identifier, isFirebase: true);
          },
          onError: (err) {
            _showFeedback('Firebase Phone Auth failed: $err', isError: true);
          },
        );
        return;
      }

      // For email login, we don't send registrationData, so purpose becomes 'login'
      final source = await authProvider.sendOtp(identifier, {});
      setState(() => _otpSource = source);
      setState(() => _otpSent = true);
      final via = source == 'server' ? 'SMS/Server' : 'Email';
      _showFeedback('OTP sent via $via.');
      _promptEnterOtp(identifier);
    } catch (e) {
      _showFeedback('Failed to send OTP: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _promptEnterOtp(String identifier, {bool isFirebase = false}) {
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
                        _otpSource == 'server'
                            ? 'via server'
                            : (_otpSource == 'firebase'
                                ? 'via Firebase'
                                : 'via email'),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
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
                                final ap = Provider.of<AuthProvider>(context,
                                    listen: false);
                                if (isFirebase) {
                                  await ap.verifyPhone(
                                    identifier,
                                    onCodeSent: (verId) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('OTP resent via Firebase'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    onError: (err) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content:
                                                  Text('Resend failed: $err')),
                                        );
                                      }
                                    },
                                  );
                                } else {
                                  // Purpose: login
                                  final src = await ap.sendOtp(identifier, {});
                                  setSheet(() => _otpSource = src);
                                  final via =
                                      src == 'server' ? 'SMS/Server' : 'Email';
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('OTP resent via $via'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
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
                                        content: Text(
                                            'Please enter a valid 6-digit OTP'),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                setSheet(() => verifying = true);
                                try {
                                  final ap = Provider.of<AuthProvider>(context,
                                      listen: false);
                                  bool ok = false;
                                  if (isFirebase) {
                                    ok = await ap.loginWithPhoneCode(
                                        otp, identifier);
                                  } else {
                                    ok = await ap.loginWithOtp(identifier, otp);
                                  }

                                  if (ok && mounted) {
                                    Navigator.pop(ctx); // Close sheet
                                    _showFeedback('Login successful!');
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Invalid OTP. Please try again.'),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('OTP login failed: $e')),
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
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = await authProvider.signInWithGoogle();
      if (user != null) {
        final userName = user.name;
        _showFeedback('Welcome $userName! Google Sign-In successful.');
      }
    } catch (error) {
      String msg = error.toString();
      if (msg.contains('Exception: ')) {
        msg = msg.replaceFirst('Exception: ', '');
      }
      bool suggestSetup =
          msg.contains('ApiException: 10') || msg.contains('sign_in_failed');
      if (suggestSetup) {
        _showFeedback(
            'Google Sign-In failed. Check Android SHA-1 and package name in Google Console. You can log in via OTP.',
            isError: true);
        await _promptEmailThenOtp();
      } else {
        _showFeedback('Google Sign-In failed: $msg', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _promptEmailThenOtp() async {
    final emailCtrl = TextEditingController(text: _emailController.text);
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Login via OTP'),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              final regex = RegExp(r'^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$');
              if (!regex.hasMatch(email)) {
                _showFeedback('Enter a valid email address.', isError: true);
                return;
              }
              try {
                final ap = Provider.of<AuthProvider>(context, listen: false);
                await ap.sendOtp(email, {});
                if (mounted) {
                  Navigator.pop(ctx);
                  _promptEnterOtp(email);
                }
              } catch (e) {
                String em = e.toString();
                if (em.startsWith('Exception: ')) {
                  em = em.replaceFirst('Exception: ', '');
                }
                _showFeedback(em, isError: true);
              }
            },
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade800,
              Colors.green.shade500,
              Colors.blue.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language Toggle
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton.icon(
                      onPressed: () => lp.toggleLanguage(),
                      icon: const Icon(Icons.language,
                          color: Colors.white, size: 18),
                      label: Text(
                        lp.isHindi ? 'English' : 'हिन्दी',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Login Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          // Logo Section
                          if (!widget.minimal) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Constants.logoUrl.isNotEmpty
                                  ? Image.network(
                                      Constants.logoUrl,
                                      height: 60,
                                      errorBuilder: (ctx, error, stack) =>
                                          const Icon(
                                        Icons.settings_suggest,
                                        size: 60,
                                        color: Colors.green,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.settings_suggest,
                                      size: 60,
                                      color: Colors.green,
                                    ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Header Text
                          Text(
                            lp.translate('login_title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lp.translate('login_welcome'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 32),

                          // Form Fields
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email or Mobile Number',
                            icon: Icons.person_outline,
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 16),
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
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(_otpSent ? 'Resend' : 'Send'),
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
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
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
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (!_isOtpLogin)
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    lp.translate('login_forgot_pass'),
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isOtpLogin
                                          ? 'Verify & Login'
                                          : lp.translate('login_button'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Social Login Section
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Colors.white70)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR CONTINUE WITH',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Colors.white70)),
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
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Don\'t have an account? ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
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

  Widget _socialIconButton(String iconUrl, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: SvgPicture.network(
          iconUrl,
          height: 24,
          width: 24,
          placeholderBuilder: (ctx) => const Icon(
            Icons.g_mobiledata,
            color: Colors.redAccent,
            size: 24,
          ),
        ),
      ),
    );
  }
}
