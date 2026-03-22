// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../services/billing_service.dart';
import '../utils/constants.dart';
import '../services/websocket_service.dart';

class RetailerOrdersScreen extends StatefulWidget {
  const RetailerOrdersScreen({super.key});

  @override
  State<RetailerOrdersScreen> createState() => _RetailerOrdersScreenState();
}

class _RetailerOrdersScreenState extends State<RetailerOrdersScreen> {
  final OrderService _orderService = OrderService();
  StreamSubscription? _orderSub;

  List<Order> _orders = [];
  bool _isLoading = true;
  int? _highlightedOrderId;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _orderSub = WebSocketService.orderUpdates.stream.listen((event) {
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
    final orders = await _orderService.getMyOrders();
    // Sort orders by ID descending (newest first)
    orders.sort((a, b) => b.id.compareTo(a.id));

    if (!mounted) return;

    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  Future<void> _generateBill(Order order) async {
    await BillingService.generateInvoice(order);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              child: ListView.builder(
                itemCount: _orders.length,
                itemBuilder: (ctx, i) {
                  final order = _orders[i];
                  final isHighlighted = _highlightedOrderId == order.id;

                  return Card(
                    key: ValueKey('order_${order.id}_$isHighlighted'),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: isHighlighted ? 4 : 1,
                    color: isHighlighted ? Colors.blue.shade50 : null,
                    child: ExpansionTile(
                      initiallyExpanded: isHighlighted,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      title: Text(
                        'Order #${order.id}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isHighlighted ? Colors.blue.shade800 : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildStatusBadge(order.status),
                              const SizedBox(width: 8),
                              Text(
                                '₹${order.totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Seller: ${order.sellerName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.green),
                            onPressed: () =>
                                BillingService.shareOnWhatsApp(order),
                            tooltip: 'Share via WhatsApp',
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf,
                                color: Colors.red),
                            onPressed: () => _generateBill(order),
                            tooltip: 'View Invoice',
                          ),
                        ],
                      ),
                      children: [
                        const Divider(height: 1),
                        if (order.pointsRedeemed > 0)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              border:
                                  Border.all(color: const Color(0xFFC8E6C9)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You saved ₹${order.pointsRedeemed} on this order! 🎉',
                                  style: const TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Thanks for ordering with SpareHub — smart choice using your points.',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (order.status == 'DELIVERED' &&
                            (order.pointsEarned) > 0)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              border: Border.all(color: Color(0xFFFFECB3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Loyalty bonus: ${order.pointsEarned} points credited for this order.',
                              style: const TextStyle(
                                color: Color(0xFF8D6E63),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ...order.items.map(
                          (item) => ListTile(
                            dense: true,
                            title: Text(
                              item.productName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              'Qty: ${item.quantity} | Price: ₹${item.price}',
                            ),
                            trailing: Text(
                              '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        /// CANCEL ORDER BUTTON
                        if (auth.user != null &&
                            (auth.user!.roles
                                    .contains(Constants.roleRetailer) ||
                                auth.user!.roles
                                    .contains(Constants.roleMechanic)) &&
                            (order.status == 'PENDING' ||
                                order.status == 'APPROVED'))
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon:
                                    const Icon(Icons.cancel_outlined, size: 18),
                                label: const Text('Cancel Order'),
                                onPressed: () async {
                                  final confirm =
                                      await _showCancelConfirmation();
                                  if (confirm != true) return;

                                  final updated =
                                      await _orderService.cancelOrder(order.id);

                                  if (updated != null) {
                                    await _fetchOrders();

                                    if (!mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Order cancelled successfully'),
                                      ),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'APPROVED':
        color = Colors.blue;
        break;
      case 'DELIVERED':
        color = Colors.green;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<bool?> _showCancelConfirmation() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
