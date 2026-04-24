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

  void addItem(Product product, double price, {int? quantity, bool isLocked = false, int? bannerId, int? offerId}) {
    final effectiveMinQty = product.minOrderQty > 1 ? product.minOrderQty : (product.offerType != null && product.offerType != 'NONE' && (product.offerMinQty ?? 0) > 0 ? (product.offerMinQty ?? 1) : 1);
    final int qtyToAdd = quantity ?? effectiveMinQty;
    if (_items.containsKey(product.id)) {
      if (_items[product.id]!.isLocked) return; // Prevent updating locked items
      _items.update(
        product.id,
        (existing) => OrderItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + qtyToAdd,
          price: existing.price,
          minQty: existing.minQty,
          isLocked: existing.isLocked,
          bannerId: existing.bannerId,
          offerId: existing.offerId,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => OrderItem(
          productId: product.id,
          productName: product.name,
          quantity: qtyToAdd,
          price: price,
          minQty: effectiveMinQty,
          isLocked: isLocked,
          bannerId: bannerId,
          offerId: offerId,
        ),
      );
    }
    notifyListeners();
  }

  void addItemFromCart(int productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.isLocked) return;
    _items.update(
      productId,
      (existing) => OrderItem(
        productId: existing.productId,
        productName: existing.productName,
        quantity: existing.quantity + 1,
        price: existing.price,
        minQty: existing.minQty,
        isLocked: existing.isLocked,
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
    if (_items[productId]!.isLocked) return;
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
          isLocked: existing.isLocked,
        ),
      );
    } else {
      removeItem(productId);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void reorder(List<OrderItem> newItems) {
    for (var item in newItems) {
      if (_items.containsKey(item.productId)) {
        if (!_items[item.productId]!.isLocked) {
          _items.update(
            item.productId,
            (existing) => OrderItem(
              productId: existing.productId,
              productName: existing.productName,
              quantity: existing.quantity + item.quantity,
              price: existing.price,
              minQty: existing.minQty,
              isLocked: existing.isLocked,
              bannerId: existing.bannerId,
              offerId: existing.offerId,
            ),
          );
        }
      } else {
        _items[item.productId] = OrderItem(
          productId: item.productId,
          productName: item.productName,
          quantity: item.quantity,
          price: item.price,
          minQty: item.minQty,
          isLocked: false,
          bannerId: item.bannerId,
          offerId: item.offerId,
        );
      }
    }
    notifyListeners();
  }
}
