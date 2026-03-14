import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../models/order.dart';
import '../models/user.dart';
import './db_universal.dart';
import './remote_client.dart';
import '../utils/constants.dart';

class OrderService {
  final DatabaseService _dbService = DatabaseService();
  final RemoteClient _remote = RemoteClient();

  // ===============================
  // ADMIN: CREATE ADMIN ORDER
  // ===============================

  Future<Order?> createAdminOrder(
    int customerId,
    String customerName,
    List<OrderItem> items, {
    int? sellerId,
  }) async {
    try {
      if (Constants.useRemote) {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');
        if (userStr == null) return null;
        final currentUser = User.fromJson(jsonDecode(userStr));
        final effectiveSellerId = sellerId ?? currentUser.id;

        final payload = {
          'customerId': customerId,
          'sellerId': effectiveSellerId,
          'items': items
              .map(
                (e) => {
                  'productId': e.productId,
                  'productName': e.productName,
                  'quantity': e.quantity,
                  'price': e.price,
                },
              )
              .toList(),
        };

        final json = await _remote.postJson('/admin/orders', payload);
        return Order.fromJson(json);
      }

      final db = await _dbService.database;
      double totalAmount = 0;
      for (var item in items) {
        totalAmount += item.price * item.quantity;
      }

      int orderId = await db.insert('orders', {
        'customerId': customerId,
        'sellerId': 0, // Admin created
        'totalAmount': totalAmount,
        'status': 'COMPLETED',
        'createdAt': DateTime.now().toIso8601String(),
      });

      for (var item in items) {
        await db.insert('order_items', {
          'orderId': orderId,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
        });
      }

      return await _getOrderById(orderId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Create admin order error: $e');
      }
      return null;
    }
  }

  // ===============================
  // CREATE ORDER REQUEST
  // ===============================

