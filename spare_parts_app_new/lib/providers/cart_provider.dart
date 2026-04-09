import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/order.dart';

class CartProvider with ChangeNotifier {
  final Map<int, OrderItem> _items = {};

  Map<int, OrderItem> get items => _items;

  int get itemCount => _items.length;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  void addItem(Product product, double price, {int? quantity}) {
    final int qtyToAdd = quantity ?? 1;
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => OrderItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + qtyToAdd,
          price: existing.price,
          minQty: existing.minQty,
        ),
      );
    } else {
      int initialQty = qtyToAdd;
      if (quantity == null) {
        // Only use offer logic if explicit quantity not provided
        initialQty = (product.offerType != null &&
                product.offerType != 'NONE' &&
                (product.offerMinQty ?? 0) > 0)
            ? (product.offerMinQty ?? 1)
            : 1;
      }
      
      _items.putIfAbsent(
        product.id,
        () => OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: initialQty,
          price: price,
          minQty: product.minOrderQty > 1 ? product.minOrderQty : product.offerMinQty,
        ),
      );
    }
    notifyListeners();
  }

  void addItemFromCart(int productId) {
    if (!_items.containsKey(productId)) return;
    _items.update(
      productId,
      (existing) => OrderItem(
        productId: existing.productId,
        productName: existing.productName,
        quantity: existing.quantity + 1,
        price: existing.price,
      ),
    );
    notifyListeners();
  }

  void removeItem(int productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void decrementItem(int productId) {
    if (!_items.containsKey(productId)) return;
    final minQty = _items[productId]!.minQty ?? 1;
    if (_items[productId]!.quantity > minQty) {
      _items.update(
        productId,
        (existing) => OrderItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity - 1,
          price: existing.price,
          minQty: existing.minQty,
        ),
      );
    } else {
      // keep at minimum quantity for offer; do not remove
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
