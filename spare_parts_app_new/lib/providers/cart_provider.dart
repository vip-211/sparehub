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

  void addItem(Product product, double price) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => OrderItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + 1,
          price: existing.price,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          price: price,
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
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => OrderItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity - 1,
          price: existing.price,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
