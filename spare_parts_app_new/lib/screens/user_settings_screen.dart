import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        ],
      ),
    );
  }
}
