// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import '../services/billing_service.dart';
import '../utils/constants.dart';

class RetailerOrdersScreen extends StatefulWidget {
  const RetailerOrdersScreen({super.key});

  @override
  State<RetailerOrdersScreen> createState() => _RetailerOrdersScreenState();
}

class _RetailerOrdersScreenState extends State<RetailerOrdersScreen> {
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
    // Sort orders by ID descending (newest first)
    orders.sort((a, b) => b.id.compareTo(a.id));

    if (!mounted) return;

    setState(() {
      _orders = orders;
      _isLoading = false;
    });
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
        leading: const BackButton(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              child: ListView.builder(
                itemCount: _orders.length,
                itemBuilder: (ctx, i) {
                  final order = _orders[i];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ExpansionTile(
                      title: Text(
                        'Order #${order.id} | Total: ₹${order.totalAmount.toStringAsFixed(2)}',
                      ),
                      subtitle: Text(
                        'Status: ${order.status} | Seller: ${order.sellerName}',
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
                        ...order.items.map(
                          (item) => ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              'Qty: ${item.quantity} | Price: ₹${item.price}',
                            ),
                            trailing: Text(
                              '₹${(item.price * item.quantity).toStringAsFixed(2)}',
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () async {
                                    final updated = await _orderService
                                        .cancelOrder(order.id);

                                    if (updated != null) {
                                      await _fetchOrders();

                                      if (!mounted) return;

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Order cancelled'),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Cancel Order'),
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
    );
  }
}
