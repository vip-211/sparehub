// ignore_for_file: use_build_context_synchronously
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import '../services/notification_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/ocr_service.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import 'profile_screen.dart';
import 'package:translator/translator.dart';
import 'package:open_file/open_file.dart';
import '../widgets/ai_chatbot_widget.dart';
import 'admin_settings_screen.dart';
import '../services/settings_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _aiEnabled = true;
  bool _voiceEnabled = true;
  final List<Widget> _widgetOptions = [
    const AllOrdersScreen(),
    const OrderRequestsScreen(),
    const ManageProductsScreen(),
    const SalesReportsScreen(),
    const InvoicingScreen(),
    const AllUsersScreen(),
    const VoiceTrainingScreen(),
    const ProfileScreen(),
  ];
  void _sendNotification() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String targetRole = 'ALL';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: targetRole,
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('All Roles')),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await NotificationService().sendNotification(
                titleController.text,
                messageController.text,
                targetRole,
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
    );
  }

  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isSuperManager ? 'Super Manager Panel' : 'Admin Panel',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            isSuperManager ? Colors.deepPurpleAccent : Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: _sendNotification,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ListTile(
                title: Text(
                  'Admin Menu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Orders'),
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('Requests'),
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Products'),
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart),
                title: const Text('Reports'),
                onTap: () {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt),
                title: const Text('Invoicing'),
                onTap: () {
                  setState(() => _selectedIndex = 4);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Users'),
                onTap: () {
                  setState(() => _selectedIndex = 5);
                  Navigator.pop(context);
                },
              ),
              if (_voiceEnabled)
                ListTile(
                  leading: const Icon(Icons.record_voice_over),
                  title: const Text('Voice Training'),
                  onTap: () {
                    setState(() => _selectedIndex = 6);
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () {
                  setState(() => _selectedIndex = 7);
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
                onTap: () {
                  Navigator.pop(context);
                  auth.logout();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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
  final DatabaseService _dbService = DatabaseService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _translator = GoogleTranslator();
  List<Order> _orders = [];
  bool _isLoading = true;
  final TextEditingController _orderSearchController = TextEditingController();
  String _orderQuery = '';
  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final orders = await _orderService.getAllOrders();
    if (mounted) {
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final visible = _orders.where((o) {
      if (_orderQuery.isEmpty) return true;
      final q = _orderQuery.toLowerCase();
      return (o.customerName.toLowerCase().contains(q) ||
          o.sellerName.toLowerCase().contains(q));
    }).toList();
    if (visible.isEmpty) return const Center(child: Text('No orders found.'));
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _orderSearchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter by customer or seller name',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _orderQuery = val.trim()),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (ctx, i) {
                final order = visible[i];
                final deliveredAt = order.deliveredAt != null
                    ? DateFormat(
                        'dd MMM, hh:mm a',
                      ).format(DateTime.parse(order.deliveredAt!))
                    : null;
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    title: Text('Order #${order.id} - ${order.status}'),
                    subtitle: Text(
                      'From: ${order.customerName} to ${order.sellerName}',
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
              },
            ),
          ),
        ],
      ),
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
    _fetchProducts();
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

  Future<void> _fetchProducts({String? query}) async {
    setState(() => _isLoading = true);
    final products = (query != null && query.isNotEmpty)
        ? await _productService.searchProducts(query)
        : await _productService.getAllProducts();
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
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
      _searchController.text = result;
      _fetchProducts(query: result);
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
        setState(() => _isLoading = true);
        Uint8List? bytes = result.files.first.bytes;
        if (bytes == null && result.files.first.path != null) {
          bytes = await File(result.files.first.path!).readAsBytes();
        }

        if (bytes == null) {
          throw Exception('Could not read file data');
        }

        final count = await _productService.importProductsFromExcel(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imported $count products successfully!')),
          );
          _fetchProducts();
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
      if (Platform.isAndroid) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted ${ids.length} products')),
        );
      }
        _selectionMode = false;
        _selectedIds.clear();
      });
      _fetchProducts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(

  void _showAddProductDialog({Product? product}) {
    final nameController = TextEditingController(text: product?.name);
    final partController = TextEditingController(text: product?.partNumber);
    final mrpController = TextEditingController(text: product?.mrp.toString());
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
    String? imagePath = product?.imagePath;
    bool productEnabled = product?.enabled ?? true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Add Product' : 'Edit Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setDialogState(() => imagePath = image.path);
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
                              image: FileImage(File(imagePath!)),
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
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
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
                          setDialogState(() {
                            partController.text = result;
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
                  imagePath: imagePath,
                  enabled: productEnabled,
                );
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
                final success = await _productService.addProduct(newProduct);
                if (success && mounted) {
                  Navigator.pop(ctx);
                  _fetchProducts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    icon: const Icon(Icons.select_all, color: Colors.redAccent),
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
                    icon: const Icon(Icons.check_box, color: Colors.redAccent),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectionMode)
                              Checkbox(
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
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                                image: p.imagePath != null
                                    ? DecorationImage(
                                        image: FileImage(File(p.imagePath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: p.imagePath == null
                                  ? const Icon(Icons.image, color: Colors.grey)
                                  : null,
                            ),
                          ],
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          'Part: ${p.partNumber} | Rack: ${p.rackNumber ?? "-"} | Stock: ${p.stock}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Rs. ${p.sellingPrice}'),
                            Switch(
                              value: p.enabled,
                              onChanged: (val) async {
                                final updated = p.copyWith(enabled: val);
                                await _productService.addProduct(updated);
                                setState(() {
                                  _products[i] = updated;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showAddProductDialog(product: p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(p.id),
                            ),
                          ],
                        ),
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            _selectedIds.add(p.id);
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (ctx) => SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Add Product'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddProductDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.library_add),
                    title: const Text('Bulk Add (JSON)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showBulkAddDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.table_view),
                    title: const Text('Import from Excel'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _importExcel();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Export to Excel'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _exportExcel();
                    },
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add),
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
          child: ListView.builder(
            shrinkWrap: true,
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
                                    image: FileImage(File(p.imagePath!)),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: $_totalAmount',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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

  void _showCreateUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
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
                            ? FileImage(File(user['shopImagePath'] as String))
                            : null,
                        child: user['shopImagePath'] == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(user['name'] ?? 'No Name'),
                      subtitle: Text(
                        '${user['email']}\nRole: ${user['role']} | Status: ${user['status']}${user['latitude'] != null ? "\nLocation: Captured" : ""}',
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
            Image.file(File(path)),
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
