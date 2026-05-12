// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'otp_verification_screen.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool showAppBar;
  const RegisterScreen({super.key, this.showAppBar = false});

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
  String _selectedCountryCode = '+91';
  bool _isLoading = false;
  bool _obscurePassword = true;
  double? _latitude;
  double? _longitude;

  List<String> _allowedRoles = [
    Constants.roleMechanic,
    Constants.roleRetailer,
    Constants.roleWholesaler
  ];

  @override
  void initState() {
    super.initState();
    _loadAllowedRoles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAllowedRoles() async {
    try {
      final remote = await SettingsService.getRemoteSettings();
      final raw = remote['ALLOWED_REG_ROLES'];
      if (raw != null && raw.isNotEmpty) {
        final parts = raw.split(',').map((e) => e.trim()).toList();
        setState(() {
          _allowedRoles = parts;
          if (!_allowedRoles.contains(_selectedRole)) {
            _selectedRole = _allowedRoles.first;
          }
        });
      }
    } catch (_) {}
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

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        setState(() => _addressController.text = address);
      }
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

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showFeedback('Please fill in all fields.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fullPhone = _selectedCountryCode + phone.replaceAll(RegExp(r'\D'), '');
      final registrationData = {
        'name': name,
        'email': email,
        'password': password,
        'role': _selectedRole,
        'phone': fullPhone,
        'address': address,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      await Provider.of<AuthProvider>(context, listen: false).sendOtp(email, registrationData);
      
      if (mounted) {
        final otp = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email: email,
              isRegistration: true,
              registrationData: registrationData,
              isFirebase: false,
            ),
          ),
        );

        if (otp != null) {
          await Provider.of<AuthProvider>(context, listen: false).register(
            name, email, password, _selectedRole, fullPhone, address,
            latitude: _latitude, longitude: _longitude, otp: otp,
          );
          Navigator.of(context).pushReplacementNamed('/thank-you');
        }
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
            // Header
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(80)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeInDown(
                      child: Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInUp(
                      child: Text(
                        'Join Parts Mitra today',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  // Form Fields
                  _buildInputField(
                    controller: _nameController,
                    hint: 'Full Name',
                    icon: Icons.person_outline,
                    delay: 200,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _emailController,
                    hint: 'Email Address',
                    icon: Icons.email_outlined,
                    delay: 300,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _phoneController,
                    hint: 'Mobile Number',
                    icon: Icons.phone_android_rounded,
                    delay: 400,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outlined,
                    delay: 500,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Role Selector
                  FadeInLeft(
                    delay: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRole,
                          isExpanded: true,
                          items: _allowedRoles.map((role) {
                            return DropdownMenuItem(value: role, child: Text(role.toUpperCase()));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedRole = val!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address with Location Button
                  FadeInLeft(
                    delay: const Duration(milliseconds: 700),
                    child: TextField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Business Address',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location, color: AppTheme.primaryBlue),
                          onPressed: _getCurrentLocation,
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Register Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 800),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Login Link
                  FadeInUp(
                    delay: const Duration(milliseconds: 900),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account? ", style: TextStyle(color: Colors.grey.shade600)),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text('Login', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w800, fontSize: 16)),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int delay = 0,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return FadeInLeft(
      delay: Duration(milliseconds: delay),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}
