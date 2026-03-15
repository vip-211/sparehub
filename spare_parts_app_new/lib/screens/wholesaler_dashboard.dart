import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'wholesaler_shop_screen.dart';
import 'retailer_orders_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import '../widgets/ai_chatbot_widget.dart';
import '../services/settings_service.dart';
import '../widgets/cart_badge.dart';
import '../widgets/notification_badge.dart';

class WholesalerDashboard extends StatefulWidget {
  const WholesalerDashboard({super.key});

  @override
  State<WholesalerDashboard> createState() => _WholesalerDashboardState();
}

class _WholesalerDashboardState extends State<WholesalerDashboard> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    WholesalerShopScreen(),
    Center(child: Text('Sales Reports', style: TextStyle(fontSize: 24))),
    RetailerOrdersScreen(), // Buying history
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Spares Hub'),
            Text(
              'Wholesaler Dashboard',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.purple.shade700,
        actions: [
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
              _widgetOptions.elementAt(_selectedIndex),
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
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
