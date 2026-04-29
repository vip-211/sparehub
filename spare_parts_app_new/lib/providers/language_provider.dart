import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import '../services/settings_service.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');
  bool _autoTranslate = false;
  final GoogleTranslator _translator = GoogleTranslator();
  final Map<String, String> _cache = {};
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिन्दी',
    'mr': 'मराठी',
  };

  LanguageProvider() {
    _loadLanguage();
    _loadAutoSetting();
  }

  Locale get currentLocale => _currentLocale;
  bool get isHindi => _currentLocale.languageCode == 'hi';
  bool get isMarathi => _currentLocale.languageCode == 'mr';
  bool get isEnglish => _currentLocale.languageCode == 'en';
  bool get autoTranslateEnabled => _autoTranslate;
  String get currentLanguageLabel =>
      supportedLanguages[_currentLocale.languageCode] ?? 'English';
  String get _targetLanguageCode => _currentLocale.languageCode;

  void toggleLanguage() async {
    final nextCode = _currentLocale.languageCode == 'en' ? 'hi' : 'en';
    await setLanguage(nextCode);
  }

  Future<void> setLanguage(String code) async {
    if (!supportedLanguages.containsKey(code)) return;
    _currentLocale = Locale(code);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('language_code') ?? 'en';
    _currentLocale = Locale(code);
    notifyListeners();
  }

  void _loadAutoSetting() async {
    await SettingsService.preloadRemoteSettings();
    _autoTranslate =
        SettingsService.getCachedRemoteSetting('AUTO_TRANSLATE_UI', 'true') ==
            'true';
    notifyListeners();
  }

  String translate(String key) {
    final english = _englishTranslations[key] ?? key;
    return t(english);
  }

  String t(String text) {
    final value = text.trim();
    if (isEnglish || !_shouldTranslate(value)) return text;
    final cacheKey = '$_targetLanguageCode::$value';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    _translator.translate(value, to: _targetLanguageCode).then((v) {
      _cache[cacheKey] = v.text;
      notifyListeners();
    }).catchError((_) {});
    return text;
  }

  bool _shouldTranslate(String text) {
    if (text.isEmpty) return false;
    if (!RegExp(r'[A-Za-z]').hasMatch(text)) return false;
    if (RegExp(r'^[#₹$€£]?\s*[\d.,%+\-xX/ ]+$').hasMatch(text)) return false;
    if (RegExp(r'^[A-Z0-9][A-Z0-9\-_./]{2,}$').hasMatch(text)) return false;
    return true;
  }

  static final Map<String, String> _englishTranslations = {
    // Login
    'login_title': 'Login',
    'login_welcome': 'Welcome to Parts Mitra',
    'login_email': 'Email Address',
    'login_password': 'Password',
    'login_button': 'Login',
    'login_otp_switch': 'Login with OTP',
    'login_pass_switch': 'Login with Password',
    'login_no_account': "Don't have an account? Register",
    'login_forgot_pass': 'Forgot Password?',

    // Register
    'reg_title': 'Create Account',
    'reg_name': 'Full Name',
    'reg_email': 'Email Address',
    'reg_phone': 'Phone Number',
    'reg_password': 'Password',
    'reg_address': 'Business Address',
    'reg_role': 'Role',
    'reg_button': 'Register Account',
    'reg_location': 'Capture Location',
    'reg_has_account': 'Already have an account? Login',

    // Dashboard
    'shop_title': 'Parts Mitra Shop',
    'shop_search': 'Search parts...',
    'shop_stock': 'Stock',
    'shop_add_to_cart': 'Add to Cart',
    'shop_out_of_stock': 'Out of Stock',
    'nav_shop': 'Shop',
    'nav_cart': 'Cart',
    'nav_orders': 'Orders',
    'nav_profile': 'Profile',
    'nav_logout': 'Logout',

    // Common
    'common_loading': 'Loading...',
    'common_success': 'Success',
    'common_error': 'Error',
  };

  static final Map<String, String> _hindiTranslations = {
    // Login
    'login_title': 'लॉगिन',
    'login_welcome': 'पार्ट्स मित्रा में आपका स्वागत है',
    'login_email': 'ईमेल पता',
    'login_password': 'पासवर्ड',
    'login_button': 'लॉगिन करें',
    'login_otp_switch': 'ओटीपी (OTP) के साथ लॉगिन करें',
    'login_pass_switch': 'पासवर्ड के साथ लॉगिन करें',
    'login_no_account': 'खाता नहीं है? पंजीकरण करें',
    'login_forgot_pass': 'पासवर्ड भूल गए?',

    // Register
    'reg_title': 'खाता बनाएं',
    'reg_name': 'पूरा नाम',
    'reg_email': 'ईमेल पता',
    'reg_phone': 'फ़ोन नंबर',
    'reg_password': 'पासवर्ड',
    'reg_address': 'व्यवसाय का पता',
    'reg_role': 'भूमिका',
    'reg_button': 'पंजीकरण करें',
    'reg_location': 'स्थान कैप्चर करें',
    'reg_has_account': 'पहले से ही एक खाता है? लॉगिन करें',

    // Dashboard
    'shop_title': 'पार्ट्स मित्रा शॉप',
    'shop_search': 'पार्ट्स खोजें...',
    'shop_stock': 'स्टॉक',
    'shop_add_to_cart': 'कार्ट में जोड़ें',
    'shop_out_of_stock': 'स्टॉक में नहीं है',
    'nav_shop': 'शॉप',
    'nav_cart': 'कार्ट',
    'nav_orders': 'ऑर्डर',
    'nav_profile': 'प्रोफ़ाइल',
    'nav_logout': 'लॉगआउट',

    // Common
    'common_loading': 'लोड हो रहा है...',
    'common_success': 'सफलता',
    'common_error': 'त्रुटि',
  };
}
