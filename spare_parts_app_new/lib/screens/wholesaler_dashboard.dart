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
        title: const Text('Wholesaler Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          const CartBadge(),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
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
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag), label: 'Shop'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Sales'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history), label: 'Buy History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
