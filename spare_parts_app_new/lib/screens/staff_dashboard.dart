import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../services/database_service.dart';
import '../models/order.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import '../widgets/notification_badge.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = [
    const StaffOrdersScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          const NotificationBadge(),
          IconButton(
              icon: const Icon(Icons.logout), onPressed: () => auth.logout()),
        ],
      ),
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.delivery_dining), label: 'Deliveries'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blueGrey,
      ),
    );
  }
}

class StaffOrdersScreen extends StatefulWidget {
  const StaffOrdersScreen({super.key});

  @override
  State<StaffOrdersScreen> createState() => _StaffOrdersScreenState();
}

class _StaffOrdersScreenState extends State<StaffOrdersScreen> {
  final OrderService _orderService = OrderService();
  List<Order> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final orders = await _orderService.getMyOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
  }

  void _updateStatus(int orderId, String status) async {
    final updated = await _orderService.updateOrderStatus(orderId, status);
    if (updated != null) {
      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Order marked as $status')));
      }
    }
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the map.')));
      }
    }
  }

  void _viewShopImage(int customerId) async {
    final db = await DatabaseService().database;
    final List<Map<String, dynamic>> maps =
        await db.query('users', where: 'id = ?', whereArgs: [customerId]);
    if (maps.isNotEmpty) {
      final String? path = maps.first['shopImagePath'] as String?;
      if (path != null && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Customer Shop Image',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Image.file(File(path)),
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close')),
              ],
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No shop image uploaded by customer.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final activeOrders = _orders
        .where((o) => o.status == 'APPROVED' || o.status == 'IN_TRANSIT')
        .toList();
    if (activeOrders.isEmpty)
      return const Center(child: Text('No active deliveries.'));

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        itemCount: activeOrders.length,
        itemBuilder: (ctx, i) {
          final order = activeOrders[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExpansionTile(
              title: Text('Order #${order.id} - ${order.status}'),
              subtitle: Text('To: ${order.customerName}'),
              children: [
                ...order.items.map((item) => ListTile(
                      title: Text(item.productName),
                      subtitle: Text('Qty: ${item.quantity}'),
                    )),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (order.latitude != null && order.longitude != null)
                        ElevatedButton.icon(
                          onPressed: () =>
                              _openMap(order.latitude!, order.longitude!),
                          icon: const Icon(Icons.map),
                          label: const Text('Navigate'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white),
                        ),
                      ElevatedButton.icon(
                        onPressed: () => _viewShopImage(order.customerId),
                        icon: const Icon(Icons.storefront),
                        label: const Text('Shop Image'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white),
                      ),
                      if (order.status == 'APPROVED')
                        ElevatedButton(
                          onPressed: () =>
                              _updateStatus(order.id, 'IN_TRANSIT'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          child: const Text('Mark In Transit'),
                        ),
                      if (order.status == 'IN_TRANSIT')
                        ElevatedButton(
                          onPressed: () => _updateStatus(order.id, 'DELIVERED'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white),
                          child: const Text('Mark Delivered'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
