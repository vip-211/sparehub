import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../services/settings_service.dart';

class AuthHomeScreen extends StatefulWidget {
  const AuthHomeScreen({super.key});

  @override
  State<AuthHomeScreen> createState() => _AuthHomeScreenState();
}

class _AuthHomeScreenState extends State<AuthHomeScreen>
    with WidgetsBindingObserver {
  bool _loading = false;
  StreamSubscription<String>? _settingsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsSub = SettingsService.onSettingsChanged.listen((key) async {
      if (key == 'HIDE_REGISTRATION') {
        await _refresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    await SettingsService.preloadRemoteSettings();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hideRegistration =
        SettingsService.getCachedRemoteSetting('HIDE_REGISTRATION', 'false') ==
            'true';
    final tabs = <Tab>[
      const Tab(text: 'Login'),
      if (!hideRegistration) const Tab(text: 'Register'),
    ];
    final views = <Widget>[
      const LoginScreen(showAppBar: false, minimal: true),
      if (!hideRegistration) const RegisterScreen(showAppBar: false),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Spares Hub'),
          bottom: TabBar(tabs: tabs),
          actions: [
            IconButton(
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ],
        ),
        body: TabBarView(children: views),
      ),
    );
  }
}
