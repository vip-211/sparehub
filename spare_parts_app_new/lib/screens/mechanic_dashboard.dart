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
import '../services/product_service.dart';
import '../widgets/cart_badge.dart';
import '../widgets/notification_badge.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'stock_screen.dart';
import 'mechanic_home_screen.dart';

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
        return const MechanicHomeScreen();
      case 1:
        return const MechanicSearchScreen();
      case 2:
        return const OffersScreen();
      case 3:
        return const RetailerOrdersScreen();
      case 4:
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
            backgroundColor:
                Theme.of(context).colorScheme.surfaceVariant,
          ),
        );
      });
    }

    return Theme(
      data: AppTheme.lightWithSeed(AppTheme.mechanicColor),
      child: PopScope(
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () => AuthService().logout().then((_) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }),
              ),
              const CartBadge(),
              const NotificationBadge(),
              const SizedBox(width: 8),
            ],
          ),
          body: FutureBuilder<List<dynamic>>(
            future: Future.wait([
              SettingsService.isAiChatbotEnabled(),
              ProductService().getCmsSetting('hide_chat_support', 'false'),
            ]),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
                return _buildPage(_selectedIndex);
              }
              final ai = snap.data?[0] ?? true;
              final hideChat = snap.data?[1] == 'true';
              return Stack(
                children: [
                  _buildPage(_selectedIndex),
                  if (ai && !hideChat) const AIChatbotWidget(),
                ],
              );
            },
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
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
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
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
      ),
    );
  }
}
