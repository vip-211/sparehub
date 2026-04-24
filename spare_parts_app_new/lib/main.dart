import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/language_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/login_screen.dart';
import 'screens/retailer_dashboard.dart';
import 'screens/mechanic_dashboard.dart';
import 'screens/wholesaler_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'screens/staff_dashboard.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'utils/constants.dart';
import 'screens/auth_home_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/retailer_orders_screen.dart';
import 'screens/user_settings_screen.dart';
import 'widgets/oem_battery_prompt.dart';
import 'screens/admin_ai_training_report_screen.dart';
import 'screens/thank_you_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/mechanic_search_screen.dart';
import 'screens/category_list_screen.dart';
import 'screens/trending_products_screen.dart';

import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'utils/app_theme.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("Handling a background message: ${message.messageId}");
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  await SettingsService.preloadRemoteSettings();
  await NotificationService.initialize();
  NotificationService.configureNavigationKey(_navigatorKey);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tprov = Provider.of<ThemeProvider>(context);
    final tm = tprov.themeMode;
    final seed = tprov.seedColor;
    final textScale = tprov.textScale;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Parts Mitra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightWithSeed(seed),
      darkTheme: AppTheme.darkWithSeed(seed),
      themeMode: tm,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final base = MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        );
        return Stack(
          children: [
            base,
            if (NotificationService.hasPendingNavigation)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 56,
                        width: 56,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Opening from notification…',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      home: const InitialLoadingWrapper(),
      routes: {
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) {
          final email = ModalRoute.of(context)!.settings.arguments as String;
          return ResetPasswordScreen(email: email);
        },
        '/orders': (context) => const RetailerOrdersScreen(),
        '/settings': (context) => const UserSettingsScreen(),
        '/offers': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
          String? offerType;
          if (args is Map) {
            final dynamic t = args['offerType'];
            if (t is String) offerType = t;
          }
          return OffersScreen(initialOfferType: offerType);
        },
        '/dashboard/retailer': (context) => const RetailerDashboard(),
        '/dashboard/mechanic': (context) => const MechanicDashboard(),
        '/dashboard/wholesaler': (context) => const WholesalerDashboard(),
        '/dashboard/admin': (context) => const AdminDashboard(),
        '/dashboard/staff': (context) => const StaffDashboard(),
        '/admin/ai-training': (context) => const AdminAITrainingReportScreen(),
        '/thank-you': (context) => const ThankYouScreen(),
        '/search': (context) => const MechanicSearchScreen(),
        '/categories': (context) => const CategoryListScreen(),
        '/products/trending': (context) => const TrendingProductsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showingExpiredDialog = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return _buildAuthFlow(context, authProvider);
  }

  Widget _buildAuthFlow(BuildContext context, AuthProvider authProvider) {
    if (authProvider.user == null) {
      // Clear notification connection state on logout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final np = Provider.of<NotificationProvider>(context, listen: false);
        if (np.isConnected) {
          np.disconnect();
        }

        // Check if we just logged out due to session expiration
        if (authProvider.sessionWasExpired && !_showingExpiredDialog) {
          _showingExpiredDialog = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Session Expired'),
              content: const Text(
                  'Your session has expired. Please log in again to continue.'),
              actions: [
                TextButton(
                  onPressed: () {
                    authProvider.clearExpiredFlag();
                    _showingExpiredDialog = false;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      });
      return const AuthHomeScreen();
    }

    if (authProvider.user!.status == 'PENDING') {
      return const PendingApprovalScreen();
    }

    // Initialize notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final np = Provider.of<NotificationProvider>(context, listen: false);
      if (authProvider.user != null && !np.isConnected) {
        final rolesString = authProvider.user!.roles.join(',');
        final userId = authProvider.user!.id;

        // This handles topic subscription, identity storage, WS connection, and fetching
        np.init(rolesString, userId: userId);

        showBatteryOptimizationPromptIfNeeded(context);
        NotificationService.tryConsumePendingNavigation();
      }
    });

    if (authProvider.user!.roles.contains(Constants.roleRetailer)) {
      return const RetailerDashboard();
    } else if (authProvider.user!.roles.contains(Constants.roleMechanic)) {
      return const MechanicDashboard();
    } else if (authProvider.user!.roles.contains(Constants.roleWholesaler)) {
      return const WholesalerDashboard();
    } else if (authProvider.user!.roles.contains(Constants.roleAdmin) ||
        authProvider.user!.roles.contains(Constants.roleSuperManager)) {
      return const AdminDashboard();
    } else if (authProvider.user!.roles.contains(Constants.roleStaff)) {
      return const StaffDashboard();
    } else {
      return const LoginScreen();
    }
  }
}

class InitialLoadingWrapper extends StatefulWidget {
  const InitialLoadingWrapper({super.key});

  @override
  State<InitialLoadingWrapper> createState() => _InitialLoadingWrapperState();
}

class _InitialLoadingWrapperState extends State<InitialLoadingWrapper> {
  late Future<void> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _settingsFuture = SettingsService.preloadRemoteSettings();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // The service handles its own errors and falls back to cache,
          // so we can always proceed.
          return const AuthWrapper();
        } else {
          // Show a loading screen while settings are being fetched.
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png',
                      width: 120, height: 120),
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Connecting to server...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const Text(
                    'This might take a moment.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
