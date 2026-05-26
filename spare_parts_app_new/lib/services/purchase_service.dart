import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/purchase.dart';
import '../utils/constants.dart';
import './remote_client.dart';

class PurchaseService {
  final RemoteClient _remote = RemoteClient();

  Future<Purchase> createPurchase(Purchase purchase) async {
    final json = await _remote.postJson('/purchases', purchase.toJson());
    return Purchase.fromJson(json);
  }

  Future<Purchase> updatePurchase(int id, Purchase purchase) async {
    final json = await _remote.putJson('/purchases/$id', purchase.toJson());
    return Purchase.fromJson(json);
  }

  Future<String> scanBill(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      String? token;
      if (userStr != null) {
        final user = jsonDecode(userStr);
        token = user['token'];
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${Constants.baseUrl}/purchases/scan-bill'),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', path));

      var response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.bytesToString();
      } else {
        throw 'Failed to scan bill: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Bill scan error: $e');
      rethrow;
    }
  }

  Future<List<Purchase>> getAllPurchases() async {
    final list = await _remote.getList('/purchases');
    return list.map((e) => Purchase.fromJson(e)).toList();
  }

  Future<void> deletePurchase(int id) async {
    await _remote.delete('/purchases/$id');
  }

  Future<void> updateDailyPaid(DateTime date, double amount) async {
    final d = date.toIso8601String().split('T')[0];
    await _remote.putJson('/purchases/daily-paid?date=$d&amount=$amount', {});
  }

  Future<List<Purchase>> getPurchasesByRange(DateTime start, DateTime end) async {
    final s = start.toIso8601String().split('T')[0];
    final e = end.toIso8601String().split('T')[0];
    final list = await _remote.getList('/purchases/by-range?start=$s&end=$e');
    return list.map((e) => Purchase.fromJson(e)).toList();
  }

  Future<List<Purchase>> searchPurchases(String query) async {
    final list = await _remote.getList('/purchases/search?query=$query');
    return list.map((e) => Purchase.fromJson(e)).toList();
  }

  Future<String?> uploadBill(String path, {Uint8List? bytes}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      String? token;
      if (userStr != null) {
        final user = jsonDecode(userStr);
        token = user['token'];
      }

      if (kIsWeb && bytes != null) {
        final res = await _remote.postMultipart(
          '/files/upload',
          fileField: 'file',
          fileName: path.split('/').last,
          bytes: bytes,
        );
        return res['url'];
      } else if (!kIsWeb) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${Constants.baseUrl}/files/upload'),
        );
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.files.add(await http.MultipartFile.fromPath('file', path));

        var response = await request.send();
        if (response.statusCode == 200) {
          var resBody = await response.stream.bytesToString();
          var json = jsonDecode(resBody);
          return json['url'];
        }
      }
    } catch (e) {
      debugPrint('Bill upload error: $e');
    }
    return null;
  }
}
