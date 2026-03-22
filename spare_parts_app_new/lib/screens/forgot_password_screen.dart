import 'reset_password_screen.dart'; // ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final authProvider =
                        Provider.of<AuthProvider>(context, listen: false);
                    try {
                      await authProvider
                          .sendPasswordResetOtp(_emailController.text);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Password reset OTP sent to your email.')),
                      );
                      // Hint banner to guide if email delivery is flaky
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).clearMaterialBanners();
                        ScaffoldMessenger.of(context).showMaterialBanner(
                          MaterialBanner(
                            content: const Text(
                                'If you do not receive the email OTP, please check spam or contact admin to enable local OTP temporarily.'),
                            leading: const Icon(Icons.info_outline),
                            actions: [
                              TextButton(
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .hideCurrentMaterialBanner(),
                                child: const Text('Dismiss'),
                              ),
                            ],
                            backgroundColor: Colors.orange.shade50,
                          ),
                        );
                      });
                      Navigator.of(context).pushNamed('/reset-password',
                          arguments: _emailController.text);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to send OTP: $e')),
                      );
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ScaffoldMessenger.of(context).clearMaterialBanners();
                        ScaffoldMessenger.of(context).showMaterialBanner(
                          MaterialBanner(
                            content: const Text(
                                'Email delivery seems down. Try again later or contact admin to enable local OTP.'),
                            leading: const Icon(Icons.report_gmailerrorred_outlined),
                            actions: [
                              TextButton(
                                onPressed: () => ScaffoldMessenger.of(context)
                                    .hideCurrentMaterialBanner(),
                                child: const Text('Dismiss'),
                              ),
                            ],
                            backgroundColor: Colors.orange.shade50,
                          ),
                        );
                      });
                    }
                  }
                },
                child: const Text('Send OTP'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
