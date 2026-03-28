// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'otp_verification_screen.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';
import 'mobile_otp_verification_screen.dart';
import '../providers/language_provider.dart';

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
  String _selectedCountryCode = '+91';
  bool _isLoading = false;
  bool _obscurePassword = true;
  double? _latitude;
  double? _longitude;

  bool _emailMode = true;
  bool _emailEnabled = true;
  bool _phoneEnabled = true;

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
      _emailEnabled = (remote['ENABLE_EMAIL_REGISTRATION'] ?? 'true') == 'true';
      _phoneEnabled = (remote['ENABLE_PHONE_REGISTRATION'] ?? 'true') == 'true';
      if (!_emailEnabled && _phoneEnabled) _emailMode = false;
      if (raw != null && raw.isNotEmpty) {
        final parts = raw.split(',').map((e) => e.trim()).toList();
        setState(() {
          // Reorder to prioritize Mechanic first when available
          final hasMech = parts.contains(Constants.roleMechanic);
          final prioritized = <String>[];
          if (hasMech) prioritized.add(Constants.roleMechanic);
          if (parts.contains(Constants.roleRetailer)) {
            prioritized.add(Constants.roleRetailer);
          }
          if (parts.contains(Constants.roleWholesaler)) {
            prioritized.add(Constants.roleWholesaler);
          }
          // Keep any remaining roles (admin/super-manager/staff) in original order
          for (final r in parts) {
            if (!prioritized.contains(r)) prioritized.add(r);
          }
          _allowedRoles = prioritized;
          // Default selection: Mechanic if available, else first allowed
          if (hasMech) {
            _selectedRole = Constants.roleMechanic;
          } else if (!_allowedRoles.contains(_selectedRole)) {
            _selectedRole = _allowedRoles.first;
          }
        });
      }
      setState(() {});
    } catch (_) {
      setState(() {});
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
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      // Reverse Geocoding to get address
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String address = [
            if (place.street != null && place.street!.isNotEmpty) place.street,
            if (place.subLocality != null && place.subLocality!.isNotEmpty)
              place.subLocality,
            if (place.locality != null && place.locality!.isNotEmpty)
              place.locality,
            if (place.administrativeArea != null &&
                place.administrativeArea!.isNotEmpty)
              place.administrativeArea,
            if (place.postalCode != null && place.postalCode!.isNotEmpty)
              place.postalCode,
            if (place.country != null && place.country!.isNotEmpty)
              place.country,
          ].join(', ');

          setState(() {
            _addressController.text = address;
          });
        }
      } catch (e) {
        debugPrint('Reverse geocoding error: $e');
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

    if (name.isEmpty || password.isEmpty || email.isEmpty || phone.isEmpty) {
      _showFeedback('Please fill in all required fields.', isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showFeedback('Please enter a valid email address.', isError: true);
      return;
    }

    if (phone.length < 10) {
      _showFeedback('Please enter a valid mobile number.', isError: true);
      return;
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
      final fullPhone =
          (_selectedCountryCode + phone.replaceAll(RegExp(r'\D'), ''));

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

      if (_emailMode) {
        await authProvider.sendOtp(email, registrationData);
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
            await authProvider.register(
              name,
              email,
              password,
              _selectedRole,
              fullPhone,
              address,
              latitude: _latitude,
              longitude: _longitude,
              otp: otp,
            );
            _showFeedback('Registration successful!');
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/thank-you');
            }
          }
        }
      } else {
        if (mounted) {
          await authProvider.verifyPhone(
            fullPhone,
            onCodeSent: (_) {},
            onError: (msg) => _showFeedback(msg, isError: true),
          );
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: fullPhone,
                isRegistration: true,
                registrationData: registrationData,
                isFirebase: true,
              ),
            ),
          );
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/thank-you');
          }
        }
      }
    } catch (e) {
      String msg = e.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.replaceFirst('Exception: ', '');
      }
      _showFeedback('Failed to register: $msg', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          if (_emailEnabled || _phoneEnabled)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_emailEnabled)
                                    ChoiceChip(
                                      label: const Text('Email OTP'),
                                      selected: _emailMode,
                                      onSelected: (v) => setState(() {
                                        if (_emailEnabled) _emailMode = true;
                                      }),
                                    ),
                                  if (_phoneEnabled)
                                    ChoiceChip(
                                      label: const Text('Phone OTP'),
                                      selected: !_emailMode,
                                      onSelected: (v) => setState(() {
                                        if (_phoneEnabled) _emailMode = false;
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          // Header Text
                          Text(
                            Provider.of<LanguageProvider>(context,
                                    listen: false)
                                .t('Create Account'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Provider.of<LanguageProvider>(context,
                                    listen: false)
                                .t('Fill in your details to get started'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                          const SizedBox(height: 24),

                          _buildTextField(
                            controller: _nameController,
                            label: 'Full Name*',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email Address*',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Icon(Icons.phone_android_outlined,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 22),
                                ),
                                const SizedBox(width: 8),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCountryCode,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.bold),
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
                                        .map((code) => DropdownMenuItem<String>(
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
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                    decoration: InputDecoration(
                                      labelText: 'Mobile Number*',
                                      labelStyle: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 14),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
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
                                  : const Text(
                                      'Register',
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
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: Text(
                          'Login',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                Theme.of(context).colorScheme.onPrimary,
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
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
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

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedRole,
          isExpanded: true,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
          dropdownColor: Theme.of(context).colorScheme.surface,
          decoration: InputDecoration(
            labelText: 'Your Role',
            labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14),
            prefixIcon: Icon(
              Icons.work_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
          ),
          items: [
            if (_allowedRoles.contains(Constants.roleMechanic))
              const DropdownMenuItem(
                value: Constants.roleMechanic,
                child: Text('Mechanic'),
              ),
            if (_allowedRoles.contains(Constants.roleRetailer))
              const DropdownMenuItem(
                value: Constants.roleRetailer,
                child: Text('Retailer'),
              ),
            if (_allowedRoles.contains(Constants.roleWholesaler))
              const DropdownMenuItem(
                value: Constants.roleWholesaler,
                child: Text('Wholesaler'),
              ),
            if (_allowedRoles.contains(Constants.roleSuperManager))
              const DropdownMenuItem(
                value: Constants.roleSuperManager,
                child: Text('Super Manager'),
              ),
            if (_allowedRoles.contains(Constants.roleAdmin))
              const DropdownMenuItem(
                value: Constants.roleAdmin,
                child: Text('Admin'),
              ),
          ],
          onChanged: (val) => setState(() => _selectedRole = val!),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    final bool hasLocation = _latitude != null && _longitude != null;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _isLoading ? null : _getCurrentLocation,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: hasLocation
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : colorScheme.secondaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasLocation
                ? colorScheme.primaryContainer
                : colorScheme.secondaryContainer,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasLocation ? Icons.location_on : Icons.my_location,
              color: hasLocation ? colorScheme.primary : colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasLocation
                    ? 'Location Captured'
                    : 'Share Exact Business Location*',
                style: TextStyle(
                  color: hasLocation
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasLocation)
              Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
