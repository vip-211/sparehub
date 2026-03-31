import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/theme_provider.dart';
import '../services/settings_service.dart';
import '../widgets/section_header.dart';
import '../utils/constants.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _voice = true;
  bool _ai = true;
  bool _ws = false;
  bool _localOtp = false;
  bool _notifInApp = true;
  bool _notifWhatsApp = false;

  // New Global Settings
  bool _wsGlobal = true;
  bool _localOtpGlobal = false;
  final TextEditingController _logoUrlController = TextEditingController();
  final TextEditingController _serverHostController = TextEditingController();
  final TextEditingController _googleClientIdController =
      TextEditingController();
  final TextEditingController _resetPasswordPathController =
      TextEditingController();
  final TextEditingController _altResetPasswordPathController =
      TextEditingController();
  final TextEditingController _changePasswordPathController =
      TextEditingController();
  final TextEditingController _otpLoginPathController = TextEditingController();
  final TextEditingController _locationIdPathController =
      TextEditingController();
  final TextEditingController _locationBodyPathController =
      TextEditingController();
  final TextEditingController _loyaltyPercentController =
      TextEditingController();
  final TextEditingController _minRedeemPointsController =
      TextEditingController();
  final TextEditingController _loginBannerTextController =
      TextEditingController();
  final TextEditingController _loginBannerImageUrlController =
      TextEditingController();
  final TextEditingController _loginBannerButtonTextController =
      TextEditingController();
  final TextEditingController _loginBannerCooldownController =
      TextEditingController();
  final TextEditingController _latestVersionController = TextEditingController();
  final TextEditingController _updateUrlController = TextEditingController();
  final Map<String, bool> _allowedRoles = {
    Constants.roleMechanic: true,
    Constants.roleRetailer: true,
    Constants.roleWholesaler: true,
    Constants.roleStaff: false,
    Constants.roleAdmin: false,
    Constants.roleSuperManager: false,
  };

  bool _loaded = false;
  late ThemeProvider _themeProvider;
  final List<Color> _colorChoices = const [
    Color(0xFF2E7D32), // Emerald
    Color(0xFF1565C0), // Royal Blue
    Color(0xFFFFB300), // Amber
    Color(0xFF7E57C2), // Purple
    Color(0xFFD32F2F), // Red
  ];
  bool _useGlobalThemeColor = false;
  bool _hideRegistration = false;
  bool _enableEmailReg = true;
  bool _enablePhoneReg = true;
  bool _otpModeEmail = true;
  bool _autoTranslateUi = false;
  String? _lastOtpError;
  int? _lastOtpErrorAt;
  bool _loginBannerEnabled = false;
  bool _loginBannerShowButton = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _logoUrlController.dispose();
    _serverHostController.dispose();
    _googleClientIdController.dispose();
    _resetPasswordPathController.dispose();
    _altResetPasswordPathController.dispose();
    _changePasswordPathController.dispose();
    _otpLoginPathController.dispose();
    _locationIdPathController.dispose();
    _locationBodyPathController.dispose();
    _loyaltyPercentController.dispose();
    _minRedeemPointsController.dispose();
    _loginBannerTextController.dispose();
    _loginBannerImageUrlController.dispose();
    _loginBannerButtonTextController.dispose();
    _loginBannerCooldownController.dispose();
    _latestVersionController.dispose();
    _updateUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Theme is managed by ThemeProvider; no need to read here
      final v = await SettingsService.isVoiceTrainingEnabled();
      final a = await SettingsService.isAiChatbotEnabled();
      final w = await SettingsService.isWebSocketEnabled();
      final o = await SettingsService.isForceLocalOtp();
      final remote = await SettingsService.getRemoteSettings();
      final last = await SettingsService.getLastOtpFailure();
      if (mounted) {
        setState(() {
          _voice = v;
          _ai = a;
          _ws = w;
          _localOtp = o;

          _notifInApp = remote['NOTIF_IN_APP_ENABLED'] == 'true';
          _notifWhatsApp = remote['NOTIF_WHATSAPP_ENABLED'] == 'true';

          // Load Global Settings
          _wsGlobal = (remote['WS_ENABLED'] ?? 'true') == 'true';
          _localOtpGlobal = (remote['FORCE_LOCAL_OTP'] ?? 'false') == 'true';
          _logoUrlController.text = remote['LOGO_URL'] ?? '';
          _serverHostController.text =
              remote['SERVER_HOST'] ?? 'partsmitra.onrender.com';
          _googleClientIdController.text = remote['GOOGLE_CLIENT_ID'] ?? '';
          _resetPasswordPathController.text =
              remote['RESET_PASSWORD_PATH'] ?? '/auth/reset-password';
          _altResetPasswordPathController.text =
              remote['ALT_RESET_PASSWORD_PATH'] ?? '/auth/password/reset';
          _changePasswordPathController.text =
              remote['CHANGE_PASSWORD_PATH'] ?? '/auth/change-password';
          _otpLoginPathController.text =
              remote['OTP_LOGIN_PATH'] ?? '/auth/otp-login';
          _locationIdPathController.text =
              remote['LOCATION_ID_PATH'] ?? '/admin/users/{id}/location';
          _locationBodyPathController.text =
              remote['LOCATION_BODY_PATH'] ?? '/admin/users/update-location';
          _loyaltyPercentController.text = remote['LOYALTY_PERCENT'] ?? '1';
          _minRedeemPointsController.text = remote['MIN_REDEEM_POINTS'] ?? '0';

          final allowedStr = remote['ALLOWED_REG_ROLES'] ??
              '${Constants.roleMechanic},${Constants.roleRetailer},${Constants.roleWholesaler}';
          final parts = allowedStr.split(',').map((e) => e.trim()).toSet();
          _allowedRoles.updateAll((key, value) => parts.contains(key));

          _useGlobalThemeColor =
              (remote['USE_GLOBAL_THEME_COLOR'] ?? 'false') == 'true';
          _hideRegistration =
              (remote['HIDE_REGISTRATION'] ?? 'false') == 'true';
          _enableEmailReg =
              (remote['ENABLE_EMAIL_REGISTRATION'] ?? 'true') == 'true';
          _enablePhoneReg =
              (remote['ENABLE_PHONE_REGISTRATION'] ?? 'true') == 'true';
          _autoTranslateUi = (remote['AUTO_TRANSLATE_UI'] ?? 'false') == 'true';
          _otpModeEmail =
              (remote['OTP_MODE'] ?? 'EMAIL').toUpperCase() != 'LOCAL';
          if (last != null) {
            _lastOtpError = last['message'] as String?;
            _lastOtpErrorAt = last['at'] as int?;
          }
          _loginBannerEnabled =
              (remote['LOGIN_BANNER_ENABLED'] ?? 'false') == 'true';
          _loginBannerTextController.text = remote['LOGIN_BANNER_TEXT'] ?? '';
          _loginBannerImageUrlController.text =
              remote['LOGIN_BANNER_IMAGE_URL'] ?? '';
          _loginBannerShowButton =
              (remote['LOGIN_BANNER_SHOW_BUTTON'] ?? 'false') == 'true';
          _loginBannerButtonTextController.text =
              remote['LOGIN_BANNER_BUTTON_TEXT'] ?? 'Check Offers';
          _loginBannerCooldownController.text =
              remote['LOGIN_BANNER_COOLDOWN_HOURS'] ?? '24';
          _latestVersionController.text = remote['LATEST_APP_VERSION'] ?? '1.0.0';
          _updateUrlController.text = remote['APP_UPDATE_URL'] ?? '';
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SettingsService.setVoiceTrainingEnabled(_voice);
      await SettingsService.setAiChatbotEnabled(_ai);
      await SettingsService.setWebSocketEnabled(_ws);
      await SettingsService.setForceLocalOtp(_localOtp);

      // Prepare Remote Settings Map
      final remoteMap = {
        'NOTIF_IN_APP_ENABLED': _notifInApp ? 'true' : 'false',
        'NOTIF_WHATSAPP_ENABLED': _notifWhatsApp ? 'true' : 'false',
        'WS_ENABLED': _wsGlobal ? 'true' : 'false',
        'FORCE_LOCAL_OTP': _localOtpGlobal ? 'true' : 'false',
        'USE_GLOBAL_THEME_COLOR': _useGlobalThemeColor ? 'true' : 'false',
        'HIDE_REGISTRATION': _hideRegistration ? 'true' : 'false',
        'ENABLE_EMAIL_REGISTRATION': _enableEmailReg ? 'true' : 'false',
        'ENABLE_PHONE_REGISTRATION': _enablePhoneReg ? 'true' : 'false',
        'OTP_MODE': _otpModeEmail ? 'EMAIL' : 'LOCAL',
        'AUTO_TRANSLATE_UI': _autoTranslateUi ? 'true' : 'false',
        'THEME_SEED_COLOR': _themeProvider.seedColor.value.toString(),
        'LOGO_URL': _logoUrlController.text,
        'SERVER_HOST': _serverHostController.text,
        'GOOGLE_CLIENT_ID': _googleClientIdController.text,
        'LOYALTY_PERCENT': _loyaltyPercentController.text,
        'MIN_REDEEM_POINTS': _minRedeemPointsController.text,
        'ALLOWED_REG_ROLES': _allowedRoles.entries
            .where((e) => e.value)
            .map((e) => e.key)
            .join(','),
        'LOGIN_BANNER_ENABLED': _loginBannerEnabled ? 'true' : 'false',
        'LOGIN_BANNER_TEXT': _loginBannerTextController.text,
        'LOGIN_BANNER_IMAGE_URL': _loginBannerImageUrlController.text,
        'LOGIN_BANNER_SHOW_BUTTON': _loginBannerShowButton ? 'true' : 'false',
        'LOGIN_BANNER_BUTTON_TEXT': _loginBannerButtonTextController.text,
        'LOGIN_BANNER_COOLDOWN_HOURS': _loginBannerCooldownController.text,
        'LATEST_APP_VERSION': _latestVersionController.text,
        'APP_UPDATE_URL': _updateUrlController.text,
      };

      await SettingsService.saveRemoteSettingsBulk(remoteMap);
      await SettingsService.preloadRemoteSettings();

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text('Error saving settings: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Theme Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _themeProvider.seedColor,
            onColorChanged: (c) => _themeProvider.setSeedColor(c),
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _themeProvider = Provider.of<ThemeProvider>(context);
    final currentTheme = _themeProvider.themeMode;
    final currentSeed = _themeProvider.seedColor;
    final textScale = _themeProvider.textScale;
    final animationSpeed = _themeProvider.animationSpeed;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_lastOtpError != null)
                  Card(
                    color: Colors.orange.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.orange.shade200)),
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      title: const Text('Recent OTP delivery error'),
                      subtitle: Text(_lastOtpError!),
                      trailing: TextButton(
                        onPressed: () async {
                          await SettingsService.clearLastOtpFailure();
                          if (mounted) {
                            setState(() {
                              _lastOtpError = null;
                              _lastOtpErrorAt = null;
                            });
                          }
                        },
                        child: const Text('Clear'),
                      ),
                    ),
                  ),
                const SectionHeader(
                    title: 'Appearance',
                    subtitle: 'Customize app look and feel'),
                const SizedBox(height: 8),

                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Primary Color',
                      style: Theme.of(context).textTheme.labelLarge),
                  subtitle: const Text('Choose a custom seed color for the app'),
                  trailing: GestureDetector(
                    onTap: _showColorPicker,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: currentSeed,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                        boxShadow: [
                          BoxShadow(
                            color: currentSeed.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Use global theme color (all users)'),
                  value: _useGlobalThemeColor,
                  onChanged: (v) => setState(() => _useGlobalThemeColor = v),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final messenger = ScaffoldMessenger.of(context);
                      _themeProvider.refreshSeedFromServer().then((ok) {
                        messenger.showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Theme updated from server'
                              : 'Please connect to internet'),
                        ));
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Apply Global Theme Now'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Text Size',
                    style: Theme.of(context).textTheme.labelLarge),
                Slider(
                  value: textScale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 6,
                  label: '${textScale.toStringAsFixed(2)}x',
                  onChanged: (v) => _themeProvider.setTextScale(v),
                ),
                const SizedBox(height: 8),
                Text('Animation Speed',
                    style: Theme.of(context).textTheme.labelLarge),
                Slider(
                  value: animationSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  label: '${animationSpeed.toStringAsFixed(2)}x',
                  onChanged: (v) => _themeProvider.setAnimationSpeed(v),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('AI Training Report'),
                  subtitle:
                      const Text('Review samples and export CSV for analysis'),
                  onTap: () =>
                      Navigator.of(context).pushNamed('/admin/ai-training'),
                ),
                const Divider(),
                const SectionHeader(
                    title: 'Local App Settings',
                    subtitle: 'These apply to this device only'),
                SwitchListTile(
                  title: const Text('Enable Voice Training'),
                  value: _voice,
                  onChanged: (v) => setState(() => _voice = v),
                ),
                SwitchListTile(
                  title: const Text('Hide Registration Page'),
                  subtitle: const Text('Remove the Register tab for all users'),
                  value: _hideRegistration,
                  onChanged: (v) => setState(() => _hideRegistration = v),
                ),
                SwitchListTile(
                  title: const Text('Enable Email Registration'),
                  subtitle: const Text('Show Email-only registration page'),
                  value: _enableEmailReg,
                  onChanged: (v) => setState(() => _enableEmailReg = v),
                ),
                SwitchListTile(
                  title: const Text('Enable Phone Registration'),
                  subtitle: const Text('Show Phone-only registration page'),
                  value: _enablePhoneReg,
                  onChanged: (v) => setState(() => _enablePhoneReg = v),
                ),
                SwitchListTile(
                  title: const Text('Enable AI Chatbot'),
                  value: _ai,
                  onChanged: (v) => setState(() => _ai = v),
                ),
                ListTile(
                  title: const Text('OTP Delivery Mode'),
                  subtitle: const Text(
                      'EMAIL uses SendGrid; LOCAL prints OTP in server logs'),
                  trailing: DropdownButton<bool>(
                    value: _otpModeEmail,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('EMAIL')),
                      DropdownMenuItem(value: false, child: Text('LOCAL')),
                    ],
                    onChanged: (v) => setState(() => _otpModeEmail = v ?? true),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Enable Auto Hindi Translation'),
                  subtitle:
                      const Text('Automatically translate UI text to Hindi'),
                  value: _autoTranslateUi,
                  onChanged: (v) => setState(() => _autoTranslateUi = v),
                ),
                SwitchListTile(
                  title: const Text('Enable WebSocket'),
                  value: _ws,
                  onChanged: (v) => setState(() => _ws = v),
                ),
                SwitchListTile(
                  title: const Text('Force Local Email OTP'),
                  value: _localOtp,
                  onChanged: (v) => setState(() => _localOtp = v),
                ),
                const Divider(),
                const SectionHeader(
                    title: 'Global System Settings',
                    subtitle: 'Affects all devices (Stored on Server)'),
                SwitchListTile(
                  title: const Text('Global WebSocket'),
                  subtitle: const Text('Enable/Disable WS for all clients'),
                  value: _wsGlobal,
                  onChanged: (v) => setState(() => _wsGlobal = v),
                ),
                SwitchListTile(
                  title: const Text('Global Force Local OTP'),
                  subtitle: const Text('Force local OTP for all clients'),
                  value: _localOtpGlobal,
                  onChanged: (v) => setState(() => _localOtpGlobal = v),
                ),
                _buildTextField(
                    'Logo URL', _logoUrlController, 'URL for the app logo'),
                _buildTextField('Server Host', _serverHostController,
                    'Backend API host (e.g. example.com)'),
                _buildTextField('Google Client ID', _googleClientIdController,
                    'Google OAuth Client ID'),
                const Divider(),
                const SectionHeader(
                    title: 'Login Banner',
                    subtitle: 'Show a message on the login screen'),
                SwitchListTile(
                  title: const Text('Enable Login Banner'),
                  value: _loginBannerEnabled,
                  onChanged: (v) => setState(() => _loginBannerEnabled = v),
                ),
                _buildTextField('Banner Text', _loginBannerTextController,
                    'e.g., Today\'s offer: 10% off on brake pads'),
                _buildTextField('Banner Image URL (Optional)',
                    _loginBannerImageUrlController, 'Direct link to an image'),
                SwitchListTile(
                  title: const Text('Show Action Button'),
                  subtitle: const Text('Adds a button to navigate to Offers'),
                  value: _loginBannerShowButton,
                  onChanged: (v) => setState(() => _loginBannerShowButton = v),
                ),
                if (_loginBannerShowButton)
                  _buildTextField('Button Text',
                      _loginBannerButtonTextController, 'e.g., View Deals'),
                _buildTextField('Banner Cooldown (hours)',
                    _loginBannerCooldownController, 'e.g., 24',
                    keyboardType: TextInputType.number),
                const Divider(),
                const SectionHeader(
                    title: 'App Updates',
                    subtitle: 'Manage app version and update link'),
                _buildTextField('Latest App Version', _latestVersionController,
                    'e.g. 1.0.1 (must match pubspec version)'),
                _buildTextField('App Update URL', _updateUrlController,
                    'Link to Play Store or APK download'),
                const Divider(),
                const SectionHeader(
                    title: 'Loyalty & Points',
                    subtitle: 'Manage reward system'),
                _buildTextField('Loyalty Percent', _loyaltyPercentController,
                    'Percentage of order amount given as points',
                    keyboardType: TextInputType.number),
                _buildTextField('Min Redeem Points', _minRedeemPointsController,
                    'Minimum points required to redeem',
                    keyboardType: TextInputType.number),
                const Divider(),
                const SectionHeader(
                    title: 'User Registration Controls',
                    subtitle:
                        'Restrict which roles are available during sign-up'),
                ..._allowedRoles.keys.map((role) {
                  return SwitchListTile(
                    title: Text(role.replaceFirst('ROLE_', '')),
                    subtitle: const Text('Visible in registration'),
                    value: _allowedRoles[role] ?? false,
                    onChanged: (v) => setState(() => _allowedRoles[role] = v),
                  );
                }).toList(),
                const Divider(),
                const SectionHeader(
                    title: 'Global Notification Settings',
                    subtitle: 'Affects all users'),
                SwitchListTile(
                  title: const Text('In-App Notifications'),
                  subtitle: const Text('Notify users when new products launch'),
                  value: _notifInApp,
                  onChanged: (v) => setState(() => _notifInApp = v),
                ),
                SwitchListTile(
                  title: const Text('WhatsApp Notifications'),
                  subtitle: const Text('Send WhatsApp alerts for new products'),
                  value: _notifWhatsApp,
                  onChanged: (v) => setState(() => _notifWhatsApp = v),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Save All Settings'),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, String hint,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: keyboardType,
      ),
    );
  }
}
