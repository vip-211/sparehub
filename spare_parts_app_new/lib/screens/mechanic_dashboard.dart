import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'mechanic_search_screen.dart';
import 'profile_screen.dart';
import 'offers_screen.dart';
import 'retailer_orders_screen.dart';
import 'notification_screen.dart';
import '../widgets/ai_chatbot_widget.dart';
import '../services/settings_service.dart';
import '../widgets/cart_badge.dart';
import '../widgets/notification_badge.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class MechanicDashboard extends StatefulWidget {
  const MechanicDashboard({super.key});

  @override
  State<MechanicDashboard> createState() => _MechanicDashboardState();
}

class _MechanicDashboardState extends State<MechanicDashboard> {
  int _selectedIndex = 0;
  String? _incomingOfferType;
  bool _bannerShown = false;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const MechanicSearchScreen();
      case 1:
        return const OffersScreen();
      case 2:
        return const RetailerOrdersScreen();
      case 3:
      default:
        return const ProfileScreen();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    if (!_bannerShown && args is Map && (args['offerType'] != null)) {
      _incomingOfferType = args['offerType'] as String?;
      final String? title = args['title'] as String?;
      final String? message = args['message'] as String?;
      final String? imageUrl = args['imageUrl'] as String?;
      _bannerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title ??
                      ((_incomingOfferType?.toUpperCase() == 'WEEKLY')
                          ? 'Weekly offers are live!'
                          : 'Daily offers are live!'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(message),
                  ),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        height: 80,
                        width: double.maxFinite,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
                    ),
                  ),
              ],
            ),
            leading: const Icon(Icons.local_offer),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  Navigator.of(context).pushNamed('/offers',
                      arguments: {'offerType': _incomingOfferType});
                },
                child: const Text('View Offer'),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text('Dismiss'),
              ),
            ],
            backgroundColor: Colors.orange.shade50,
          ),
        );
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Do you want to exit the application?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('No')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Yes')),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Parts Mitra'),
              Text(
                'Mechanic Dashboard',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade700,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.brightness_6_outlined),
              onSelected: (val) {
                final tp = Provider.of<ThemeProvider>(context, listen: false);
                if (val == 'system') tp.setThemeMode(ThemeMode.system);
                if (val == 'light') tp.setThemeMode(ThemeMode.light);
                if (val == 'dark') tp.setThemeMode(ThemeMode.dark);
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(value: 'system', child: Text('System Theme')),
                PopupMenuItem(value: 'light', child: Text('Light Theme')),
                PopupMenuItem(value: 'dark', child: Text('Dark Theme')),
              ],
            ),
            const CartBadge(),
            const NotificationBadge(),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<bool>(
          future: SettingsService.isAiChatbotEnabled(),
          builder: (context, snap) {
            final ai = snap.data ?? true;
            return Stack(
              children: [
                _buildPage(_selectedIndex),
                if (ai) const AIChatbotWidget(),
              ],
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer),
              label: 'Offers',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
