// ignore_for_file: use_build_context_synchronously
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'voice_training_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../services/database_service.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';
import '../services/remote_client.dart';
import '../services/notification_service.dart';
import 'package:spare_parts_app/services/billing_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/ocr_service.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/category.dart' as model;
import '../models/user.dart';
import '../utils/constants.dart';
import '../utils/image_utils.dart';
import 'profile_screen.dart';
import 'package:translator/translator.dart';
import 'package:open_file/open_file.dart';
import '../widgets/product_grid_item.dart';
import '../widgets/ai_chatbot_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'admin_settings_screen.dart';
import 'offers_screen.dart';
import '../services/settings_service.dart';
import '../widgets/cart_badge.dart';
import '../widgets/notification_badge.dart';
import '../providers/theme_provider.dart';
import '../services/websocket_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _aiEnabled = true;
  bool _voiceEnabled = true;
  String? _incomingOfferType;
  bool _bannerShown = false;
  final List<Widget> _widgetOptions = [
    const AdminOverviewScreen(),
    const OffersScreen(),
    const AllOrdersScreen(),
    const OrderRequestsScreen(),
    const ManageProductsScreen(),
    const ManageCategoriesScreen(),
    const SalesReportsScreen(),
    const InvoicingScreen(),
    const AllUsersScreen(),
    const RecycleBinScreen(),
    const VoiceTrainingScreen(),
    const ProfileScreen(),
  ];
  void _sendNotification() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final imageUrlController = TextEditingController();
    String targetRole = 'ALL';
    String offerType = 'DAILY';
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Notification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(labelText: 'Message'),
                  maxLines: 2,
                ),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL (Optional)',
                    hintText: 'https://example.com/image.jpg',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() => isUploading = true);
                            try {
                              final url = await ProductService()
                                  .uploadProductImage(image.path);
                              if (url != null) {
                                setDialogState(() {
                                  imageUrlController.text =
                                      '${Constants.serverUrl}$url';
                                  isUploading = false;
                                });
                              }
                            } catch (e) {
                              setDialogState(() => isUploading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Upload failed: $e')),
                              );
                            }
                          }
                        },
                  icon: isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image),
                  label: Text(isUploading ? 'Uploading...' : 'Upload Image'),
                ),
                if (imageUrlController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrlController.text,
                        height: 100,
                        width: double.maxFinite,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: targetRole,
                  items: [
                    const DropdownMenuItem(
                        value: 'ALL', child: Text('All Roles')),
                    DropdownMenuItem(
                      value: Constants.roleMechanic,
                      child: const Text('Mechanics'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleRetailer,
                      child: const Text('Retailers'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleWholesaler,
                      child: const Text('Wholesalers'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleStaff,
                      child: const Text('Staff'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleSuperManager,
                      child: const Text('Super Managers'),
                    ),
                  ],
                  onChanged: (val) => targetRole = val!,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: offerType,
                  items: const [
                    DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                    DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                  ],
                  onChanged: (val) => offerType = val ?? 'DAILY',
                  decoration:
                      const InputDecoration(labelText: 'Offer Type (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.isEmpty ||
                          messageController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Title and message are required')),
                        );
                        return;
                      }
                      await NotificationService().sendNotification(
                        titleController.text,
                        messageController.text,
                        targetRole,
                        imageUrl: imageUrlController.text.isNotEmpty
                            ? imageUrlController.text
                            : null,
                        offerType: offerType,
                        route: 'offers',
                      );
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notification sent successfully!'),
                          ),
                        );
                      }
                    },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
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
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      });
    }
    // Lazy-load settings the first time build runs if not yet loaded
    SettingsService.isAiChatbotEnabled().then((v) {
      if (mounted && _aiEnabled != v) setState(() => _aiEnabled = v);
    });
    SettingsService.isVoiceTrainingEnabled().then((v) {
      if (mounted && _voiceEnabled != v) setState(() => _voiceEnabled = v);
    });
    final auth = Provider.of<AuthProvider>(context);
    final isSuperManager =
        auth.user?.roles.contains(Constants.roleSuperManager) ?? false;
    final isAdmin = auth.user?.roles.contains(Constants.roleAdmin) ?? false;
    final hasAdminPrivileges = isSuperManager || isAdmin;

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
          title: Text(
            isSuperManager ? 'Super Manager Panel' : 'Admin Panel',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: isSuperManager
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          foregroundColor: isSuperManager
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onError,
          actions: [
            const CartBadge(),
            const NotificationBadge(),
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
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminSettingsScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_active),
              onPressed: _sendNotification,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await auth.logout();
                if (mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(auth.user?.name ?? 'Admin'),
                  accountEmail: Text(auth.user?.email ?? ''),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    child: Icon(Icons.person,
                        color: isSuperManager
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error),
                  ),
                  decoration: BoxDecoration(
                    color: isSuperManager
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Overview'),
                  selected: _selectedIndex == 0,
                  onTap: () {
                    setState(() => _selectedIndex = 0);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.local_offer),
                  title: const Text('Offers'),
                  selected: _selectedIndex == 1,
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: const Text('Orders'),
                  selected: _selectedIndex == 2,
                  onTap: () {
                    setState(() => _selectedIndex = 2);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.assignment),
                  title: const Text('Requests'),
                  selected: _selectedIndex == 3,
                  onTap: () {
                    setState(() => _selectedIndex = 3);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory),
                  title: const Text('Products'),
                  selected: _selectedIndex == 4,
                  onTap: () {
                    setState(() => _selectedIndex = 4);
                    Navigator.pop(context);
                  },
                ),
                if (hasAdminPrivileges)
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: const Text('Categories'),
                    selected: _selectedIndex == 5,
                    onTap: () {
                      setState(() => _selectedIndex = 5);
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('Reports'),
                  selected: _selectedIndex == 6,
                  onTap: () {
                    setState(() => _selectedIndex = 6);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt),
                  title: const Text('Invoicing'),
                  selected: _selectedIndex == 7,
                  onTap: () {
                    setState(() => _selectedIndex = 7);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Users'),
                  selected: _selectedIndex == 8,
                  onTap: () {
                    setState(() => _selectedIndex = 8);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore_from_trash),
                  title: const Text('Recycle Bin'),
                  selected: _selectedIndex == 9,
                  onTap: () {
                    setState(() => _selectedIndex = 9);
                    Navigator.pop(context);
                  },
                ),
                if (_voiceEnabled)
                  ListTile(
                    leading: const Icon(Icons.record_voice_over),
                    title: const Text('Voice Training'),
                    selected: _selectedIndex == 10,
                    onTap: () {
                      setState(() => _selectedIndex = 10);
                      Navigator.pop(context);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  selected: _selectedIndex == 11,
                  onTap: () {
                    setState(() => _selectedIndex = 11);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active),
                  title: const Text('Send Notification'),
                  onTap: () {
                    Navigator.pop(context);
                    _sendNotification();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminSettingsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title:
                      const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    await auth.logout();
                    if (mounted) {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        body: Stack(
          children: [
            _widgetOptions[_selectedIndex],
            if (_aiEnabled) const AIChatbotWidget(),
          ],
        ),
      ),
    );
  }
}

class AdminUserOrdersDetailScreen extends StatelessWidget {
  final int customerId;
  final String customerName;
  final List<Order> orders;
  final User? user;
  final Function(int, String) onUpdateStatus;
  final Function(Order) onEditOrder;
  final Function(int) onDeleteOrder;

  const AdminUserOrdersDetailScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.orders,
    this.user,
    required this.onUpdateStatus,
    required this.onEditOrder,
    required this.onDeleteOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$customerName\'s Orders'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (user != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.05),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user!.shopImagePath != null
                        ? getImageProvider(user!.shopImagePath!)
                        : null,
                    child: user!.shopImagePath == null
                        ? const Icon(Icons.storefront)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user!.name ?? customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user!.address ?? 'No address provided',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ExpansionTile(
                    title: Text('Order #${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Status: ${order.status}',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600)),
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
                          children: [
                            if (order.status == 'PENDING')
                              ElevatedButton(
                                onPressed: () =>
                                    onUpdateStatus(order.id, 'APPROVED'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white),
                                child: const Text('Approve'),
                              ),
                            ElevatedButton.icon(
                              onPressed: () => onEditOrder(order),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => onDeleteOrder(order.id),
                              icon: const Icon(Icons.delete, size: 16),
                              label: const Text('Delete'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final OrderService _orderService = OrderService();
  final ProductService _productService = ProductService();
  final AuthService _authService = AuthService();

  Map<String, dynamic> _stats = {
    'totalOrders': 0,
    'pendingOrders': 0,
    'totalRevenue': 0.0,
    'totalProducts': 0,
    'lowStockProducts': 0,
    'totalUsers': 0,
    'pendingRequests': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    _setupOrderSubscription();
  }

  StreamSubscription? _orderSub;

  void _setupOrderSubscription() {
    // Already handled globally by NotificationService usually,
    // but we can add specific listener here for the Dashboard if needed
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final orders = await _orderService.getAllOrders();
      final products = await _productService.getAllProducts();
      final users = await _authService.getAllUsers();
      final requests = await _orderService.getOrderRequests();

      double revenue = 0;
      int pending = 0;
      for (var o in orders) {
        if (o.status == 'DELIVERED' || o.status == 'APPROVED') {
          revenue += o.totalAmount;
        }
        if (o.status == 'PENDING') pending++;
      }

      int lowStock = products.where((p) => p.stock <= 5).length;
      int pendingReq = requests.where((r) => r['status'] == 'PENDING').length;

      if (mounted) {
        setState(() {
          _stats = {
            'totalOrders': orders.length,
            'pendingOrders': pending,
            'totalRevenue': revenue,
            'totalProducts': products.length,
            'lowStockProducts': lowStock,
            'totalUsers': users.length,
            'pendingRequests': pendingReq,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final isVeryNarrow = constraints.maxWidth < 320;
                final crossAxisCount = isVeryNarrow ? 1 : 2;
                final aspect = crossAxisCount == 2 ? 1.25 : 1.1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: aspect,
                  children: [
                    _buildStatCard(
                      'Total Revenue',
                      '₹${_stats['totalRevenue'].toStringAsFixed(0)}',
                      Icons.payments,
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Total Orders',
                      '${_stats['totalOrders']}',
                      Icons.shopping_bag,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Pending Orders',
                      '${_stats['pendingOrders']}',
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Pending Requests',
                      '${_stats['pendingRequests']}',
                      Icons.assignment_late,
                      Colors.redAccent,
                    ),
                    _buildStatCard(
                      'Total Products',
                      '${_stats['totalProducts']}',
                      Icons.inventory_2,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      'Low Stock',
                      '${_stats['lowStockProducts']}',
                      Icons.warning,
                      Colors.amber,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQuickAction(
              context,
              'Add New Product',
              Icons.add_box,
              Colors.green.shade700,
              () => (context.findAncestorStateOfType<_AdminDashboardState>())
                  ?.setState(() =>
                      (context.findAncestorStateOfType<_AdminDashboardState>())
                          ?._selectedIndex = 4),
            ),
            _buildQuickAction(
              context,
              'Create Invoice',
              Icons.receipt_long,
              Colors.blue.shade700,
              () => (context.findAncestorStateOfType<_AdminDashboardState>())
                  ?.setState(() =>
                      (context.findAncestorStateOfType<_AdminDashboardState>())
                          ?._selectedIndex = 7),
            ),
            _buildQuickAction(
              context,
              'View All Users',
              Icons.people,
              Colors.orange.shade700,
              () => (context.findAncestorStateOfType<_AdminDashboardState>())
                  ?.setState(() =>
                      (context.findAncestorStateOfType<_AdminDashboardState>())
                          ?._selectedIndex = 8),
            ),
            _buildQuickAction(
              context,
              'Assign User Location',
              Icons.my_location,
              Colors.purple.shade700,
              () => _showAssignLocationDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignLocationDialog(BuildContext context) async {
    final authService = AuthService();
    List<User> users = [];
    User? selected;
    final latCtrl = TextEditingController();
    final lonCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    bool loading = true;
    try {
      users = await authService.getAllUsers();
    } catch (_) {}
    loading = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Assign User Location'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<User>(
                  isExpanded: true,
                  value: selected,
                  items: users
                      .map((u) => DropdownMenuItem<User>(
                            value: u,
                            child: Text(u.name ?? u.email),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => selected = val),
                  decoration: const InputDecoration(
                    labelText: 'Select User',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: latCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: lonCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: addrCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final serviceEnabled =
                              await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled) return;
                          var permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.denied) return;
                          }
                          if (permission == LocationPermission.deniedForever) {
                            return;
                          }
                          final pos = await Geolocator.getCurrentPosition(
                              locationSettings: const LocationSettings(
                                  accuracy: LocationAccuracy.high));
                          setState(() {
                            latCtrl.text = pos.latitude.toStringAsFixed(6);
                            lonCtrl.text = pos.longitude.toStringAsFixed(6);
                          });
                        },
                        icon: const Icon(Icons.gps_fixed, size: 18),
                        label: const Text('Use My GPS'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final lat = double.tryParse(latCtrl.text);
                          final lon = double.tryParse(lonCtrl.text);
                          if (lat == null || lon == null) return;
                          try {
                            final uri = Uri.parse(
                                'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon');
                            final res = await http.get(uri,
                                headers: {'User-Agent': 'spares-hub-app'});
                            if (res.statusCode >= 200 && res.statusCode < 300) {
                              final data =
                                  jsonDecode(res.body) as Map<String, dynamic>;
                              final disp =
                                  data['display_name']?.toString() ?? '';
                              setState(() {
                                addrCtrl.text = disp;
                              });
                            }
                          } catch (_) {}
                        },
                        child: const Text('Reverse Geocode'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      final lat = double.tryParse(latCtrl.text);
                      final lon = double.tryParse(lonCtrl.text);
                      if (lat == null || lon == null) return;
                      String msg = 'Location saved';
                      try {
                        await authService.updateUserLocation(
                            selected!.id, lat, lon);
                      } catch (_) {
                        msg = 'Saved locally; server path missing';
                      }
                      if (addrCtrl.text.trim().isNotEmpty) {
                        try {
                          await authService.updateUserAddress(
                              selected!.id, addrCtrl.text.trim());
                        } catch (_) {}
                      }
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String title, IconData icon,
      Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withOpacity(0.3)),
      ),
    );
  }

  Widget _buildHeaderChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 16, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class OrderRequestsScreen extends StatefulWidget {
  const OrderRequestsScreen({super.key});
  @override
  State<OrderRequestsScreen> createState() => _OrderRequestsScreenState();
}

class _OrderRequestsScreenState extends State<OrderRequestsScreen> {
  final OrderService _orderService = OrderService();
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _staff = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final reqs = await _orderService.getOrderRequests();
    // Sort requests by ID descending (newest first)
    reqs.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));

    final staff = await (await _dbService.database).query(
      'users',
      where: 'role = ?',
      whereArgs: [Constants.roleStaff],
    );
    if (mounted) {
      setState(() {
        _requests = reqs;
        _staff = staff;
        _isLoading = false;
      });
    }
  }

  Future<void> _assign(int requestId, int staffId) async {
    await _orderService.assignRequestToStaff(requestId, staffId);
    _fetch();
  }

  Future<void> _updateStatus(int requestId, String status) async {
    await _orderService.updateRequestStatus(requestId, status);
    _fetch();
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          title: Container(
            width: 150,
            height: 12,
            color: Colors.grey[300],
          ),
          subtitle: Container(
            width: 100,
            height: 10,
            color: Colors.grey[300],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        itemCount: _requests.length,
        itemBuilder: (ctx, i) {
          final r = _requests[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(r['text'] as String),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By: ${r['customerName']}'),
                  Text('Status: ${r['status']}'),
                  if (r['assignedStaffName'] != null)
                    Text('Assigned: ${r['assignedStaffName']}'),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'PROCESS') {
                    _updateStatus(r['id'] as int, 'PROCESSING');
                  }
                  if (val == 'COMPLETE') {
                    _updateStatus(r['id'] as int, 'COMPLETED');
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'PROCESS',
                    child: Text('Mark Processing'),
                  ),
                  PopupMenuItem(
                    value: 'COMPLETE',
                    child: Text('Mark Completed'),
                  ),
                ],
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    title: const Text('Assign to Staff'),
                    content: DropdownButtonFormField<int>(
                      items: _staff
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as int,
                              child: Text(s['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (staffId) async {
                        if (staffId != null) {
                          await _assign(r['id'] as int, staffId);
                          if (context.mounted) Navigator.pop(dctx);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});
  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen> {
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _translator = GoogleTranslator();
  List<Order> _orders = [];
  bool _isLoading = true;
  bool _isGridView = false;
  final Map<int, User?> _customerCache = {};
  final TextEditingController _orderSearchController = TextEditingController();
  String _orderQuery = '';
  StreamSubscription? _orderWsSub;
  int? _highlightedOrderId;
  final Set<int> _collapsedCustomerIds = {};

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

  Future<void> _fetchOrders() async {
    final orders = await _orderService.getAllOrders();
    // Sort orders by ID descending (newest first)
    orders.sort((a, b) => b.id.compareTo(a.id));

    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
      _fetchCustomerInfos(orders);
    }
  }

  Future<void> _fetchCustomerInfos(List<Order> orders) async {
    final customerIds = orders.map((o) => o.customerId).toSet();
    for (final id in customerIds) {
      if (!_customerCache.containsKey(id)) {
        final user = await _authService.getUserById(id);
        if (mounted) {
          setState(() {
            _customerCache[id] = user;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _orderWsSub?.cancel();
    super.dispose();
  }

  void _showRequests() async {
    final requests = await _orderService.getOrderRequests();
    final staff = await (await _dbService.database).query(
      'users',
      where: 'role = ?',
      whereArgs: [Constants.roleStaff],
    );
    TextEditingController controller = TextEditingController();
    bool isListening = false;
    XFile? picked;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Order Requests'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'New request text',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isListening ? Icons.mic : Icons.mic_none,
                        color: isListening ? Colors.red : Colors.grey,
                      ),
                      onPressed: () async {
                        if (!isListening) {
                          final ok = await _speech.initialize(
                            onStatus: (_) {},
                            onError: (_) {},
                          );
                          if (ok) {
                            setDialog(() => isListening = true);
                            _speech.listen(
                              onResult: (val) async {
                                String text = val.recognizedWords;
                                try {
                                  final t = await _translator.translate(
                                    text,
                                    to: 'en',
                                  );
                                  text = t.text;
                                } catch (_) {}
                                setDialog(() => controller.text = text);
                              },
                            );
                          }
                        } else {
                          setDialog(() => isListening = false);
                          _speech.stop();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.photo),
                      onPressed: () async {
                        final picker = ImagePicker();
                        picked = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        setDialog(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    await _orderService.createOrderRequest(
                      text,
                      photoPath: picked?.path,
                    );
                    Navigator.pop(ctx);
                    _showRequests();
                  },
                  child: const Text('Submit New'),
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (ctx2, i) {
                      final r = requests[i];
                      return ListTile(
                        title: Text(r['text'] as String),
                        subtitle: Text(
                          'By: ${r['customerName']} • Status: ${r['status']}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'PROCESS') {
                              await _orderService.updateRequestStatus(
                                r['id'] as int,
                                'PROCESSING',
                              );
                            }
                            if (val == 'COMPLETE') {
                              await _orderService.updateRequestStatus(
                                r['id'] as int,
                                'COMPLETED',
                              );
                            }
                            if (!mounted) return;
                            Navigator.pop(ctx);
                            _showRequests();
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(
                              value: 'PROCESS',
                              child: Text('Mark Processing'),
                            ),
                            PopupMenuItem(
                              value: 'COMPLETE',
                              child: Text('Mark Completed'),
                            ),
                          ],
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Assign to Staff'),
                              content: DropdownButtonFormField<int>(
                                items: staff
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s['id'] as int,
                                        child: Text(s['name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (staffId) async {
                                  if (staffId != null) {
                                    await _orderService.assignRequestToStaff(
                                      r['id'] as int,
                                      staffId,
                                    );
                                    Navigator.pop(dctx);
                                    Navigator.pop(ctx);
                                    _showRequests();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateStatus(int orderId, String status) async {
    final updated = await _orderService.updateOrderStatus(orderId, status);
    if (updated != null) {
      _fetchOrders();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Order $status')));
      }
    }
  }

  void _editOrder(Order order) {
    List<OrderItem> editedItems = List.from(order.items);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Edit Order #${order.id}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: editedItems.length,
              itemBuilder: (context, index) {
                final item = editedItems[index];
                return ListTile(
                  title: Text(item.productName),
                  subtitle: Text('Price: ${item.price}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          setStateDialog(() {
                            if (item.quantity > 1) {
                              editedItems[index] = OrderItem(
                                productId: item.productId,
                                productName: item.productName,
                                quantity: item.quantity - 1,
                                price: item.price,
                              );
                            } else {
                              editedItems.removeAt(index);
                            }
                          });
                        },
                      ),
                      Text('${item.quantity}'),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setStateDialog(() {
                            editedItems[index] = OrderItem(
                              productId: item.productId,
                              productName: item.productName,
                              quantity: item.quantity + 1,
                              price: item.price,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await _orderService.updateOrderItems(
                  order.id,
                  editedItems,
                );
                if (success) {
                  Navigator.pop(ctx);
                  _fetchOrders();
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          title: Container(
            width: 150,
            height: 12,
            color: Colors.grey[300],
          ),
          subtitle: Container(
            width: 100,
            height: 10,
            color: Colors.grey[300],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    final visible = _orders.where((o) {
      if (_orderQuery.isEmpty) return true;
      final q = _orderQuery.toLowerCase();
      return (o.customerName.toLowerCase().contains(q) ||
          o.sellerName.toLowerCase().contains(q));
    }).toList();

    // Group orders by customer ID
    final Map<int, List<Order>> grouped = {};
    for (var o in visible) {
      final id = o.customerId;
      if (!grouped.containsKey(id)) grouped[id] = [];
      grouped[id]!.add(o);
    }
    final customerIds = grouped.keys.toList();

    if (visible.isEmpty) return const Center(child: Text('No orders found.'));
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _orderSearchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Filter by customer or seller name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        setState(() => _orderQuery = val.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [!_isGridView, _isGridView],
                  onPressed: (index) {
                    setState(() {
                      _isGridView = index == 1;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  children: const [
                    Icon(Icons.list),
                    Icon(Icons.grid_view),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isGridView ? _buildGridView(grouped) : _buildListView(grouped),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(Map<int, List<Order>> grouped) {
    final ids = grouped.keys.toList();
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: ids.length,
      itemBuilder: (context, index) {
        final id = ids[index];
        final userOrders = grouped[id]!;
        final user = _customerCache[id];
        final customerName = userOrders.first.customerName;

        return Card(
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              // Open user specific orders screen for admin
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminUserOrdersDetailScreen(
                    customerId: id,
                    customerName: customerName,
                    orders: userOrders,
                    user: user,
                    onUpdateStatus: _updateStatus,
                    onEditOrder: _editOrder,
                    onDeleteOrder: (orderId) async {
                      final ok = await _orderService.deleteOrder(orderId);
                      if (mounted && ok) _fetchOrders();
                    },
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      user?.shopImagePath != null &&
                              user!.shopImagePath!.isNotEmpty
                          ? Image(
                              image: getImageProvider(user.shopImagePath!),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.storefront,
                                    size: 40, color: Colors.grey),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.storefront,
                                  size: 40, color: Colors.grey),
                            ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${userOrders.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${userOrders.length} Orders',
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 10, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                user?.address ?? 'No address',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListView(Map<int, List<Order>> grouped) {
    final customerIds = grouped.keys.toList();
    return ListView.builder(
      itemCount: customerIds.length,
      itemBuilder: (ctx, index) {
        final id = customerIds[index];
        final customerOrders = grouped[id]!;
        final customerName = customerOrders.first.customerName;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(
                      '${customerOrders.length} Orders',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.red.shade50,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _collapsedCustomerIds.contains(id)
                        ? 'Expand'
                        : 'Collapse',
                    icon: Icon(
                      _collapsedCustomerIds.contains(id)
                          ? Icons.unfold_more
                          : Icons.unfold_less,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_collapsedCustomerIds.contains(id)) {
                          _collapsedCustomerIds.remove(id);
                        } else {
                          _collapsedCustomerIds.add(id);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_collapsedCustomerIds.contains(id))
              const SizedBox.shrink()
            else
              ...customerOrders.map((order) {
                final isHighlighted = _highlightedOrderId == order.id;
                final deliveredAt = order.deliveredAt != null
                    ? DateFormat('dd MMM, hh:mm a')
                        .format(DateTime.parse(order.deliveredAt!))
                    : null;
                return Card(
                  key: ValueKey('admin_order_${order.id}_$isHighlighted'),
                  elevation: isHighlighted ? 4 : 2,
                  color: isHighlighted ? Colors.blue.shade50 : null,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: isHighlighted,
                    title: Text(
                      'Order #${order.id} - ${order.status}',
                      style: TextStyle(
                        fontWeight: isHighlighted ? FontWeight.bold : null,
                        color: isHighlighted ? Colors.blue.shade800 : null,
                      ),
                    ),
                    subtitle: Text('Date: ${order.createdAt}'),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.share,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary),
                              onPressed: () =>
                                  BillingService.shareOnWhatsApp(order),
                              tooltip: 'Share Summary',
                            ),
                            IconButton(
                              icon: Icon(Icons.picture_as_pdf,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.error),
                              onPressed: () =>
                                  BillingService.generateInvoice(order),
                              tooltip: 'View Invoice',
                            ),
                            IconButton(
                              icon: Icon(Icons.ios_share,
                                  size: 20,
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                              onPressed: () =>
                                  BillingService.shareInvoice(order),
                              tooltip: 'Share Invoice PDF',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Order'),
                                    content: Text(
                                      'Are you sure you want to delete order #${order.id}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          final ok = await _orderService
                                              .deleteOrder(order.id);
                                          if (mounted && ok) _fetchOrders();
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            TextButton.icon(
                              onPressed: _showRequests,
                              icon: const Icon(Icons.assignment),
                              label: const Text('View Requests'),
                            ),
                          ],
                        ),
                      ),
                      ...order.items.map(
                        (item) => ListTile(
                          title: Text(item.productName),
                          subtitle:
                              Text('Qty: ${item.quantity} | ${item.price}'),
                        ),
                      ),
                      if (order.status != 'DELIVERED' &&
                          order.status != 'CANCELLED')
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ElevatedButton.icon(
                            onPressed: () => _editOrder(order),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Edit Items / Bill'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      if (order.status == 'DELIVERED')
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Delivery Info:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                    'Delivered By: ${order.deliveredBy ?? "N/A"}'),
                                Text('Delivered At: $deliveredAt'),
                              ],
                            ),
                          ),
                        ),
                      if (order.status == 'PENDING')
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    _updateStatus(order.id, 'APPROVED'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Approve'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    _updateStatus(order.id, 'CANCELLED'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
          ],
        );
      },
    );
  }
}

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});
  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final ProductService _productService = ProductService();
  final OCRService _ocrService = OCRService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Product> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  bool _isListening = false;
  bool _showExtraIcons = false;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  @override
  void dispose() {
    _ocrService.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _productService.getAllProducts(),
        _productService.getCategories(),
      ]);
      final products = results[0] as List<Product>;
      final categories = results[1] as List<Map<String, dynamic>>;
      products.sort((a, b) => b.id.compareTo(a.id));
      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) async {
            String text = val.recognizedWords;
            // No need to translate if we are listening in English
            setState(() {
              _searchController.text = text;
              if (text.isNotEmpty) {
                _fetchProducts(query: text);
              }
            });
          },
          localeId: 'en_US',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  int _currentPage = 0;
  bool _isLastPage = false;
  final int _pageSize = 15;

  Future<void> _fetchProducts({String? query, bool isLoadMore = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (!isLoadMore) {
        _currentPage = 0;
        _products = [];
        _isLastPage = false;
      }
    });

    try {
      final products = (query != null && query.isNotEmpty)
          ? await _productService.searchProducts(query,
              page: _currentPage, size: _pageSize)
          : await _productService.getAllProducts(
              page: _currentPage, size: _pageSize);

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _products.addAll(products);
          } else {
            _products = products;
          }

          _isLastPage = products.length < _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch products: $e')),
        );
      }
    }
  }

  void _loadMore() {
    if (!_isLastPage && !_isLoading) {
      _currentPage++;
      _fetchProducts(isLoadMore: true);
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (val.isEmpty) {
        _fetchProducts();
      } else {
        _fetchProducts(query: val);
      }
    });
  }

  void _scanQRCode() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Scan QR Code')),
        body: MobileScanner(
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              Navigator.pop(ctx, barcodes.first.rawValue);
            }
          },
        ),
      ),
    );
    if (result != null) {
      final parsed = _productService.parseQRContent(result);
      final pn = parsed['partNumber']!;
      final mrp = parsed['mrp']!;

      _searchController.text = pn;
      _fetchProducts(query: pn);

      if (mrp.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanned Part: $pn | MRP: ₹$mrp')),
        );
      }
    }
  }

  void _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (result != null) {
        final categories = await _productService.getCategories();
        int? selectedCategoryId;

        if (mounted) {
          selectedCategoryId = await showDialog<int>(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Target Category'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Select a category to assign all imported products to:'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Auto-categorize (AI)'),
                        ),
                        ...categories.map((c) => DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['name'] ?? ''),
                            )),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedCategoryId = val),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, -1), // Cancel
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selectedCategoryId),
                    child: const Text('Start Import'),
                  ),
                ],
              ),
            ),
          );
        }

        if (selectedCategoryId == -1) return;

        setState(() => _isLoading = true);
        Uint8List? bytes = result.files.first.bytes;
        if (bytes == null && !kIsWeb && result.files.first.path != null) {
          bytes = await File(result.files.first.path!).readAsBytes();
        }

        if (bytes == null) {
          throw Exception('Could not read file data');
        }

        if (Constants.useRemote) {
          await _productService.uploadExcel(bytes,
              categoryId: selectedCategoryId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Imported successfully!')),
            );
            _fetchProducts();
          }
        } else {
          final count = await _productService.importProductsFromExcel(bytes,
              categoryId: selectedCategoryId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported $count products locally!')),
            );
            _fetchProducts();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _exportExcel() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (status.isDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
          return;
        }
      }

      final bytes = await _productService.exportProductsToExcel();
      String fileName =
          "products_export_${DateTime.now().millisecondsSinceEpoch}.xlsx";

      if (kIsWeb) {
        await FilePicker.platform.saveFile(
          fileName: fileName,
          bytes: bytes,
        );
        return;
      }

      String? path;
      if (kIsWeb) {
        // Web export is already handled by FilePicker.platform.saveFile
        return;
      }
      if (Platform.isAndroid) {
        // In Android 11+ /storage/emulated/0/Download might be restricted
        // but we'll try it first, then fallback to app-specific directory.
        try {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            path = "${downloadDir.path}/$fileName";
          } else {
            final directory = await getExternalStorageDirectory();
            path = "${directory!.path}/$fileName";
          }
          final file = File(path);
          await file.writeAsBytes(bytes);
        } catch (e) {
          final directory = await getExternalStorageDirectory();
          path = "${directory!.path}/$fileName";
          final file = File(path);
          await file.writeAsBytes(bytes);
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        path = '${directory.path}/$fileName';
        final file = File(path);
        await file.writeAsBytes(bytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported successfully to $path'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () {
                if (path != null) {
                  OpenFile.open(path);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _deleteProduct(int id) async {
    final success = await _productService.deleteProduct(id);
    if (success) {
      _fetchProducts();
    }
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text('Delete ${ids.length} selected products?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _productService.deleteProductsBulk(ids);
    if (ok) {
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
      _fetchProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${ids.length} products')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bulk delete failed')),
      );
    }
  }

  void _showOfferDialog(Product product) {
    String selectedOffer = product.offerType ?? 'NONE';
    bool notifyWhatsApp = false;
    bool notifyInApp = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manage Offer: ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedOffer,
                decoration: const InputDecoration(labelText: 'Offer Type'),
                items: const [
                  DropdownMenuItem(value: 'NONE', child: Text('None')),
                  DropdownMenuItem(value: 'DAILY', child: Text('Daily Offer')),
                  DropdownMenuItem(
                      value: 'WEEKLY', child: Text('Weekly Offer')),
                ],
                onChanged: (val) => setDialogState(() => selectedOffer = val!),
              ),
              if (selectedOffer != 'NONE') ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Send WhatsApp Notification'),
                  subtitle:
                      const Text('All users will receive a WhatsApp message'),
                  value: notifyWhatsApp,
                  onChanged: (val) =>
                      setDialogState(() => notifyWhatsApp = val),
                ),
                SwitchListTile(
                  title: const Text('Send In-App Notification'),
                  subtitle: const Text('Notification bar & in-app badge'),
                  value: notifyInApp,
                  onChanged: (val) => setDialogState(() => notifyInApp = val),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await _productService.setProductOffer(
                  product.id,
                  selectedOffer,
                  notifyWhatsApp: notifyWhatsApp,
                  notifyInApp: notifyInApp,
                );
                if (success && mounted) {
                  Navigator.pop(ctx);
                  _fetchProducts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Offer updated for ${product.name}')),
                  );
                }
              },
              child: const Text('Apply Offer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog({Product? product}) {
    final nameController = TextEditingController(text: product?.name);
    final partController = TextEditingController(text: product?.partNumber);
    final mrpController = TextEditingController(text: product?.mrp.toString());
    final discountController = TextEditingController(text: '0');
    final priceController = TextEditingController(
      text: product?.sellingPrice.toString(),
    );
    final rackController =
        TextEditingController(text: product?.rackNumber ?? '');
    final wholesalerPriceController = TextEditingController(
      text: product?.wholesalerPrice.toString(),
    );
    final retailerPriceController = TextEditingController(
      text: product?.retailerPrice.toString(),
    );
    final mechanicPriceController = TextEditingController(
      text: product?.mechanicPrice.toString(),
    );
    final stockController = TextEditingController(
      text: product?.stock.toString(),
    );
    final wholesalerController = TextEditingController(
      text: product?.wholesalerId.toString() ?? '1',
    );
    final imageLinkController = TextEditingController(
      text: (product?.imagePath?.startsWith('http') ?? false)
          ? product!.imagePath
          : '',
    );
    String? imagePath = product?.imagePath;
    Uint8List? pickedImageBytes;
    bool productEnabled = product?.enabled ?? true;
    int? selectedCategoryId = product?.categoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setDialogState(() {
                      imagePath = image.path;
                      pickedImageBytes = bytes;
                    });
                    imageLinkController.clear();
                  }
                },
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    image: imagePath != null
                        ? DecorationImage(
                            image: getImageProvider(imagePath),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imagePath == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Uncategorized'),
                  ),
                  ..._categories.map((c) => DropdownMenuItem<int>(
                        value: c['id'] as int,
                        child: Text(c['name'] ?? ''),
                      )),
                ],
                onChanged: (val) =>
                    setDialogState(() => selectedCategoryId = val),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: imageLinkController,
                decoration: const InputDecoration(
                  labelText: 'Image Link (URL)',
                  hintText: 'https://example.com/image.jpg',
                ),
                onChanged: (val) {
                  setDialogState(() {
                    imagePath = val.isEmpty ? null : val;
                  });
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: partController,
                      decoration: const InputDecoration(
                        labelText: 'Part Number',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.redAccent,
                    ),
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (ctx) => Scaffold(
                          appBar: AppBar(title: const Text('Scan Part QR')),
                          body: MobileScanner(
                            onDetect: (capture) {
                              final barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty) {
                                Navigator.pop(ctx, barcodes.first.rawValue);
                              }
                            },
                          ),
                        ),
                      );
                      if (result != null) {
                        final parsed = _productService.parseQRContent(result);
                        setDialogState(() {
                          partController.text = parsed['partNumber']!;
                          if (parsed['mrp']!.isNotEmpty) {
                            mrpController.text = parsed['mrp']!;
                          }
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.redAccent,
                    ),
                    onPressed: () async {
                      final partNumber =
                          await _ocrService.pickAndExtractPartNumber();
                      if (partNumber != null) {
                        setDialogState(() {
                          partController.text = partNumber;
                        });
                      }
                    },
                  ),
                ],
              ),
              TextField(
                controller: mrpController,
                decoration: const InputDecoration(labelText: 'MRP'),
                keyboardType: TextInputType.number,
                onChanged: (val) {
                  final mrp = double.tryParse(val) ?? 0;
                  final discount =
                      double.tryParse(discountController.text) ?? 0;
                  if (mrp > 0 && discount > 0) {
                    final price = mrp * (1 - discount / 100);
                    setDialogState(() {
                      priceController.text = price.toStringAsFixed(2);
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Apply Global Discount %',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: discountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              suffixText: '%',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              final discount = double.tryParse(val) ?? 0;
                              final mrp =
                                  double.tryParse(mrpController.text) ?? 0;
                              if (mrp > 0) {
                                final price = mrp * (1 - discount / 100);
                                setDialogState(() {
                                  priceController.text =
                                      price.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Entering a percentage will automatically set the default selling price based on the MRP.',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Role Discounts (%)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Wholesaler %',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final d = double.tryParse(val) ?? 0;
                              final mrp =
                                  double.tryParse(mrpController.text) ?? 0;
                              if (mrp > 0 && d >= 0) {
                                final p = mrp * (1 - d / 100);
                                setDialogState(() {
                                  wholesalerPriceController.text =
                                      p.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Retailer %',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final d = double.tryParse(val) ?? 0;
                              final mrp =
                                  double.tryParse(mrpController.text) ?? 0;
                              if (mrp > 0 && d >= 0) {
                                final p = mrp * (1 - d / 100);
                                setDialogState(() {
                                  retailerPriceController.text =
                                      p.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Mechanic %',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final d = double.tryParse(val) ?? 0;
                              final mrp =
                                  double.tryParse(mrpController.text) ?? 0;
                              if (mrp > 0 && d >= 0) {
                                final p = mrp * (1 - d / 100);
                                setDialogState(() {
                                  mechanicPriceController.text =
                                      p.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextField(
                controller: rackController,
                decoration: const InputDecoration(labelText: 'Rack Number'),
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Default Selling Price',
                ),
                keyboardType: TextInputType.number,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Enabled'),
                  Switch(
                    value: productEnabled,
                    onChanged: (v) => setDialogState(() {
                      productEnabled = v;
                    }),
                  ),
                ],
              ),
              const Divider(),
              const Text(
                'Role Specific Prices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: wholesalerPriceController,
                decoration: const InputDecoration(
                  labelText: 'Wholesaler Price',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: retailerPriceController,
                decoration: const InputDecoration(
                  labelText: 'Retailer Price',
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: mechanicPriceController,
                decoration: const InputDecoration(
                  labelText: 'Mechanic Price',
                ),
                keyboardType: TextInputType.number,
              ),
              const Divider(),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: wholesalerController,
                decoration: const InputDecoration(labelText: 'Wholesaler ID'),
                keyboardType: TextInputType.number,
              ),
              Visibility(
                visible: product != null && product.categoryName != null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.category,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Category: ${product?.categoryName ?? ""}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    partController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Name and Part Number are required')),
                  );
                  return;
                }

                final finalImagePath = imageLinkController.text.isNotEmpty
                    ? imageLinkController.text
                    : imagePath;

                final newProduct = Product(
                  id: product?.id ?? 0,
                  name: nameController.text,
                  partNumber: partController.text,
                  rackNumber:
                      rackController.text.isEmpty ? null : rackController.text,
                  mrp: double.tryParse(mrpController.text) ?? 0,
                  sellingPrice: double.tryParse(priceController.text) ?? 0,
                  wholesalerPrice:
                      double.tryParse(wholesalerPriceController.text) ?? 0,
                  retailerPrice:
                      double.tryParse(retailerPriceController.text) ?? 0,
                  mechanicPrice:
                      double.tryParse(mechanicPriceController.text) ?? 0,
                  stock: int.tryParse(stockController.text) ?? 0,
                  wholesalerId: int.tryParse(wholesalerController.text) ?? 1,
                  imagePath: finalImagePath,
                  enabled: productEnabled,
                  categoryId: selectedCategoryId,
                );
                try {
                  if (product == null) {
                    final existing = await _productService
                        .getByPartNumber(newProduct.partNumber.trim());
                    if (existing != null) {
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Product with this part number exists. Opening it.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        _showAddProductDialog(product: existing);
                      }
                      return;
                    }
                  }
                  final savedProduct = await _productService.addProduct(
                    newProduct,
                    imageBytes: pickedImageBytes,
                  );
                  if (savedProduct != null) {
                    if (mounted) {
                      Navigator.pop(ctx);
                      if (product == null &&
                          savedProduct.categoryName != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Added & Auto-categorized as: ${savedProduct.categoryName}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Product saved successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      _fetchProducts();
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to save product. Part number might already exist.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkAddDialog() {
    final jsonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Add Products (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste JSON array of products:'),
            const SizedBox(height: 8),
            TextField(
              controller: jsonController,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText:
                    '[{"name": "Item", "partNumber": "123", "mrp": 100, "sellingPrice": 80, "wholesalerPrice": 70, "retailerPrice": 75, "mechanicPrice": 78, "stock": 10, "wholesalerId": 1}]',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final List<dynamic> data = jsonDecode(jsonController.text);
                final products = data
                    .map(
                      (item) => Product(
                        id: 0,
                        name: item['name'],
                        partNumber: item['partNumber'],
                        mrp: (item['mrp'] as num).toDouble(),
                        sellingPrice: (item['sellingPrice'] as num).toDouble(),
                        wholesalerPrice: (item['wholesalerPrice'] ??
                                item['sellingPrice'] as num)
                            .toDouble(),
                        retailerPrice: (item['retailerPrice'] ??
                                item['sellingPrice'] as num)
                            .toDouble(),
                        mechanicPrice: (item['mechanicPrice'] ??
                                item['sellingPrice'] as num)
                            .toDouble(),
                        stock: item['stock'],
                        wholesalerId: item['wholesalerId'] ?? 1,
                        imagePath: item['imagePath'],
                      ),
                    )
                    .toList();
                final count = await _productService.addProductsBulk(products);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Added $count products')),
                  );
                  _fetchProducts();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid JSON format')),
                );
              }
            },
            child: const Text('Add Bulk'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          title: Container(
            width: 150,
            height: 12,
            color: Colors.grey[300],
          ),
          subtitle: Container(
            width: 100,
            height: 10,
            color: Colors.grey[300],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    if (_isLoading && products.isEmpty) {
      return _buildSkeleton();
    }
    if (products.isEmpty) {
      return const Center(child: Text('No products found'));
    }
    // List view layout for admin page
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLastPage &&
            !_isLoading &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: products.length + (_isLastPage ? 0 : 1),
        itemBuilder: (ctx, i) {
          if (i == products.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final p = products[i];
          final isSelected = _selectedIds.contains(p.id);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              onTap: () => _showAddProductDialog(product: p),
              onLongPress: () {
                setState(() {
                  _selectionMode = true;
                  _selectedIds.add(p.id);
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Checkbox(
                          value: _selectedIds.contains(p.id),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(p.id);
                              } else {
                                _selectedIds.remove(p.id);
                              }
                            });
                          },
                        ),
                      ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        image: DecorationImage(
                          image: getImageProvider(p.imagePath ??
                              p.imageLink ??
                              p.categoryImageLink ??
                              p.categoryImagePath),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) =>
                              debugPrint('Image load error: $exception'),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (p.imagePath == null)
                            Center(
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey[400], size: 32),
                            ),
                          if (p.offerType != null && p.offerType != 'NONE')
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_offer,
                                    size: 12, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Part: ${p.partNumber}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13),
                          ),
                          if (p.offerType != null && p.offerType != 'NONE')
                            Text(
                              'Offer: ${p.offerType}',
                              style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Rack: ${p.rackNumber ?? "-"}',
                                  style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Stock: ${p.stock}',
                                style: TextStyle(
                                  color: p.stock > 0
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rs. ${p.sellingPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.local_offer_outlined,
                            color:
                                (p.offerType != null && p.offerType != 'NONE')
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          onPressed: () => _showOfferDialog(p),
                          tooltip: 'Set Offer',
                        ),
                        Switch(
                          value: p.enabled,
                          activeColor: Colors.redAccent,
                          onChanged: (val) async {
                            final updated = p.copyWith(enabled: val);
                            await _productService.addProduct(updated);
                            setState(() {
                              final idx =
                                  _products.indexWhere((x) => x.id == p.id);
                              if (idx != -1) _products[idx] = updated;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteProduct(p.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length + 1,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.redAccent,
            tabs: [
              const Tab(text: 'All Products'),
              ..._categories.map((c) => Tab(text: c['name'])),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search product or part #',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Chip(
                    label: Text('Total: ${_products.length}'),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  const SizedBox(width: 10),
                  if (_selectionMode) ...[
                    IconButton(
                      tooltip: 'Select All',
                      onPressed: () {
                        setState(() {
                          _selectedIds
                            ..clear()
                            ..addAll(_products.map((e) => e.id));
                        });
                      },
                      icon:
                          const Icon(Icons.select_all, color: Colors.redAccent),
                    ),
                    IconButton(
                      tooltip: 'Delete Selected',
                      onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                    ),
                    IconButton(
                      tooltip: 'Exit Selection',
                      onPressed: () {
                        setState(() {
                          _selectionMode = false;
                          _selectedIds.clear();
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: 'Select Multiple',
                      onPressed: () {
                        setState(() {
                          _selectionMode = true;
                        });
                      },
                      icon:
                          const Icon(Icons.check_box, color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showExtraIcons = !_showExtraIcons),
                    icon: Icon(
                      _showExtraIcons
                          ? Icons.remove_circle_outlined
                          : Icons.add_circle_outlined,
                      color: Colors.redAccent,
                    ),
                  ),
                  if (_showExtraIcons) ...[
                    IconButton(
                      onPressed: _scanQRCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      color: Colors.redAccent,
                    ),
                    IconButton(
                      onPressed: () async {
                        final partNumber =
                            await _ocrService.pickAndExtractPartNumber();
                        if (partNumber != null) {
                          _searchController.text = partNumber;
                          _onSearchChanged(partNumber);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      color: Colors.redAccent,
                    ),
                    IconButton(
                      onPressed: _listen,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildProductList(_products),
                  ..._categories.map((c) {
                    final catProducts = _products
                        .where((p) => p.categoryId == c['id'])
                        .toList();
                    return _buildProductList(catProducts);
                  }),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'export',
              onPressed: _exportExcel,
              backgroundColor: Colors.green,
              child: const Icon(Icons.file_download),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'import',
              onPressed: _importExcel,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.file_upload),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: 'add',
              onPressed: () => _showAddProductDialog(),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

class InvoicingScreen extends StatefulWidget {
  const InvoicingScreen({super.key});
  @override
  State<InvoicingScreen> createState() => _InvoicingScreenState();
}

class _InvoicingScreenState extends State<InvoicingScreen> {
  final ProductService _productService = ProductService();
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final OCRService _ocrService = OCRService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _billingItems = [];
  double _totalAmount = 0;
  bool _isListening = false;
  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  void _listen(
    TextEditingController controller,
    Function(String) onResult,
  ) async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            controller.text = val.recognizedWords;
            if (val.recognizedWords.isNotEmpty) {
              onResult(val.recognizedWords);
            }
          },
          localeId: 'en_US',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _calculateTotal() {
    double total = 0;
    for (var item in _billingItems) {
      double price = (item['price'] as double);
      double discountPercent = (item['discount'] as double? ?? 0);
      int quantity = (item['quantity'] as int);
      double discountedPrice = price * (1 - (discountPercent / 100));
      total += discountedPrice * quantity;
    }
    setState(() => _totalAmount = total);
  }

  void _showUserSearch() async {
    final users = await _authService.getAllUsers();
    final filteredUsers =
        users.where((u) => !u.roles.contains(Constants.roleAdmin)).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Customer'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              return ListTile(
                title: Text(user.name ?? 'No Name'),
                subtitle: Text(user.roles.first),
                onTap: () {
                  setState(() {
                    _selectedUser = {
                      'id': user.id,
                      'name': user.name,
                      'email': user.email,
                      'address': user.address,
                      'role': user.roles.first,
                    };
                    _billingItems = [];
                    _totalAmount = 0;
                  });
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _addProductToBill() async {
    final searchController = TextEditingController();
    List<Product> searchResults = [];
    bool showExtra = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Product to Bill'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search or Scan QR',
                        ),
                        onChanged: (val) async {
                          if (val.length >= 2) {
                            final results =
                                await _productService.searchProducts(val);
                            setDialogState(() => searchResults = results);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setDialogState(() => showExtra = !showExtra),
                      icon: Icon(
                        showExtra
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                        color: Colors.grey,
                      ),
                    ),
                    if (showExtra) ...[
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          final result = await showDialog<String>(
                            context: context,
                            builder: (ctx) => Scaffold(
                              appBar: AppBar(title: const Text('Scan Part QR')),
                              body: MobileScanner(
                                onDetect: (capture) {
                                  final barcodes = capture.barcodes;
                                  if (barcodes.isNotEmpty) {
                                    Navigator.pop(ctx, barcodes.first.rawValue);
                                  }
                                },
                              ),
                            ),
                          );
                          if (result != null) {
                            final product = await _productService
                                .getProductByQRCode(result);
                            if (product != null) {
                              setDialogState(() => searchResults = [product]);
                              searchController.text = result;
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: () async {
                          final partNumber =
                              await _ocrService.pickAndExtractPartNumber();
                          if (partNumber != null) {
                            final product = await _productService
                                .getProductByQRCode(partNumber);
                            if (product != null) {
                              setDialogState(() => searchResults = [product]);
                              searchController.text = partNumber;
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Part $partNumber not found.'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _listen(searchController, (val) async {
                          if (val.length >= 2) {
                            final results =
                                await _productService.searchProducts(val);
                            setDialogState(() => searchResults = results);
                          }
                        }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 200,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final p = searchResults[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                            image: p.imagePath != null
                                ? DecorationImage(
                                    image: getImageProvider(p.imagePath),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: p.imagePath == null
                              ? const Icon(Icons.image, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          p.name,
                          style: TextStyle(
                            color: p.stock <= 0 ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Text('Part: ${p.partNumber}'),
                        trailing: p.stock <= 0
                            ? const Text(
                                'OUT OF STOCK',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              )
                            : Text('Rs. ${p.sellingPrice}'),
                        onTap: p.stock <= 0
                            ? null
                            : () {
                                setState(() {
                                  _billingItems.add({
                                    'id': p.id,
                                    'name': p.name,
                                    'partNumber': p.partNumber,
                                    'price': p.sellingPrice,
                                    'quantity': 1,
                                    'discount': 0.0,
                                  });
                                  _calculateTotal();
                                });
                                Navigator.pop(ctx);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _generatePDF() async {
    if (_selectedUser == null || _billingItems.isEmpty) return;
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SPARE PARTS CO.',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                        pw.Text('123, Auto Market, City'),
                        pw.Text('Phone: +91 99999 88888'),
                        pw.Text('GSTIN: 07AAAAA0000A1Z5'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                        ),
                        pw.Text(
                          'Invoice #: INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Divider(thickness: 2, color: PdfColors.red900),
                pw.SizedBox(height: 15),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BILL TO:',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red900,
                            ),
                          ),
                          pw.Text(
                            '${_selectedUser!['name']}',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          pw.Text(
                            'Address: ${_selectedUser!['address'] ?? "N/A"}',
                          ),
                          pw.Text('Email: ${_selectedUser!['email']}'),
                          pw.Text('Phone: ${_selectedUser!['phone'] ?? "N/A"}'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Table(
                  border: pw.TableBorder(
                    horizontalInside: const pw.BorderSide(
                      color: PdfColors.grey300,
                    ),
                    bottom: const pw.BorderSide(color: PdfColors.black),
                    top: const pw.BorderSide(color: PdfColors.black),
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.red50,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Item Description',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Part #',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'MRP (INR)',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Qty',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Disc %',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ..._billingItems.map((item) {
                      double discountPercent =
                          (item['discount'] as double? ?? 0);
                      double discountedPrice = (item['price'] as double) *
                          (1 - (discountPercent / 100));
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item['name']),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item['partNumber']),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item['price'].toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item['quantity']}',
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${discountPercent.toStringAsFixed(1)}%',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              (discountedPrice * item['quantity'])
                                  .toStringAsFixed(2),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Sub Total: Rs. ${_totalAmount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          'GST (0%): Rs. 0.00',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                        pw.Divider(color: PdfColors.grey),
                        pw.Text(
                          'Grand Total: Rs. ${_totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 50),
                pw.Text(
                  'Terms & Conditions:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.Text(
                  '1. Goods once sold will not be taken back.',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  '2. This is a computer generated invoice.',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    // Send on WhatsApp option
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Share Invoice'),
          content: const Text(
            'Would you like to send this invoice link to the customer on WhatsApp?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send on WhatsApp'),
              onPressed: () async {
                final phone = _selectedUser!['phone'] ?? '';
                if (phone.isNotEmpty) {
                  final message =
                      "Hello ${_selectedUser!['name']}, your invoice for Rs. $_totalAmount has been generated. Thank you for shopping with us!";
                  final url =
                      'https://wa.me/91$phone?text=${Uri.encodeComponent(message)}';
                  if (await canLaunchUrl(Uri.parse(url))) {
                    await launchUrl(Uri.parse(url));
                  }
                }
                if (context.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      );
    }
    // Also create an order in the database so it's reflected to the user
    final orderItems = _billingItems
        .map(
          (item) => OrderItem(
            productId: item['id'],
            productName: item['name'],
            quantity: item['quantity'],
            price: (item['price'] as double) *
                (1 - (item['discount'] as double? ?? 0) / 100),
          ),
        )
        .toList();
    await OrderService().createAdminOrder(
      _selectedUser!['id'] as int,
      _selectedUser!['name'] as String,
      orderItems,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill generated and reflected in user orders.'),
        ),
      );
      setState(() {
        _billingItems = [];
        _selectedUser = null;
        _totalAmount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: Text(
                  _selectedUser == null
                      ? 'Select a Customer'
                      : 'Billing For: ${_selectedUser!['name']}',
                ),
                subtitle: Text(
                  _selectedUser == null
                      ? 'Tap to search'
                      : 'Role: ${_selectedUser!['role']}',
                ),
                trailing: const Icon(Icons.person_search),
                onTap: _showUserSearch,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _billingItems.length,
                itemBuilder: (ctx, i) {
                  final item = _billingItems[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Part: ${item['partNumber']} | Price: ${item['price']}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      if (item['quantity'] > 1) {
                                        item['quantity']--;
                                      } else {
                                        _billingItems.removeAt(i);
                                      }
                                      _calculateTotal();
                                    });
                                  },
                                ),
                                Text(
                                  '${item['quantity']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      item['quantity']++;
                                      _calculateTotal();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Text('Discount: %'),
                                SizedBox(
                                  width: 60,
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        item['discount'] =
                                            double.tryParse(val) ?? 0.0;
                                        _calculateTotal();
                                      });
                                    },
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Net: ${((item['price'] as double) * (1 - ((item['discount'] as double? ?? 0.0) / 100)) * (item['quantity'] as int)).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_billingItems.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTight = constraints.maxWidth < 360;
                    if (isTight) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Total: $_totalAmount',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _generatePDF,
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Generate Bill'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Total: $_totalAmount',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _generatePDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Generate Bill'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _selectedUser != null
          ? FloatingActionButton(
              onPressed: _addProductToBill,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.add_shopping_cart),
            )
          : null,
    );
  }
}

class SalesReportsScreen extends StatefulWidget {
  const SalesReportsScreen({super.key});
  @override
  State<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends State<SalesReportsScreen> {
  final OrderService _orderService = OrderService();
  Map<String, dynamic> _dailyReport = {'totalRevenue': 0.0, 'totalOrders': 0};
  Map<String, dynamic> _weeklyReport = {'totalRevenue': 0.0, 'totalOrders': 0};
  Map<String, dynamic> _monthlyReport = {'totalRevenue': 0.0, 'totalOrders': 0};
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    final daily = await _orderService.getSalesReport('DAILY');
    final weekly = await _orderService.getSalesReport('WEEKLY');
    final monthly = await _orderService.getSalesReport('MONTHLY');
    if (mounted) {
      setState(() {
        _dailyReport = daily;
        _weeklyReport = weekly;
        _monthlyReport = monthly;
        _isLoading = false;
      });
    }
  }

  Widget _buildReportCard(
    String title,
    Map<String, dynamic> report,
    Color color,
  ) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Revenue',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      "Rs. ${report['totalRevenue'].toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Orders',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${report['totalOrders']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
          ),
          title: Container(
            width: 150,
            height: 12,
            color: const Color(0xFFE0E0E0),
          ),
          subtitle: Container(
            width: 100,
            height: 10,
            color: const Color(0xFFE0E0E0),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    return RefreshIndicator(
      onRefresh: _fetchReports,
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Sales Performance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          _buildReportCard('Daily Report', _dailyReport, Colors.blue),
          _buildReportCard('Weekly Report', _weeklyReport, Colors.orange),
          _buildReportCard('Monthly Report', _monthlyReport, Colors.green),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class AllUsersScreen extends StatefulWidget {
  const AllUsersScreen({super.key});

  @override
  State<AllUsersScreen> createState() => _AllUsersScreenState();
}

class _AllUsersScreenState extends State<AllUsersScreen> {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  final RemoteClient _remote = RemoteClient();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final users = await _authService.getAllUsers();
    // Sort users by ID descending (newest first)
    users.sort((a, b) => b.id.compareTo(a.id));

    if (mounted) {
      setState(() {
        _users = users
            .map((u) => {
                  'id': u.id,
                  'email': u.email,
                  'name': u.name,
                  'phone': u.phone,
                  'role': u.roles.isNotEmpty ? u.roles.first : 'N/A',
                  'status': u.status ?? 'PENDING',
                  'address': u.address,
                  'points': u.points,
                })
            .toList();
        _filteredUsers = List.from(_users);
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _filteredUsers = _users
          .where((user) =>
              (user['name']?.toString().toLowerCase() ?? '')
                  .contains(value.toLowerCase()) ||
              (user['email']?.toString().toLowerCase() ?? '')
                  .contains(value.toLowerCase()) ||
              (user['phone']?.toString().toLowerCase() ?? '')
                  .contains(value.toLowerCase()))
          .toList();
    });
  }

  void _updateUserStatus(int userId, String status) async {
    await _authService.updateUserStatus(userId, status);
    _fetchUsers();
  }

  void _updateUserAddress(int userId, String currentAddress) {
    final controller = TextEditingController(text: currentAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update User Address'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Business Address',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.updateUserAddress(userId, controller.text);
              Navigator.pop(ctx);
              _fetchUsers();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showPointsDialog(int userId, int currentPoints) {
    final controller = TextEditingController(text: '0');
    String operation = 'ADD';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Manage Points (Current: $currentPoints)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: operation,
                decoration: const InputDecoration(labelText: 'Operation'),
                items: const [
                  DropdownMenuItem(value: 'ADD', child: Text('Add Points')),
                  DropdownMenuItem(
                      value: 'SUBTRACT', child: Text('Subtract Points')),
                  DropdownMenuItem(value: 'SET', child: Text('Set Points')),
                ],
                onChanged: (val) => setDialogState(() => operation = val!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final points = int.tryParse(controller.text) ?? 0;
                try {
                  await _remote.putJson(
                    '/admin/users/$userId/points?points=$points&operation=$operation',
                    {},
                  );
                  Navigator.pop(ctx);
                  _fetchUsers();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    String selectedRole = Constants.roleMechanic;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New User Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Business Address',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Use Current Location'),
                    onPressed: () async {
                      try {
                        final hasPerm = await Geolocator.checkPermission();
                        if (hasPerm == LocationPermission.denied ||
                            hasPerm == LocationPermission.deniedForever) {
                          final req = await Geolocator.requestPermission();
                          if (req == LocationPermission.denied ||
                              req == LocationPermission.deniedForever) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Location permission denied')),
                            );
                            return;
                          }
                        }
                        final pos = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high);
                        setDialogState(() {
                          latController.text = pos.latitude.toStringAsFixed(6);
                          lngController.text = pos.longitude.toStringAsFixed(6);
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to get location: $e')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    DropdownMenuItem(
                      value: Constants.roleMechanic,
                      child: const Text('Mechanic'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleRetailer,
                      child: const Text('Retailer'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleWholesaler,
                      child: const Text('Wholesaler'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleStaff,
                      child: const Text('Delivery Staff'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleSuperManager,
                      child: const Text('Super Manager'),
                    ),
                    DropdownMenuItem(
                      value: Constants.roleAdmin,
                      child: const Text('Admin'),
                    ),
                  ],
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final success = await _authService.register(
                    nameController.text,
                    emailController.text,
                    passwordController.text,
                    selectedRole,
                    phoneController.text,
                    addressController.text,
                  );
                  if (success) {
                    // If lat/lon provided, update the created user profile
                    try {
                      final all = await _authService.getAllUsers();
                      final created = all.firstWhere(
                          (u) =>
                              u.email.toLowerCase() ==
                              emailController.text.toLowerCase(),
                          orElse: () => throw 'not found');
                      double? lat = double.tryParse(latController.text);
                      double? lng = double.tryParse(lngController.text);
                      if (lat != null || lng != null) {
                        await _authService.adminUpdateUserProfile(
                          created.id,
                          latitude: lat,
                          longitude: lng,
                        );
                      }
                    } catch (_) {}
                    Navigator.pop(ctx);
                    _fetchUsers();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Create Profile'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameController = TextEditingController(text: user['name'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    final addressController =
        TextEditingController(text: user['address'] ?? '');
    final pointsController =
        TextEditingController(text: (user['points'] ?? 0).toString());
    final latController = TextEditingController(
        text: user['latitude'] != null ? '${user['latitude']}' : '');
    final lngController = TextEditingController(
        text: user['longitude'] != null ? '${user['longitude']}' : '');
    String status = user['status'] ?? 'PENDING';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit User Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                TextField(
                  controller: addressController,
                  decoration:
                      const InputDecoration(labelText: 'Business Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
                    DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                    DropdownMenuItem(
                        value: 'SUSPENDED', child: Text('SUSPENDED')),
                  ],
                  onChanged: (val) => setDialogState(() => status = val!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pointsController,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  decoration: const InputDecoration(labelText: 'Points'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Use Current Location'),
                    onPressed: () async {
                      try {
                        var perm = await Geolocator.checkPermission();
                        if (perm == LocationPermission.denied ||
                            perm == LocationPermission.deniedForever) {
                          perm = await Geolocator.requestPermission();
                          if (perm == LocationPermission.denied ||
                              perm == LocationPermission.deniedForever) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Location permission denied')),
                            );
                            return;
                          }
                        }
                        final pos = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high);
                        setDialogState(() {
                          latController.text = pos.latitude.toStringAsFixed(6);
                          lngController.text = pos.longitude.toStringAsFixed(6);
                        });
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to get location: $e')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final int userId = user['id'] as int;
                  final int? points = int.tryParse(pointsController.text);
                  final double? lat = double.tryParse(latController.text);
                  final double? lng = double.tryParse(lngController.text);
                  await _authService.adminUpdateUserProfile(
                    userId,
                    name: nameController.text,
                    email: emailController.text,
                    phone: phoneController.text,
                    address: addressController.text,
                    status: status,
                    points: points,
                    latitude: lat,
                    longitude: lng,
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    _fetchUsers();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleDialog(int userId, String currentRole) {
    // Sanitize role to match Constants if it's in old format
    String sanitizedRole = currentRole;
    if (currentRole == 'mechanic') sanitizedRole = Constants.roleMechanic;
    if (currentRole == 'retailer') sanitizedRole = Constants.roleRetailer;
    if (currentRole == 'wholesaler') sanitizedRole = Constants.roleWholesaler;
    if (currentRole == 'staff') sanitizedRole = Constants.roleStaff;
    if (currentRole == 'supermanager') {
      sanitizedRole = Constants.roleSuperManager;
    }
    if (currentRole == 'admin') sanitizedRole = Constants.roleAdmin;
    // Final safety check: if still not in dropdown, default to mechanic
    final validRoles = [
      Constants.roleMechanic,
      Constants.roleRetailer,
      Constants.roleWholesaler,
      Constants.roleStaff,
      Constants.roleSuperManager,
      Constants.roleAdmin,
    ];
    if (!validRoles.contains(sanitizedRole)) {
      sanitizedRole = Constants.roleMechanic;
    }
    String selectedRole = sanitizedRole;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change User Role'),
        content: DropdownButtonFormField<String>(
          value: selectedRole,
          items: [
            DropdownMenuItem(
              value: Constants.roleMechanic,
              child: const Text('Mechanic'),
            ),
            DropdownMenuItem(
              value: Constants.roleRetailer,
              child: const Text('Retailer'),
            ),
            DropdownMenuItem(
              value: Constants.roleWholesaler,
              child: const Text('Wholesaler'),
            ),
            DropdownMenuItem(
              value: Constants.roleStaff,
              child: const Text('Staff'),
            ),
            DropdownMenuItem(
              value: Constants.roleSuperManager,
              child: const Text('Super Manager'),
            ),
            DropdownMenuItem(
              value: Constants.roleAdmin,
              child: const Text('Admin'),
            ),
          ],
          onChanged: (val) => selectedRole = val!,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.updateUserRole(userId, selectedRole);
              if (mounted) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (auth.user?.id == userId) {
                  await auth.refreshUser();
                }
                Navigator.pop(ctx);
              }
              _fetchUsers();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by name, email or phone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: _filteredUsers.isEmpty
            ? const Center(child: Text('No users found.'))
            : ListView.builder(
                itemCount: _filteredUsers.length,
                itemBuilder: (ctx, i) {
                  final user = _filteredUsers[i];
                  final bool isPending = user['status'] == 'PENDING';
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isPending ? Colors.orange : Colors.blueGrey,
                        backgroundImage: user['shopImagePath'] != null
                            ? getImageProvider(user['shopImagePath'] as String?)
                            : null,
                        child: user['shopImagePath'] == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(user['name'] ?? 'No Name'),
                      subtitle: Text(
                        '${user['email']}\nRole: ${user['role']} | Status: ${user['status']}\nPoints: ${user['points'] ?? 0}${user['latitude'] != null ? "\nLocation: Captured" : ""}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) {
                          final int userId = user['id'] as int;
                          if (user['role'] == Constants.roleSuperManager &&
                              (val == 'ACTIVATE' || val == 'SUSPEND')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Super Manager cannot be modified.'),
                              ),
                            );
                            return;
                          }
                          if (val == 'ACTIVATE') {
                            _updateUserStatus(userId, 'ACTIVE');
                          }
                          if (val == 'SUSPEND') {
                            _updateUserStatus(userId, 'PENDING');
                          }
                          if (val == 'CHANGE_ROLE') {
                            _showRoleDialog(userId, user['role'] as String);
                          }
                          if (val == 'VIEW_LOCATION') {
                            _openMap(
                              user['latitude'] as double,
                              user['longitude'] as double,
                            );
                          }
                          if (val == 'UPDATE_ADDRESS') {
                            _updateUserAddress(
                              userId,
                              user['address'] as String? ?? '',
                            );
                          }
                          if (val == 'MANAGE_POINTS') {
                            _showPointsDialog(
                              userId,
                              (user['points'] as num? ?? 0).toInt(),
                            );
                          }
                          if (val == 'EDIT_PROFILE') {
                            _showEditUserDialog(user);
                          }
                          if (val == 'VIEW_SHOP') {
                            _viewShopImage(user['shopImagePath'] as String?);
                          }
                          if (val == 'DELETE') {
                            _confirmAndDeleteUser(
                                userId, user['role'] as String);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (isPending &&
                              user['role'] != Constants.roleSuperManager)
                            const PopupMenuItem(
                              value: 'ACTIVATE',
                              child: Text('Activate Account'),
                            ),
                          if (!isPending &&
                              user['role'] != Constants.roleSuperManager)
                            const PopupMenuItem(
                              value: 'SUSPEND',
                              child: Text('Suspend Account'),
                            ),
                          const PopupMenuItem(
                            value: 'CHANGE_ROLE',
                            child: Text('Change Role'),
                          ),
                          const PopupMenuItem(
                            value: 'UPDATE_ADDRESS',
                            child: Text('Edit Address'),
                          ),
                          const PopupMenuItem(
                            value: 'EDIT_PROFILE',
                            child: Text('Edit Profile'),
                          ),
                          const PopupMenuItem(
                            value: 'MANAGE_POINTS',
                            child: Text('Manage Points'),
                          ),
                          if (user['shopImagePath'] != null)
                            const PopupMenuItem(
                              value: 'VIEW_SHOP',
                              child: Text('View Shop Image'),
                            ),
                          if (user['latitude'] != null)
                            const PopupMenuItem(
                              value: 'VIEW_LOCATION',
                              child: Text('View Location'),
                            ),
                          if (user['role'] != Constants.roleSuperManager)
                            const PopupMenuItem(
                              value: 'DELETE',
                              child: Text('Delete User'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Future<void> _confirmAndDeleteUser(int userId, String role) async {
    if (role == Constants.roleSuperManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete Super Manager.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text(
            'Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _authService.deleteUser(userId);
    if (ok) {
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete user')),
        );
      }
    }
  }

  void _viewShopImage(String? path) {
    if (path == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(image: getImageProvider(path)),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the map.')),
        );
      }
    }
  }
}

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});
  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final AuthService _authService = AuthService();
  final RemoteClient _remote = RemoteClient();
  final DatabaseService _dbService = DatabaseService();

  List<Product> _deletedProducts = [];
  List<Order> _deletedOrders = [];
  List<Map<String, dynamic>> _deletedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchDeletedItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeletedItems() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productService.getDeletedProducts();
      final orders = await _orderService.getDeletedOrders();
      final users = await _authService.getDeletedUsers();
      if (mounted) {
        setState(() {
          _deletedProducts = products;
          _deletedOrders = orders;
          _deletedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreProduct(int id) async {
    final ok = await _productService.restoreProduct(id);
    if (ok) {
      _fetchDeletedItems();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product restored')),
      );
    }
  }

  Future<void> _permanentDeleteProduct(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanent Delete'),
        content: const Text(
            'Are you sure you want to permanently delete this product? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (Constants.useRemote) {
      try {
        await _remote.delete('/admin/recycle-bin/products/$id/permanent');
        _fetchDeletedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted permanently')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      // Local delete logic
      final db = await _dbService.database;
      await db.delete('products', where: 'id = ?', whereArgs: [id]);
      _fetchDeletedItems();
    }
  }

  Future<void> _restoreOrder(int id) async {
    final ok = await _orderService.restoreOrder(id);
    if (ok) {
      _fetchDeletedItems();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order restored')),
      );
    }
  }

  Future<void> _restoreUser(int id) async {
    final ok = await _authService.restoreUser(id);
    if (ok) {
      _fetchDeletedItems();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User restored')),
      );
    }
  }

  Future<void> _permanentDeleteUser(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanent Delete'),
        content: const Text(
            'Are you sure you want to permanently delete this user? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (Constants.useRemote) {
      try {
        await _remote.delete('/admin/recycle-bin/users/$id/permanent');
        _fetchDeletedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted permanently')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      // Local delete logic
      final db = await _dbService.database;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
      _fetchDeletedItems();
    }
  }

  Future<void> _permanentDeleteOrder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanent Delete'),
        content: const Text(
            'Are you sure you want to permanently delete this order? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (Constants.useRemote) {
      try {
        await _remote.delete('/admin/recycle-bin/orders/$id/permanent');
        _fetchDeletedItems();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order deleted permanently')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      // Local delete logic
      final db = await _dbService.database;
      await db.delete('orders', where: 'id = ?', whereArgs: [id]);
      _fetchDeletedItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.redAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.redAccent,
            tabs: const [
              Tab(icon: Icon(Icons.inventory), text: 'Products'),
              Tab(icon: Icon(Icons.shopping_bag), text: 'Orders'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDeletedProductsList(),
          _buildDeletedOrdersList(),
          _buildDeletedUsersList(),
        ],
      ),
    );
  }

  Widget _buildDeletedProductsList() {
    if (_deletedProducts.isEmpty) {
      return const Center(child: Text('No deleted products found.'));
    }
    return ListView.builder(
      itemCount: _deletedProducts.length,
      itemBuilder: (ctx, i) {
        final p = _deletedProducts[i];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              image: DecorationImage(
                image: getImageProvider(p.imagePath),
                fit: BoxFit.cover,
                onError: (_, __) => debugPrint('Image error'),
              ),
            ),
          ),
          title: Text(p.name),
          subtitle: Text('Part: ${p.partNumber}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _restoreProduct(p.id),
                icon: const Icon(Icons.restore, color: Colors.blue),
                tooltip: 'Restore',
              ),
              IconButton(
                onPressed: () => _permanentDeleteProduct(p.id),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete Permanent',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeletedOrdersList() {
    if (_deletedOrders.isEmpty) {
      return const Center(child: Text('No deleted orders found.'));
    }
    return ListView.builder(
      itemCount: _deletedOrders.length,
      itemBuilder: (ctx, i) {
        final o = _deletedOrders[i];
        return ListTile(
          title: Text('Order #${o.id}'),
          subtitle: Text('Customer: ${o.customerName}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _restoreOrder(o.id),
                icon: const Icon(Icons.restore, color: Colors.blue),
                tooltip: 'Restore',
              ),
              IconButton(
                onPressed: () => _permanentDeleteOrder(o.id),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete Permanent',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeletedUsersList() {
    if (_deletedUsers.isEmpty) {
      return const Center(child: Text('No deleted users found.'));
    }
    return ListView.builder(
      itemCount: _deletedUsers.length,
      itemBuilder: (ctx, i) {
        final u = _deletedUsers[i];
        return ListTile(
          title: Text(u['name'] ?? 'No Name'),
          subtitle: Text(u['email'] ?? ''),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _restoreUser(u['id'] as int),
                icon: const Icon(Icons.restore, color: Colors.blue),
                tooltip: 'Restore',
              ),
              IconButton(
                onPressed: () => _permanentDeleteUser(u['id'] as int),
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Delete Permanent',
              ),
            ],
          ),
        );
      },
    );
  }
}

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final RemoteClient _remote = RemoteClient();
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await _remote.getList('/categories');
      setState(() {
        _categories = res.map((e) => model.Category.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching categories: $e')),
        );
      }
    }
  }

  void _showAddCategoryDialog({model.Category? category}) {
    final nameController =
        TextEditingController(text: category != null ? category.name : '');
    final descriptionController = TextEditingController(
        text: category != null ? category.description : '');
    final imagePathController =
        TextEditingController(text: category != null ? category.imagePath : '');
    final imageLinkController =
        TextEditingController(text: category != null ? category.imageLink : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Category Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: imagePathController,
                decoration: const InputDecoration(labelText: 'Image Path'),
              ),
              TextField(
                controller: imageLinkController,
                decoration:
                    const InputDecoration(labelText: 'Image Link (URL)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                if (category == null) {
                  await _remote.postJson('/categories', {
                    'name': nameController.text,
                    'description': descriptionController.text,
                    'imagePath': imagePathController.text,
                    'imageLink': imageLinkController.text,
                  });
                } else {
                  await _remote.putJson('/categories/${category.id}', {
                    'id': category.id,
                    'name': nameController.text,
                    'description': descriptionController.text,
                    'imagePath': imagePathController.text,
                    'imageLink': imageLinkController.text,
                  });
                }
                Navigator.pop(ctx);
                _fetchCategories();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text(
            'Are you sure? Products in this category will become uncategorized.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _remote.delete('/categories/$id');
      _fetchCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting category: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchCategories,
        child: ListView.builder(
          itemCount: _categories.length,
          itemBuilder: (ctx, i) {
            final cat = _categories[i] as model.Category;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  backgroundImage:
                      cat.imagePath != null && cat.imagePath!.isNotEmpty
                          ? NetworkImage(cat.imagePath!)
                          : null,
                  child: cat.imagePath == null || cat.imagePath!.isEmpty
                      ? const Icon(Icons.category, color: Colors.white)
                      : null,
                ),
                title: Text(
                  cat.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    cat.description != null ? Text(cat.description!) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showAddCategoryDialog(category: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteCategory(cat.id),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
