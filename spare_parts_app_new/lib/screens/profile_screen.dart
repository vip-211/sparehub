import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:spare_parts_app/screens/edit_profile_screen.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _buildProfileItem(
      BuildContext context, IconData icon, String title, String value,
      {bool isEditable = false, VoidCallback? onEdit, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.2)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1C1E))),
        trailing: trailing ??
            (isEditable
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                        icon: Icon(Icons.edit_rounded,
                            size: 18, color: Colors.grey.shade400),
                        onPressed: onEdit),
                  )
                : null),
      ),
    );
  }

  void _showEditAddressDialog(BuildContext context, AuthProvider authProvider) {
    final controller = TextEditingController(text: authProvider.user?.address);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Address'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), hintText: 'Enter your address'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await authProvider.updateAddress(controller.text);
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _pickShopImage(BuildContext context, AuthProvider authProvider) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await authProvider.updateShopImage(image.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Shop image updated!')));
      }
    }
  }

  void _showVerifyPhoneDialog(BuildContext context, AuthProvider authProvider) {
    final otpController = TextEditingController();
    authProvider.sendVerificationOtp();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Phone Number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('A 6-digit OTP has been sent to your email.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
              ),
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await authProvider.verifyPhoneNumber(otpController.text);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Phone verified successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Verification failed: $e')),
                  );
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: user?.shopImagePath != null
                              ? FileImage(File(user!.shopImagePath!))
                              : null,
                          child: user?.shopImagePath == null
                              ? Icon(Icons.store_rounded,
                                  size: 60,
                                  color: Theme.of(context).primaryColor)
                              : null,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.camera_alt_rounded,
                              size: 20, color: Theme.of(context).primaryColor),
                          onPressed: () =>
                              _pickShopImage(context, authProvider),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user?.roles.join(' • ').toUpperCase() ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PROFILE INFORMATION',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1C1E),
                            letterSpacing: 1.5),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EditProfileScreen()),
                          );
                        },
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        label: const Text('EDIT ALL',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem(
                    context,
                    Icons.email_outlined,
                    'EMAIL ADDRESS',
                    user?.email ?? '',
                  ),
                  _buildProfileItem(
                    context,
                    Icons.phone_outlined,
                    'PHONE NUMBER',
                    user?.phone ?? 'Not provided',
                    trailing: user?.phoneVerified == true
                        ? const Icon(Icons.verified_rounded,
                            color: Colors.blue, size: 20)
                        : TextButton(
                            onPressed: () =>
                                _showVerifyPhoneDialog(context, authProvider),
                            child: const Text('VERIFY',
                                style: TextStyle(
                                    fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                  ),
                  _buildProfileItem(
                    context,
                    Icons.location_on_outlined,
                    'DELIVERY ADDRESS',
                    user?.address ?? 'No address set',
                    isEditable: true,
                    onEdit: () => _showEditAddressDialog(context, authProvider),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SHOP VERIFICATION',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1C1E),
                        letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        if (user?.shopImagePath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              File(user!.shopImagePath!),
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 40, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                Text('Upload Shop Photo for Faster Delivery',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade400)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _pickShopImage(context, authProvider),
                            icon:
                                const Icon(Icons.camera_alt_rounded, size: 18),
                            label: Text(user?.shopImagePath != null
                                ? 'UPDATE SHOP PHOTO'
                                : 'UPLOAD SHOP PHOTO'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => authProvider.logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('LOGOUT ACCOUNT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
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
}
