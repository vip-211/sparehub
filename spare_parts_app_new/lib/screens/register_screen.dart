// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'otp_verification_screen.dart';
import '../services/sso_mobile.dart'
    if (dart.library.html) '../services/sso_web.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RegisterScreen extends StatefulWidget {
  final bool showAppBar;
  const RegisterScreen({super.key, this.showAppBar = true});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedRole = Constants.roleMechanic;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isEmailRegistration = true; // Toggle between Email and Mobile
  double? _latitude;
  double? _longitude;

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

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showFeedback(
        'Location services are disabled. Please enable them.',
        isError: true,
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showFeedback('Location permissions are denied.', isError: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showFeedback(
        'Location permissions are permanently denied. Please enable in settings.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _showFeedback('Location captured successfully!');
    } catch (e) {
      _showFeedback('Error getting location: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final address = _addressController.text.trim();

    if (name.isEmpty || password.isEmpty) {
      _showFeedback('Please fill in name and password.', isError: true);
      return;
    }

    if (_isEmailRegistration && email.isEmpty) {
      _showFeedback('Please enter your email address.', isError: true);
      return;
    }

    if (!_isEmailRegistration && phone.isEmpty) {
      _showFeedback('Please enter your mobile number.', isError: true);
      return;
    }

    if (_isEmailRegistration) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        _showFeedback('Please enter a valid email address.', isError: true);
        return;
      }
    } else {
      if (phone.length < 10) {
        _showFeedback('Please enter a valid mobile number.', isError: true);
        return;
      }
    }

    if (password.length < 6) {
      _showFeedback('Password must be at least 6 characters.', isError: true);
      return;
    }

    if (!Constants.useRemote && (_latitude == null || _longitude == null)) {
      _showFeedback('Please capture your location to register.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final registrationData = {
        'name': name,
        'email': _isEmailRegistration ? email : '$phone@spares.hub',
        'password': password,
        'role': _selectedRole,
        'phone': phone,
        'address': address,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      final target = _isEmailRegistration ? email : phone;
      await authProvider.sendOtp(target, registrationData);

      if (mounted) {
        _showFeedback(
            'OTP sent to your ${_isEmailRegistration ? "email" : "mobile"}.');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: target,
              registrationData: registrationData,
            ),
          ),
        );
      }
    } catch (e) {
      _showFeedback('Failed to send OTP: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          _showFeedback('Google Sign-In successful!');
        }
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('Exception: '))
        msg = msg.replaceFirst('Exception: ', '');
      _showFeedback('Google Sign-In failed: $msg', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 20),
                  // Register Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          // Header Text
                          const Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fill in your details to get started',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 24),

                          // Registration Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _isEmailRegistration = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: _isEmailRegistration
                                            ? Colors.green.shade600
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Email',
                                          style: TextStyle(
                                            color: _isEmailRegistration
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _isEmailRegistration = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: !_isEmailRegistration
                                            ? Colors.green.shade600
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Mobile',
                                          style: TextStyle(
                                            color: !_isEmailRegistration
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name*',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          if (_isEmailRegistration)
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email Address*',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            )
                          else
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Mobile Number*',
                              icon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Password*',
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
                          const SizedBox(height: 16),

                          // Role Dropdown
                          _buildDropdown(),
                          const SizedBox(height: 16),

                          _buildTextField(
                            controller: _addressController,
                            label: 'Shop Address (Optional)',
                            icon: Icons.location_on_outlined,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 24),

                          // Location Capture Button
                          _buildLocationButton(),
                          const SizedBox(height: 32),

                          // Register Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
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
                                  : const Text(
                                      'Send OTP & Register',
                                      style: TextStyle(
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

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Login',
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
    int maxLines = 1,
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
        maxLines: maxLines,
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

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: InputDecoration(
            labelText: 'Your Role',
            labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            prefixIcon: Icon(
              Icons.work_outlined,
              color: Colors.green.shade600,
              size: 22,
            ),
            border: InputBorder.none,
          ),
          items: [
            DropdownMenuItem(
              value: Constants.roleWholesaler,
              child: const Text('Wholesaler'),
            ),
            DropdownMenuItem(
              value: Constants.roleRetailer,
              child: const Text('Retailer'),
            ),
            DropdownMenuItem(
              value: Constants.roleMechanic,
              child: const Text('Mechanic'),
            ),
            DropdownMenuItem(
              value: Constants.roleSuperManager,
              child: const Text('Super Manager'),
            ),
          ],
          onChanged: (val) => setState(() => _selectedRole = val!),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    final bool hasLocation = _latitude != null && _longitude != null;
    return InkWell(
      onTap: _isLoading ? null : _getCurrentLocation,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: hasLocation ? Colors.blue.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasLocation ? Colors.blue.shade100 : Colors.orange.shade100,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasLocation ? Icons.location_on : Icons.my_location,
              color:
                  hasLocation ? Colors.blue.shade700 : Colors.orange.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasLocation
                    ? 'Location Captured'
                    : 'Share Exact Business Location*',
                style: TextStyle(
                  color: hasLocation
                      ? Colors.blue.shade700
                      : Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasLocation)
              Icon(Icons.check_circle, color: Colors.blue.shade700, size: 20),
          ],
        ),
      ),
    );
  }
}
