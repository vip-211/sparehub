import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import '../models/order.dart';
import '../utils/image_utils.dart';
import '../utils/constants.dart';
import 'profile_screen.dart';
import '../widgets/notification_badge.dart';
import '../providers/theme_provider.dart';
import 'staff_mechanic_locations_screen.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _selectedIndex = 0;
  String? _incomingOfferType;
  bool _bannerShown = false;

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const StaffOrdersScreen();
      case 1:
        return const StaffMechanicLocationsScreen();
      case 2:
      default:
        return const ProfileScreen();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
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
          title: const Text('Staff Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
            const NotificationBadge(),
            IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await auth.logout();
                  if (mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  }
                }),
          ],
        ),
        body: _buildPage(_selectedIndex),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.delivery_dining_outlined),
              selectedIcon: Icon(Icons.delivery_dining),
              label: 'Deliveries',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on),
              label: 'Mechanics',
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

class StaffOrdersScreen extends StatefulWidget {
  const StaffOrdersScreen({super.key});

  @override
  State<StaffOrdersScreen> createState() => _StaffOrdersScreenState();
}

class _StaffOrdersScreenState extends State<StaffOrdersScreen> {
  final OrderService _orderService = OrderService();
  StreamSubscription? _orderWsSub;
  List<Order> _orders = [];
  bool _isLoading = true;
  int? _highlightedOrderId;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _orderWsSub = WebSocketService.orderUpdates.stream.listen((data) {
      if (!mounted) return;
      _fetchOrders();
    });

    // Check for highlighted order ID in arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)!.settings.arguments;
      if (args is Map && args.containsKey('orderId')) {
        setState(() {
          _highlightedOrderId = int.tryParse(args['orderId'].toString());
        });
      }
    });
  }

  @override
  void dispose() {
    _orderWsSub?.cancel();
    super.dispose();
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
    String? path;
    try {
      if (Constants.useRemote) {
        final user = await AuthService().getUserById(customerId);
        path = user?.shopImagePath;
      } else {
        final db = await DatabaseService().database;
        final List<Map<String, dynamic>> maps =
            await db.query('users', where: 'id = ?', whereArgs: [customerId]);
        if (maps.isNotEmpty) {
          path = maps.first['shopImagePath'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Error viewing shop image: $e');
    }

    if (path != null && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: Text('Customer Shop Image',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Image(
                  image: getImageProvider(path),
                  fit: BoxFit.contain,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close', style: TextStyle(fontSize: 16))),
              ),
            ],
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No shop image uploaded by customer.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final activeOrders = _orders
        .where((o) =>
            o.status == 'APPROVED' ||
            o.status == 'PACKED' ||
            o.status == 'OUT_FOR_DELIVERY')
        .toList();
    if (activeOrders.isEmpty) {
      return const Center(child: Text('No active deliveries.'));
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        itemCount: activeOrders.length,
        itemBuilder: (ctx, i) {
          final order = activeOrders[i];
          final isHighlighted = _highlightedOrderId == order.id;
          return Card(
            key: ValueKey('staff_order_${order.id}_$isHighlighted'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: isHighlighted ? 4 : 2,
            color: isHighlighted
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3)
                : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              initiallyExpanded: isHighlighted,
              title: Text('Order #${order.id}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isHighlighted
                          ? Theme.of(context).colorScheme.primary
                          : null)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer: ${order.customerName}'),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          _getStatusColor(order.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        color: _getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                const Divider(),
                ...order.items.map((item) => ListTile(
                      title: Text(item.productName),
                      subtitle: Text('Qty: ${item.quantity}'),
                      trailing: Text('₹${item.price * item.quantity}'),
                    )),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (order.latitude != null && order.longitude != null)
                        ElevatedButton.icon(
                          onPressed: () =>
                              _openMap(order.latitude!, order.longitude!),
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('Navigate'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12)),
                        ),
                      ElevatedButton.icon(
                        onPressed: () => _viewShopImage(order.customerId),
                        icon: const Icon(Icons.storefront, size: 18),
                        label: const Text('Shop Image'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12)),
                      ),
                      if (order.status == 'APPROVED')
                        ElevatedButton(
                          onPressed: () => _updateStatus(order.id, 'PACKED'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12)),
                          child: const Text('Mark Packed'),
                        ),
                      if (order.status == 'PACKED')
                        ElevatedButton(
                          onPressed: () =>
                              _updateStatus(order.id, 'OUT_FOR_DELIVERY'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12)),
                          child: const Text('Out for Delivery'),
                        ),
                      if (order.status == 'OUT_FOR_DELIVERY')
                        ElevatedButton(
                          onPressed: () => _updateStatus(order.id, 'DELIVERED'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12)),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return Colors.blue;
      case 'PACKED':
        return Colors.indigo;
      case 'OUT_FOR_DELIVERY':
        return Colors.orange;
      case 'DELIVERED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
