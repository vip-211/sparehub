import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/settings_service.dart';

Future<void> showBatteryOptimizationPromptIfNeeded(BuildContext context) async {
  if (!Platform.isAndroid) return;
  final alreadyShown = await SettingsService.isBatteryPromptShown();
  if (alreadyShown) return;

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Allow Background Notifications'),
      content: const Text(
        'On some Android devices (Xiaomi, Oppo, Vivo, etc.), battery optimizations may '
        'block notifications when the app is closed. To ensure you always receive alerts:\n\n'
        '• Allow notifications for Parts Mitra\n'
        '• Disable battery optimization for the app\n'
        '• Allow auto-start/launch on boot if available',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Remind Me Later'),
        ),
        TextButton(
          onPressed: () async {
            await SettingsService.setBatteryPromptShown(true);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Don’t Show Again'),
        ),
        ElevatedButton(
          onPressed: () async {
            await openAppSettings();
            await SettingsService.setBatteryPromptShown(true);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
}
