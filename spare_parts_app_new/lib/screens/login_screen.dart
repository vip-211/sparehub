// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../utils/constants.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import '../services/sso_mobile.dart'
    if (dart.library.html) '../services/sso_web.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/settings_service.dart';
import 'offers_screen.dart';

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
  String _selectedCountryCode = '+91';
  String? _otpSource; // 'server' or 'email'

  Timer? _resendTimer;
  int _secondsRemaining = 0;
  bool _canResend = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowAdminBanner();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    if (!mounted) return;
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('last_email') ?? '';
    // Cleanup any previously stored plaintext password
    if (prefs.containsKey('last_password')) {
      await prefs.remove('last_password');
    }
    if (mounted && email.isNotEmpty) {
      setState(() {
        _emailController.text = email;
      });
    }
  }

  Future<void> _maybeShowAdminBanner() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearMaterialBanners();
      }
      return;
    }
    await SettingsService.preloadRemoteSettings();
    final enabled = SettingsService.getCachedRemoteSetting(
            'LOGIN_BANNER_ENABLED', 'false') ==
        'true';
    final text =
        SettingsService.getCachedRemoteSetting('LOGIN_BANNER_TEXT', '');
    final rawImage =
        SettingsService.getCachedRemoteSetting('LOGIN_BANNER_IMAGE_URL', '')
            .trim();
    Uri? parsedImageUri;
    try {
      parsedImageUri = Uri.tryParse(rawImage);
    } catch (_) {
      parsedImageUri = null;
    }
    final bool isValidImageUrl = parsedImageUri != null &&
        parsedImageUri.isAbsolute &&
        (parsedImageUri.scheme == 'http' || parsedImageUri.scheme == 'https') &&
        parsedImageUri.host.isNotEmpty;
    final imageUrl = isValidImageUrl ? rawImage : '';
    final showButton = SettingsService.getCachedRemoteSetting(
            'LOGIN_BANNER_SHOW_BUTTON', 'false') ==
        'true';
    final buttonText = (SettingsService.getCachedRemoteSetting(
                'LOGIN_BANNER_BUTTON_TEXT', 'Check Offers'))
            .trim()
            .isNotEmpty
        ? SettingsService.getCachedRemoteSetting(
            'LOGIN_BANNER_BUTTON_TEXT', 'Check Offers')
        : 'Check Offers';
    final cooldownHoursStr = SettingsService.getCachedRemoteSetting(
        'LOGIN_BANNER_COOLDOWN_HOURS', '24');
    final cooldownHours = int.tryParse(cooldownHoursStr) ?? 24;

    if (!enabled || text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lastText = prefs.getString('login_banner_last_text');
    final dismissedUntil = prefs.getInt('login_banner_dismissed_until') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dismissalActive = (lastText == text) && dismissedUntil > nowMs;
    if (dismissalActive) return;
    await prefs.setString('login_banner_last_text', text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Text(text),
        leading: imageUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    return const Icon(Icons.campaign_outlined);
                  },
                ),
              )
            : const Icon(Icons.campaign_outlined),
        actions: [
          if (showButton)
            TextButton(
              onPressed: () async {
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                final p = await SharedPreferences.getInstance();
                final until = DateTime.now()
                    .add(Duration(hours: cooldownHours))
                    .millisecondsSinceEpoch;
                await p.setInt('login_banner_dismissed_until', until);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OffersScreen()),
                );
              },
              child: Text(buttonText),
            ),
          TextButton(
            onPressed: () async {
              if (!mounted) return;
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              final p = await SharedPreferences.getInstance();
              final until = DateTime.now()
                  .add(Duration(hours: cooldownHours))
                  .millisecondsSinceEpoch;
              await p.setInt('login_banner_dismissed_until', until);
            },
            child: const Text('Dismiss'),
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_email', _emailController.text);
    // Do not store plaintext passwords
    if (prefs.containsKey('last_password')) {
      await prefs.remove('last_password');
    }
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
              color: isError
                  ? Theme.of(context).colorScheme.onError
                  : Theme.of(context).colorScheme.onPrimary,
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
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
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
    final rawIdentifier = _emailController.text.trim();
    if (rawIdentifier.isEmpty) {
      _showFeedback('Please enter your email or mobile number.', isError: true);
      return;
    }

    final isEmail = rawIdentifier.contains('@');
    final identifier = isEmail
        ? rawIdentifier
        : (_selectedCountryCode + rawIdentifier.replaceAll(RegExp(r'\D'), ''));

    if (isEmail) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(identifier)) {
        _showFeedback('Please enter a valid email address.', isError: true);
        return;
      }
    } else {
      if (rawIdentifier.length < 10) {
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
        _navigateToDashboard();
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
    if (!_canResend) {
      _showFeedback('Please wait ${_secondsRemaining}s before resending.',
          isError: true);
      return;
    }

    final rawIdentifier = _emailController.text.trim();
    if (rawIdentifier.isEmpty) {
      _showFeedback('Please enter your email or mobile number.', isError: true);
      return;
    }

    final isEmail = rawIdentifier.contains('@');
    final identifier = isEmail
        ? rawIdentifier
        : (_selectedCountryCode + rawIdentifier.replaceAll(RegExp(r'\D'), ''));

    if (isEmail) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(identifier)) {
        _showFeedback('Please enter a valid email address.', isError: true);
        return;
      }
    } else {
      if (rawIdentifier.length < 10) {
        _showFeedback('Please enter a valid mobile number.', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (!isEmail) {
        // ONLY Firebase Phone Auth for mobile login
        await authProvider.verifyPhone(
          identifier,
          onCodeSent: (verId) {
            setState(() {
              _otpSource = 'firebase';
              _otpSent = true;
              _isLoading = false;
            });
            _startResendTimer();
            _showFeedback('OTP sent to your phone via Firebase.');
            _promptEnterOtp(identifier, isFirebase: true);
          },
          onError: (err) {
            setState(() => _isLoading = false);
            _showFeedback('Firebase Phone Auth failed: $err', isError: true);
          },
        );
        return;
      }

      // For email login, we still use the provider's sendOtp method
      final source = await authProvider.sendOtp(identifier, {});
      setState(() {
        _otpSource = source;
        _otpSent = true;
      });
      _startResendTimer();
      _showFeedback('OTP sent via Email.');
      _promptEnterOtp(identifier);
    } catch (e) {
      _showFeedback('Failed to send OTP: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _promptEnterOtp(String identifier, {bool isFirebase = false}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: identifier,
          isFirebase: isFirebase,
        ),
      ),
    );

    if (result != null && result.length == 6) {
      _handleOtpLogin(identifier, result, isFirebase: isFirebase);
    }
  }

  void _handleOtpLogin(String identifier, String otp,
      {bool isFirebase = false}) async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      bool success = false;

      if (isFirebase) {
        success = await authProvider.loginWithPhoneCode(otp, identifier);
      } else {
        success = await authProvider.loginWithOtp(identifier, otp);
      }

      if (success) {
        if (mounted) {
          final userName = authProvider.user?.name ?? 'User';
          _showFeedback('Welcome $userName! Login successful.');
          _navigateToDashboard();
        }
      } else {
        _showFeedback(
          isFirebase
              ? 'Invalid phone OTP. Please try again.'
              : 'Invalid OTP. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      _showFeedback(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = await authProvider.signInWithGoogle();
      if (user != null) {
        final userName = user.name;
        _showFeedback('Welcome $userName! Google Sign-In successful.');
        _navigateToDashboard();
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
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          // Logo Section
                          if (!widget.minimal) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Constants.logoUrl.isNotEmpty
                                  ? Image.network(
                                      Constants.logoUrl,
                                      height: 60,
                                      errorBuilder: (ctx, error, stack) => Icon(
                                        Icons.settings_suggest,
                                        size: 60,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.settings_suggest,
                                      size: 60,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Header Text
                          Text(
                            lp.translate('login_title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lp.translate('login_welcome'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Form Fields
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            child: Row(
                              children: [
                                if (!_emailController.text.contains('@') &&
                                    _emailController.text.isNotEmpty &&
                                    RegExp(r'^\d+$').hasMatch(
                                        _emailController.text.trim())) ...[
                                  const SizedBox(width: 12),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCountryCode,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontWeight: FontWeight.bold),
                                      dropdownColor:
                                          Theme.of(context).colorScheme.surface,
                                      items: [
                                        '+91',
                                        '+1',
                                        '+44',
                                        '+971',
                                        '+61',
                                        '+81',
                                        '+92',
                                        '+880',
                                        '+94',
                                        '+65'
                                      ]
                                          .map((code) =>
                                              DropdownMenuItem<String>(
                                                value: code,
                                                child: Text(code),
                                              ))
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedCountryCode = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const VerticalDivider(width: 1),
                                ],
                                Expanded(
                                  child: TextField(
                                    controller: _emailController,
                                    onChanged: (v) => setState(() {}),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                    decoration: InputDecoration(
                                      labelText: 'Email or Mobile Number',
                                      labelStyle: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5)),
                                      prefixIcon: _emailController.text
                                                  .contains('@') ||
                                              _emailController.text.isEmpty ||
                                              !RegExp(r'^\d+$').hasMatch(
                                                  _emailController.text.trim())
                                          ? Icon(Icons.person_outline,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary)
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                  onPressed: (_isLoading || !_canResend)
                                      ? null
                                      : _handleSendOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(_canResend
                                      ? (_otpSent ? 'Resend' : 'Send')
                                      : '${_secondsRemaining}s'),
                                ),
                              ],
                            ),
                          ] else
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_outlined,
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.5),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),

                          // Forgot Password & Toggle Login Mode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: TextButton(
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
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.start,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (!_isOtpLogin)
                                Flexible(
                                  child: TextButton(
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
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
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
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
                      _googleButton(_handleGoogleSignIn),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
            fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14),
          prefixIcon: Icon(icon,
              color: Theme.of(context).colorScheme.primary, size: 22),
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

  Widget _googleButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.g_mobiledata, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}
