import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import '../widgets/section_header.dart';

class UserSettingsScreen extends StatelessWidget {
  const UserSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            title: 'Appearance',
            subtitle: 'Customize how the app looks',
          ),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto),
                  label: Text('System')),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Light')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Dark')),
            ],
            selected: {tp.themeMode},
            onSelectionChanged: (sel) => tp.setThemeMode(sel.first),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              tp.refreshSeedFromServer().then((ok) {
                messenger.showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Theme updated from server'
                      : 'Please connect to internet'),
                ));
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Update theme from server'),
          ),
          const SizedBox(height: 16),
          Text('Text Size', style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: tp.textScale,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            label: '${tp.textScale.toStringAsFixed(2)}x',
            onChanged: (v) => tp.setTextScale(v),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          const SectionHeader(
            title: 'Share',
            subtitle: 'Share the app with friends and family',
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.partsmitra.app';
              SharePlus.instance.share(
                ShareParams(
                  text: 'Check out Parts Mitra - the spare parts management app!\n$playStoreUrl',
                  subject: 'Parts Mitra App',
                ),
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('Share App'),
          ),
          const SizedBox(height: 16),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Center(
                  child: Text(
                    'Version ${snapshot.data!.version}+${snapshot.data!.buildNumber}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
