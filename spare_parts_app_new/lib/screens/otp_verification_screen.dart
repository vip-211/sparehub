// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_exceptions.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final Map<String, dynamic>? registrationData;
  final bool isRegistration;
  final bool isFirebase;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.registrationData,
    this.isRegistration = false,
    this.isFirebase = false,
  });

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Timer? _timer;
  int _secondsRemaining = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
                  // OTP Card
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Icon Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.mark_email_read_outlined,
                                size: 60,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Header Text
                            const Text(
                              'Verification',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter the 6-digit code sent to\n${widget.email}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 32),

                            // OTP Input
                            TextFormField(
                              controller: _otpController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 8,
                              ),
                              decoration: InputDecoration(
                                hintText: '000000',
                                hintStyle:
                                    TextStyle(color: Colors.grey.shade300),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                      color: Colors.green.shade600, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter the OTP';
                                }
                                if (value.length != 6) {
                                  return 'OTP must be 6 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),

                            // Verify Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        if (_formKey.currentState!.validate()) {
                                          setState(() => _isLoading = true);
                                          final authProvider =
                                              Provider.of<AuthProvider>(
                                            context,
                                            listen: false,
                                          );
                                          try {
                                            if (widget.registrationData !=
                                                null) {
                                              // Registration logic
                                              String? firebaseToken;
                                              if (widget.isFirebase) {
                                                firebaseToken = await authProvider
                                                    .verifyPhoneCodeAndGetToken(
                                                  _otpController.text,
                                                );
                                                if (firebaseToken == null) {
                                                  throw 'Firebase verification failed';
                                                }
                                              }

                                              final success =
                                                  await authProvider.register(
                                                widget
                                                    .registrationData!['name'],
                                                widget
                                                    .registrationData!['email'],
                                                widget.registrationData![
                                                    'password'],
                                                widget
                                                    .registrationData!['role'],
                                                widget.registrationData![
                                                        'phone'] ??
                                                    '',
                                                widget.registrationData![
                                                        'address'] ??
                                                    '',
                                                latitude:
                                                    widget.registrationData![
                                                        'latitude'],
                                                longitude:
                                                    widget.registrationData![
                                                        'longitude'],
                                                otp: widget.isFirebase
                                                    ? null
                                                    : _otpController.text,
                                                firebaseToken: firebaseToken,
                                              );
                                              if (success) {
                                                if (mounted) {
                                                  setState(
                                                      () => _isLoading = false);
                                                }
                                                if (mounted) {
                                                  Navigator.of(context)
                                                      .pushNamedAndRemoveUntil(
                                                          '/thank-you',
                                                          (route) => false);
                                                }
                                              } else {
                                                _showFeedback(
                                                    'Registration failed. Please try again.',
                                                    isError: true);
                                              }
                                            } else {
                                              // Registration flow expects OTP string result
                                              final otpValue =
                                                  _otpController.text;
                                              if (otpValue.length == 6) {
                                                if (mounted) {
                                                  setState(
                                                      () => _isLoading = false);
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback(
                                                          (_) {
                                                    Navigator.of(context)
                                                        .pop(otpValue);
                                                  });
                                                }
                                              } else {
                                                _showFeedback(
                                                    'OTP must be 6 digits',
                                                    isError: true);
                                              }
                                            }
                                          } catch (e) {
                                            String msg = e.toString();
                                            if (msg.startsWith('Exception: ')) {
                                              msg = msg.replaceFirst(
                                                  'Exception: ', '');
                                            }
                                            _showFeedback(msg, isError: true);
                                          } finally {
                                            if (mounted)
                                              setState(
                                                  () => _isLoading = false);
                                          }
                                        }
                                      },
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
                                            color: Colors.white))
                                    : const Text(
                                        'Verify & Continue',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Resend OTP
                            TextButton(
                              onPressed: (!_isLoading && _canResend)
                                  ? () async {
                                      setState(() => _isLoading = true);
                                      try {
                                        final authProvider =
                                            Provider.of<AuthProvider>(
                                          context,
                                          listen: false,
                                        );
                                        if (widget.isFirebase) {
                                          await authProvider.verifyPhone(
                                            widget.email,
                                            onCodeSent: (verId) {
                                              _showFeedback(
                                                  'OTP resent via Firebase');
                                              _startTimer();
                                            },
                                            onError: (err) {
                                              _showFeedback(
                                                  'Firebase Phone Auth failed: $err',
                                                  isError: true);
                                            },
                                          );
                                        } else {
                                          final source =
                                              await authProvider.sendOtp(
                                            widget.email,
                                            widget.registrationData ?? {},
                                          );
                                          final via = source == 'server'
                                              ? 'SMS/Server'
                                              : 'Email';
                                          _showFeedback('OTP resent via $via');
                                          _startTimer(); // Restart the 30s timer
                                        }
                                      } catch (e) {
                                        _showFeedback(e.toString(),
                                            isError: true);
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isLoading = false);
                                        }
                                      }
                                    }
                                  : null,
                              child: Text(
                                _canResend
                                    ? 'Resend OTP Code'
                                    : 'Resend in ${_secondsRemaining}s',
                                style: TextStyle(
                                  color: _canResend
                                      ? Colors.green.shade700
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Back to Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Entered wrong details? ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              Navigator.of(context).pop();
                            });
                          }
                        },
                        child: const Text(
                          'Go Back',
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
}