  Future<bool> createOrderRequest(String text, {String? photoPath}) async {
    try {
      if (Constants.useRemote) {
        await _remote.postJson('/orders/custom-request', {
          'text': text,
          'photoPath': photoPath,
        });
        return true;
      }
      final db = await _dbService.database;
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      if (userStr == null) return false;
      final user = jsonDecode(userStr);
      final customerId = user['id'];
      final customerName = user['name'] ?? 'Unknown';

      await db.insert('order_requests', {
        'customerId': customerId,
        'customerName': customerName,
        'text': text,
        'photoPath': photoPath,
        'status': 'NEW',
        'createdAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Create order request error: $e');
      return false;
    }
  }

  // ===============================
  // GET ORDER REQUESTS
  // ===============================

  Future<List<Map<String, dynamic>>> getOrderRequests() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/orders/custom-requests');
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      final db = await _dbService.database;
      return await db.query('order_requests', orderBy: 'id DESC');
    } catch (e) {
      debugPrint('Get order requests error: $e');
      return [];
    }
  }

  // ===============================
  // CREATE ORDER
  // ===============================

  Future<Order?> createOrder(int sellerId, List<OrderItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');

      if (userStr == null) return null;

      final currentUser = User.fromJson(jsonDecode(userStr));

      if (Constants.useRemote) {
        final payload = {
          'sellerId': sellerId,
          'customerId': currentUser.id,
          'items': items
              .map(
                (e) => {
                  'productId': e.productId,
                  'productName': e.productName,
                  'quantity': e.quantity,
                  'price': e.price,
                },
              )
              .toList(),
        };

        final json = await _remote.postJson('/orders', payload);

        return Order.fromJson(json);
      }

      final db = await _dbService.database;

      double totalAmount = 0;

      for (var item in items) {
        totalAmount += item.price * item.quantity;
      }

      int orderId = await db.insert('orders', {
        'customerId': currentUser.id,
        'sellerId': sellerId,
        'totalAmount': totalAmount,
        'status': 'PENDING',
        'createdAt': DateTime.now().toIso8601String(),
      });

      for (var item in items) {
        await db.insert('order_items', {
          'orderId': orderId,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
        });
      }

      return await _getOrderById(orderId);
    } catch (e) {
      debugPrint('Create order error: $e');
      return null;
    }
  }

  // ===============================
  // GET MY ORDERS
  // ===============================

  Future<List<Order>> getMyOrders() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/orders/my-orders');
        return list
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      if (userStr == null) return [];
      final currentUser = User.fromJson(jsonDecode(userStr));

      final db = await _dbService.database;
      final maps = await db.query(
        'orders',
        where: '(customerId = ? OR sellerId = ?) AND deleted = 0',
        whereArgs: [currentUser.id, currentUser.id],
        orderBy: 'id DESC',
      );

      List<Order> orders = [];
      for (var map in maps) {
        final items = await db.query(
          'order_items',
          where: 'orderId = ?',
          whereArgs: [map['id']],
        );
        final orderData = Map<String, dynamic>.from(map);
        orderData['items'] = items;
        orders.add(Order.fromJson(orderData));
      }
      return orders;
    } catch (e) {
      debugPrint('Get my orders error: $e');
      return [];
    }
  }

  Future<List<Order>> getAllOrders() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/admin/orders');
        return list
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final db = await _dbService.database;
      final maps =
          await db.query('orders', where: 'deleted = 0', orderBy: 'id DESC');
      List<Order> orders = [];
      for (var map in maps) {
        final items = await db.query(
          'order_items',
          where: 'orderId = ?',
          whereArgs: [map['id']],
        );
        final orderData = Map<String, dynamic>.from(map);
        orderData['items'] = items;
        orders.add(Order.fromJson(orderData));
      }
      return orders;
    } catch (e) {
      debugPrint('Get all orders error: $e');
      return [];
    }
  }

  // ===============================
  // UPDATE ORDER STATUS
  // ===============================

  Future<Order?> updateOrderStatus(int orderId, String status) async {
    try {
      if (Constants.useRemote) {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');

        if (userStr == null) return null;

        final user = jsonDecode(userStr);

        final response = await http.put(
          Uri.parse(
            '${Constants.baseUrl}/orders/$orderId/status?status=$status',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${user['token']}',
          },
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return Order.fromJson(jsonDecode(response.body));
        }

        return null;
      }

      final db = await _dbService.database;

      await db.update(
        'orders',
        {'status': status},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      return await _getOrderById(orderId);
    } catch (e) {
      debugPrint('Update order status error: $e');
      return null;
    }
  }

  // ===============================
  // CANCEL ORDER
  // ===============================

  Future<Order?> cancelOrder(int orderId) async {
    return updateOrderStatus(orderId, 'CANCELLED');
  }

  // ===============================
  // DELETE ORDER
  // ===============================

  Future<bool> deleteOrder(int orderId) async {
    try {
      if (Constants.useRemote) {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');

        if (userStr == null) return false;

        final user = jsonDecode(userStr);

        final response = await http.delete(
          Uri.parse('${Constants.baseUrl}/admin/orders/$orderId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${user['token']}',
          },
        );

        return response.statusCode >= 200 && response.statusCode < 300;
      }

      final db = await _dbService.database;

      await db.update('orders', {'deleted': 1},
          where: 'id = ?', whereArgs: [orderId]);

      return true;
    } catch (e) {
      debugPrint('Delete order error: $e');
      return false;
    }
  }

  // ===============================
  // ADMIN: UPDATE REQUEST STATUS
  // ===============================

  Future<bool> updateRequestStatus(int requestId, String status) async {
    try {
      if (Constants.useRemote) {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');
        if (userStr == null) return false;
        final user = jsonDecode(userStr);
        final response = await http.put(
          Uri.parse(
            '${Constants.baseUrl}/admin/order-requests/$requestId/status?status=$status',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${user['token']}',
          },
        );
        return response.statusCode >= 200 && response.statusCode < 300;
      }
      final db = await _dbService.database;
      await db.update(
        'order_requests',
        {'status': status},
        where: 'id = ?',
        whereArgs: [requestId],
      );
      return true;
    } catch (e) {
      debugPrint('Update request status error: $e');
      return false;
    }
  }

  // ===============================
  // ADMIN: ASSIGN REQUEST TO STAFF
  // ===============================

  Future<bool> assignRequestToStaff(int requestId, int staffId) async {
    try {
      if (Constants.useRemote) {
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');
        if (userStr == null) return false;
        final user = jsonDecode(userStr);

        final response = await http.put(
          Uri.parse(
            '${Constants.baseUrl}/admin/order-requests/$requestId/assign?staffId=$staffId',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${user['token']}',
          },
        );
        return response.statusCode >= 200 && response.statusCode < 300;
      }

      final db = await _dbService.database;
      await db.update(
        'order_requests',
        {'sellerId': staffId, 'status': 'ASSIGNED'},
        where: 'id = ?',
        whereArgs: [requestId],
      );
      return true;
    } catch (e) {
      debugPrint('Assign request error: $e');
      return false;
    }
  }

  // ===============================
  // ADMIN: GET SALES REPORT
  // ===============================

  Future<Map<String, dynamic>> getSalesReport([String period = 'DAILY']) async {
    try {
      if (Constants.useRemote) {
        dynamic data;
        try {
          data = await _remote.getJson('/admin/sales?type=$period');
        } catch (_) {
          try {
            data = await _remote.getJson('/orders/sales?type=$period');
          } catch (_) {
            try {
              data = await _remote.getJson('/orders/sales?period=$period');
            } catch (_) {
              data = null;
            }
          }
        }
        if (data is Map<String, dynamic>) {
          final totalRevenue =
              (data['totalSales'] ?? data['revenue'] ?? data['totalRevenue']);
          final totalOrders =
              (data['totalOrders'] ?? data['orderCount'] ?? data['orders']);
          return {
            'totalRevenue': (totalRevenue as num?)?.toDouble() ?? 0.0,
            'totalOrders': (totalOrders as num?)?.toInt() ?? 0,
          };
        }
        return {'totalRevenue': 0.0, 'totalOrders': 0};
      }

      final db = await _dbService.database;
      final orders = await db.query('orders', where: "status = 'COMPLETED'");

      double totalRevenue = 0;
      for (var o in orders) {
        totalRevenue += (o['totalAmount'] as num).toDouble();
      }

      return {'totalOrders': orders.length, 'totalRevenue': totalRevenue};
    } catch (e) {
      debugPrint('Get sales report error: $e');
      return {'totalOrders': 0, 'totalRevenue': 0.0};
    }
  }

  // ===============================
  // ADMIN: UPDATE ORDER ITEMS
  // ===============================

  Future<bool> updateOrderItems(int orderId, List<OrderItem> items) async {
    try {
      if (Constants.useRemote) {
        final payload = items
            .map(
              (e) => {
                'productId': e.productId,
                'productName': e.productName,
                'quantity': e.quantity,
                'price': e.price,
              },
            )
            .toList();

        await _remote.putJson('/admin/orders/$orderId/items', payload);
        return true;
      }

      final db = await _dbService.database;
      await db.delete(
        'order_items',
        where: 'orderId = ?',
        whereArgs: [orderId],
      );

      double totalAmount = 0;
      for (var item in items) {
        totalAmount += item.price * item.quantity;
        await db.insert('order_items', {
          'orderId': orderId,
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
        });
      }

      await db.update(
        'orders',
        {'totalAmount': totalAmount},
        where: 'id = ?',
        whereArgs: [orderId],
      );

      return true;
    } catch (e) {
      debugPrint('Update order items error: $e');
      return false;
    }
  }

  Future<List<Order>> getDeletedOrders() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/admin/recycle-bin/orders');
        return list
            .map((e) => Order.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final db = await _dbService.database;
      final maps =
          await db.query('orders', where: 'deleted = 1', orderBy: 'id DESC');
      List<Order> orders = [];
      for (var map in maps) {
        final items = await db.query(
          'order_items',
          where: 'orderId = ?',
          whereArgs: [map['id']],
        );
        final orderData = Map<String, dynamic>.from(map);
        orderData['items'] = items;
        orders.add(Order.fromJson(orderData));
      }
      return orders;
    } catch (e) {
      debugPrint('Get deleted orders error: $e');
      return [];
    }
  }

  Future<bool> restoreOrder(int orderId) async {
    try {
      if (Constants.useRemote) {
        await _remote
            .postJson('/admin/recycle-bin/orders/$orderId/restore', {});
        return true;
      }
      final db = await _dbService.database;
      await db.update('orders', {'deleted': 0},
          where: 'id = ?', whereArgs: [orderId]);
      return true;
    } catch (e) {
      debugPrint('Restore order error: $e');
      return false;
    }
  }

  // ===============================
  // GET ORDER BY ID
  // ===============================

  Future<Order?> _getOrderById(int id) async {
    final db = await _dbService.database;

    final maps = await db.query('orders', where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;

    final items = await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [id],
    );

    final orderData = Map<String, dynamic>.from(maps.first);
    orderData['items'] = items;

    return Order.fromJson(orderData);
  }
}
