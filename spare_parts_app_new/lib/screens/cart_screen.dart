import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../services/order_service.dart';
import 'order_confirmation_screen.dart';
import '../services/settings_service.dart';
import '../utils/app_theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isPlacingOrder = false;
  bool _usePoints = false;

  void _placeOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (cart.items.isEmpty) return;

    setState(() => _isPlacingOrder = true);
    final pointsToRedeem = _usePoints ? auth.user?.points ?? 0 : 0;
    final success = await OrderService().createOrder(1, cart.items.values.toList(), pointsToRedeem: pointsToRedeem, deliveryCharge: cart.deliveryCharge);

    setState(() => _isPlacingOrder = false);
    if (success != null && mounted) {
      auth.refreshUser();
      cart.clear();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderConfirmationScreen(order: success)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    return Scaffold(
      backgroundColor: AppTheme.softWhite,
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: cart.items.isEmpty ? _buildEmptyCart() : _buildCartContent(cart),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeInDown(child: Icon(Icons.shopping_cart_outlined, size: 120, color: Colors.grey.shade300)),
          const SizedBox(height: 24),
          FadeInUp(child: const Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.grey))),
          const SizedBox(height: 32),
          FadeInUp(delay: const Duration(milliseconds: 200), child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Start Shopping'))),
        ],
      ),
    );
  }

  Widget _buildCartContent(CartProvider cart) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: cart.items.length,
            itemBuilder: (ctx, i) {
              final item = cart.items.values.toList()[i];
              return FadeInLeft(
                delay: Duration(milliseconds: i * 100),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                  child: Row(
                    children: [
                      Container(height: 80, width: 80, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryBlue)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.charcoalBlack)),
                            const SizedBox(height: 4),
                            Text('₹${item.price}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _quantityButton(Icons.remove, () => cart.decrementItem(item.productId)),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                                _quantityButton(Icons.add, () => cart.addItemFromCart(item.productId)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => cart.removeItem(item.productId)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildSummary(cart),
      ],
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: AppTheme.primaryBlue)),
    );
  }

  Widget _buildSummary(CartProvider cart) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _summaryRow('Subtotal', '₹${cart.subtotalAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              _summaryRow('Delivery Fee', '₹${cart.deliveryCharge.toStringAsFixed(2)}', isFree: cart.deliveryCharge == 0),
              const Divider(height: 32),
              _summaryRow('Total Amount', '₹${(cart.subtotalAmount + cart.deliveryCharge).toStringAsFixed(2)}', isTotal: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _isPlacingOrder ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 8, shadowColor: AppTheme.primaryBlue.withOpacity(0.4)),
                  child: _isPlacingOrder ? const CircularProgressIndicator(color: Colors.white) : const Text('CHECKOUT NOW', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false, bool isFree = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isTotal ? 18 : 14, fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600, color: isTotal ? AppTheme.charcoalBlack : Colors.grey)),
        Text(isFree ? 'FREE' : value, style: TextStyle(fontSize: isTotal ? 20 : 14, fontWeight: FontWeight.w900, color: isFree ? AppTheme.accentGreen : (isTotal ? AppTheme.primaryBlue : AppTheme.charcoalBlack))),
      ],
    );
  }
}
