import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/user.dart';
import './db_universal.dart';
import '../utils/constants.dart';
import './remote_client.dart';
import 'package:sqflite/sqflite.dart';
import '../services/settings_service.dart';

import 'package:spare_parts_app/services/voice_correction_service.dart';

class ProductService {
  final DatabaseService _dbService = DatabaseService();
  final RemoteClient _remote = RemoteClient();

  Future<String?> uploadProductImage(String path, {Uint8List? bytes}) async {
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
      debugPrint('Image upload error: $e');
    }
    return null;
  }

  Future<void> uploadExcel(Uint8List bytes, {int? categoryId}) async {
    final uri = Uri.parse('${Constants.baseUrl}/excel/upload').replace(
      queryParameters:
          categoryId != null ? {'categoryId': categoryId.toString()} : null,
    );
    var request = http.MultipartRequest('POST', uri);
    request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'products.xlsx'));
    final res = await request.send();
    if (res.statusCode != 200) {
      throw Exception('Upload failed');
    }
  }

  Future<int> importProductsFromExcel(Uint8List bytes,
      {int? categoryId}) async {
    var excel = Excel.decodeBytes(bytes);
    int count = 0;
    List<Product> productsToInsert = [];
    final existingPartNumbers = <String>{};
    // Preload existing part numbers for local mode
    if (!Constants.useRemote) {
      final db = await _dbService.database;
      final rows = await db.query('products', columns: ['partNumber']);
      for (final r in rows) {
        final pn = (r['partNumber'] as String?)?.trim();
        if (pn != null && pn.isNotEmpty) existingPartNumbers.add(pn);
      }
    }
    final seenInFile = <String>{};

    for (var table in excel.tables.keys) {
      var rows = excel.tables[table]!.rows;
      if (rows.length <= 1) continue; // Skip header

      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.isEmpty) continue;

        try {
          String getVal(int index) {
            if (index >= row.length || row[index] == null) return '';
            final val = row[index]?.value;
            if (val == null) return '';
            return val.toString();
          }

          String name = getVal(0);
          if (name.isEmpty) continue;

          final partNumber = getVal(1).trim();
          if (partNumber.isEmpty) continue;
          if (seenInFile.contains(partNumber)) continue;
          if (existingPartNumbers.contains(partNumber)) continue;
          seenInFile.add(partNumber);

          String rackNumber = getVal(2);
          double mrp = double.tryParse(getVal(3)) ?? 0;
          double sellingPrice = double.tryParse(getVal(4)) ?? 0;
          double wholesalerPrice = 0;
          double retailerPrice = 0;
          double mechanicPrice = 0;
          int stock = 0;

          if (row.length >= 9) {
            wholesalerPrice = double.tryParse(getVal(5)) ?? 0;
            retailerPrice = double.tryParse(getVal(6)) ?? 0;
            mechanicPrice = double.tryParse(getVal(7)) ?? 0;
            stock = int.tryParse(getVal(8)) ?? 0;
          } else if (row.length >= 6) {
            stock = int.tryParse(getVal(5)) ?? 0;
          }

          productsToInsert.add(
            Product(
              id: 0,
              name: name,
              partNumber: partNumber,
              rackNumber: rackNumber.isEmpty ? null : rackNumber,
              mrp: mrp,
              sellingPrice: sellingPrice,
              wholesalerPrice: wholesalerPrice,
              retailerPrice: retailerPrice,
              mechanicPrice: mechanicPrice,
              stock: stock,
              wholesalerId: 1,
              categoryId: categoryId,
            ),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Row $i error: $e');
          }
        }
      }
    }

    if (productsToInsert.isNotEmpty) {
      count = await addProductsBulk(productsToInsert);
    }
    return count;
  }

  Future<Uint8List> exportProductsToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Products'];
    excel.delete('Sheet1');

    // Header
    sheetObject.appendRow([
      TextCellValue('Name'),
      TextCellValue('Part Number'),
      TextCellValue('Rack Number'),
      TextCellValue('MRP'),
      TextCellValue('Selling Price'),
      TextCellValue('Wholesaler Price'),
      TextCellValue('Retailer Price'),
      TextCellValue('Mechanic Price'),
      TextCellValue('Stock'),
    ]);

    final products = await getAllProducts();
    for (var p in products) {
      sheetObject.appendRow([
        TextCellValue(p.name),
        TextCellValue(p.partNumber),
        TextCellValue(p.rackNumber ?? ''),
        DoubleCellValue(p.mrp),
        DoubleCellValue(p.sellingPrice),
        DoubleCellValue(p.wholesalerPrice),
        DoubleCellValue(p.retailerPrice),
        DoubleCellValue(p.mechanicPrice),
        IntCellValue(p.stock),
      ]);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  Map<String, String> parseQRContent(String raw) {
    // Typical Honda/Spare Part QR format: "PARTNUMBER,MRP,..."
    // or just the part number.
    // We try to extract Part Number and MRP.
    final Map<String, String> result = {'partNumber': raw, 'mrp': ''};

    // 1. Try splitting by comma
    final parts = raw.split(',');
    if (parts.length >= 2) {
      // Check if the first part looks like a part number (alphanumeric, at least 5 chars)
      final pn = parts[0].trim().toUpperCase();
      if (RegExp(r'^[A-Z0-9\-_]{5,}$').hasMatch(pn)) {
        result['partNumber'] = pn;
        // Check if the second part looks like a price
        final price = parts[1].trim();
        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(price)) {
          result['mrp'] = price;
        }
      }
    } else {
      // 2. Try splitting by other delimiters like pipe or tab
      final partsOther = raw.split(RegExp(r'[|\t]'));
      if (partsOther.length >= 2) {
        final pn = partsOther[0].trim().toUpperCase();
        if (RegExp(r'^[A-Z0-9\-_]{5,}$').hasMatch(pn)) {
          result['partNumber'] = pn;
          final price = partsOther[1].trim();
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(price)) {
            result['mrp'] = price;
          }
        }
      }
    }

    // Clean up result partNumber (some QR codes might have extra info)
    // If partNumber is a URL, extract the last path segment or query param
    if (result['partNumber']!.startsWith('http')) {
      try {
        final uri = Uri.parse(result['partNumber']!);
        if (uri.pathSegments.isNotEmpty) {
          result['partNumber'] = uri.pathSegments.last.toUpperCase();
        } else if (uri.queryParameters.containsKey('pn')) {
          result['partNumber'] = uri.queryParameters['pn']!.toUpperCase();
        }
      } catch (_) {}
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/categories');
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      final db = await _dbService.database;
      return await db.query('categories', where: 'deleted = 0');
    } catch (e) {
      debugPrint('Get categories error: $e');
      return [];
    }
  }

  Future<List<Product>> getProductsByCategory(int categoryId) async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/products?categoryId=$categoryId');
        final products = list
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();

        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');
        if (userStr == null) return products;

        final user = User.fromJson(jsonDecode(userStr));
        if (user.roles.contains(Constants.roleAdmin) ||
            user.roles.contains(Constants.roleSuperManager) ||
            user.roles.contains(Constants.roleStaff)) {
          return products;
        }

        final enabledOnly = products.where((p) => p.enabled).toList();
        if (user.roles.contains(Constants.roleWholesaler)) {
          return enabledOnly
              .where((p) => p.wholesalerPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        if (user.roles.contains(Constants.roleRetailer)) {
          return enabledOnly
              .where((p) => p.retailerPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        if (user.roles.contains(Constants.roleMechanic)) {
          return enabledOnly
              .where((p) => p.mechanicPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        return enabledOnly.where((p) => p.sellingPrice > 0).toList();
      }

      final db = await _dbService.database;
      final maps = await db.query('products',
          where: 'categoryId = ? AND deleted = 0', whereArgs: [categoryId]);
      return maps.map((p) => Product.fromJson(p)).toList();
    } catch (e) {
      debugPrint('Get products by category error: $e');
      return [];
    }
  }

  Future<List<Product>> getAllProducts() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/products');
        final products = list
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');
        if (userStr == null) return products;
        final user = User.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
        if (user.roles.contains(Constants.roleAdmin) ||
            user.roles.contains(Constants.roleSuperManager) ||
            user.roles.contains(Constants.roleStaff)) {
          return products;
        }
        final enabledOnly = products.where((p) => p.enabled).toList();
        if (user.roles.contains(Constants.roleWholesaler)) {
          return enabledOnly
              .where((p) => p.wholesalerPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        if (user.roles.contains(Constants.roleRetailer)) {
          return enabledOnly
              .where((p) => p.retailerPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        if (user.roles.contains(Constants.roleMechanic)) {
          return enabledOnly
              .where((p) => p.mechanicPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        return enabledOnly.where((p) => p.sellingPrice > 0).toList();
      }
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps =
          await db.query('products', where: 'deleted = 0');
      final products = maps.map((p) => Product.fromJson(p)).toList();
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      if (userStr == null) {
        return products.where((p) => p.enabled && p.sellingPrice > 0).toList();
      }
      final user = User.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
      if (user.roles.contains(Constants.roleAdmin) ||
          user.roles.contains(Constants.roleStaff)) {
        return products;
      }
      final enabledOnly = products.where((p) => p.enabled).toList();
      if (user.roles.contains(Constants.roleWholesaler)) {
        return enabledOnly
            .where((p) => p.wholesalerPrice > 0 || p.sellingPrice > 0)
            .toList();
      }
      if (user.roles.contains(Constants.roleRetailer)) {
        return enabledOnly
            .where((p) => p.retailerPrice > 0 || p.sellingPrice > 0)
            .toList();
      }
      if (user.roles.contains(Constants.roleMechanic)) {
        return enabledOnly
            .where((p) => p.mechanicPrice > 0 || p.sellingPrice > 0)
            .toList();
      }
      return enabledOnly.where((p) => p.sellingPrice > 0).toList();
    } catch (e) {
      debugPrint('Local get products error: $e');
      return [];
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    if (query.isEmpty) return [];
    try {
      String correctedQuery = query;
      if (!Constants.useRemote) {
        final voiceEnabled = await SettingsService.isVoiceTrainingEnabled();
        if (voiceEnabled) {
          final voiceCorrectionService = VoiceCorrectionService();
          correctedQuery =
              await voiceCorrectionService.getCorrection(query) ?? query;
        }
      }
      if (Constants.useRemote) {
        final list = await _remote.getList(
          '/products/search?query=${Uri.encodeComponent(correctedQuery)}',
        );
        final products = list
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('user');
        if (userStr == null) {
          return products;
        }
        final user = User.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
        if (user.roles.contains(Constants.roleAdmin) ||
            user.roles.contains(Constants.roleSuperManager) ||
            user.roles.contains(Constants.roleStaff)) {
          return products;
        }
        if (user.roles.contains(Constants.roleWholesaler)) {
          return products
              .where((p) => p.wholesalerPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        if (user.roles.contains(Constants.roleRetailer)) {
          return products
              .where((p) => p.retailerPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        if (user.roles.contains(Constants.roleMechanic)) {
          return products
              .where((p) => p.mechanicPrice > 0 || p.sellingPrice > 0)
              .toList();
        }
        return products.where((p) => p.sellingPrice > 0).toList();
      }

      final db = await _dbService.database;
      final List<Map<String, dynamic>> direct = await db.query(
        'products',
        where:
            '(name LIKE ? OR partNumber LIKE ? OR partNumber = ? OR rackNumber LIKE ?)',
        whereArgs: [
          '%$correctedQuery%',
          '%$correctedQuery%',
          correctedQuery,
          '%$correctedQuery%'
        ],
      );
      final List<Map<String, dynamic>> aliasMatches = await db.rawQuery(
        'SELECT p.* FROM products p INNER JOIN product_aliases a ON a.productId = p.id WHERE a.alias LIKE ?',
        ['%$correctedQuery%'],
      );
      final all = [...direct, ...aliasMatches];
      final seen = <int>{};
      final unique = <Map<String, dynamic>>[];
      for (final m in all) {
        final id = m['id'] as int;
        if (!seen.contains(id)) {
          seen.add(id);
          unique.add(m);
        }
      }
      final products = unique.map((p) => Product.fromJson(p)).toList();
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('user');
      if (userStr == null) {
        return products.where((p) => p.sellingPrice > 0).toList();
      }
      final user = User.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
      if (user.roles.contains(Constants.roleAdmin) ||
          user.roles.contains(Constants.roleStaff)) {
        return products;
      }
      final enabledOnly = products.where((p) => p.enabled).toList();
      if (user.roles.contains(Constants.roleWholesaler)) {
        return enabledOnly.where((p) => p.wholesalerPrice > 0).toList();
      }
      if (user.roles.contains(Constants.roleRetailer)) {
        return enabledOnly.where((p) => p.retailerPrice > 0).toList();
      }
      if (user.roles.contains(Constants.roleMechanic)) {
        return enabledOnly.where((p) => p.mechanicPrice > 0).toList();
      }
      return enabledOnly.where((p) => p.sellingPrice > 0).toList();
    } catch (e) {
      debugPrint('Local search products error: $e');
      return [];
    }
  }

  Future<Product?> getProductByQRCode(String qrCode) async {
    try {
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'partNumber = ?',
        whereArgs: [qrCode],
      );
      if (maps.isNotEmpty) {
        return Product.fromJson(maps.first);
      }
    } catch (e) {
      debugPrint('Local QR search error: $e');
    }
    return null;
  }

  Future<double> getPriceForUser(Product product) async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr == null) return product.sellingPrice;

    final user = User.fromJson(jsonDecode(userStr) as Map<String, dynamic>);
    if (user.roles.contains(Constants.roleWholesaler)) {
      return product.wholesalerPrice;
    }
    if (user.roles.contains(Constants.roleRetailer)) {
      return product.retailerPrice;
    }
    if (user.roles.contains(Constants.roleMechanic)) {
      return product.mechanicPrice;
    }

    return product.sellingPrice;
  }

  Future<Product?> getByPartNumber(String partNumber) async {
    try {
      if (partNumber.trim().isEmpty) return null;
      if (Constants.useRemote) {
        // Backend lookup endpoint not guaranteed; skip remote check here.
        return null;
      }
      final db = await _dbService.database;
      final rows = await db.query(
        'products',
        where: 'partNumber = ?',
        whereArgs: [partNumber.trim()],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Product.fromJson(rows.first);
    } catch (e) {
      debugPrint('getByPartNumber error: $e');
      return null;
    }
  }

  Future<Product?> addProduct(Product product, {Uint8List? imageBytes}) async {
    try {
      if (Constants.useRemote) {
        String? currentImagePath = product.imagePath;
        if (currentImagePath != null &&
            !currentImagePath.startsWith('http') &&
            !currentImagePath.startsWith('/api/files/display/')) {
          // It's likely a local file path or web blob URL
          final uploadedUrl = await uploadProductImage(
            currentImagePath,
            bytes: imageBytes,
          );
          if (uploadedUrl != null) {
            product = product.copyWith(imagePath: uploadedUrl);
          }
        }

        final Map<String, dynamic> res;
        if (product.id != 0) {
          res = await _remote.putJson(
              '/products/${product.id}', product.toJson());
        } else {
          res = await _remote.postJson('/products', product.toJson());
        }
        return Product.fromJson(res);
      }
      final db = await _dbService.database;
      if (product.id == 0) {
        final existing = await db.query(
          'products',
          where: 'partNumber = ?',
          whereArgs: [product.partNumber.trim()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          return null;
        }
      }
      if (product.id != 0) {
        // Update existing
        await db.update(
          'products',
          {
            'name': product.name,
            'partNumber': product.partNumber,
            'rackNumber': product.rackNumber,
            'mrp': product.mrp,
            'sellingPrice': product.sellingPrice,
            'wholesalerPrice': product.wholesalerPrice,
            'retailerPrice': product.retailerPrice,
            'mechanicPrice': product.mechanicPrice,
            'stock': product.stock,
            'wholesalerId': product.wholesalerId,
            'imagePath': product.imagePath,
            'description': product.description,
            'enabled': product.enabled ? 1 : 0,
            'deleted': 0,
          },
          where: 'id = ?',
          whereArgs: [product.id],
        );
        return product;
      }

      // Insert new
      final id = await db.insert('products', {
        'name': product.name,
        'partNumber': product.partNumber,
        'rackNumber': product.rackNumber,
        'mrp': product.mrp,
        'sellingPrice': product.sellingPrice,
        'wholesalerPrice': product.wholesalerPrice,
        'retailerPrice': product.retailerPrice,
        'mechanicPrice': product.mechanicPrice,
        'stock': product.stock,
        'wholesalerId': product.wholesalerId,
        'imagePath': product.imagePath,
        'enabled': product.enabled ? 1 : 0,
        'deleted': 0,
      });
      return product.copyWith(id: id);
    } catch (e) {
      debugPrint('Add/update product error: $e');
      return null;
    }
  }

  Future<void> addAlias(
    int productId,
    String alias,
    String? pronunciation,
  ) async {
    if (Constants.useRemote) {
      await _remote.postJson('/products/$productId/aliases', {
        'alias': alias,
        'pronunciation': pronunciation,
      });
      return;
    }
    final db = await _dbService.database;
    await db.insert('product_aliases', {
      'productId': productId,
      'alias': alias,
      'pronunciation': pronunciation,
    });
  }

  Future<List<Map<String, dynamic>>> getAliases(int productId) async {
    if (Constants.useRemote) {
      final list = await _remote.getList('/products/$productId/aliases');
      return list.cast<Map<String, dynamic>>();
    }
    final db = await _dbService.database;
    return db.query(
      'product_aliases',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'id DESC',
    );
  }

  Future<void> deleteAlias(int id) async {
    if (Constants.useRemote) {
      await _remote.delete('/products/aliases/$id');
      return;
    }
    final db = await _dbService.database;
    await db.delete('product_aliases', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addProductsBulk(List<Product> products) async {
    int count = 0;
    try {
      if (Constants.useRemote) {
        final payload = products.map((e) => e.toJson()).toList();
        await _remote.postJson('/products/bulk', payload);
        return products.length;
      }
      final db = await _dbService.database;
      await db.transaction((txn) async {
        for (var product in products) {
          final exists = await txn.query(
            'products',
            columns: ['id'],
            where: 'partNumber = ?',
            whereArgs: [product.partNumber.trim()],
            limit: 1,
          );
          if (exists.isNotEmpty) {
            continue;
          }
          await txn.insert(
            'products',
            {
              'name': product.name,
              'partNumber': product.partNumber.trim(),
              'mrp': product.mrp,
              'sellingPrice': product.sellingPrice,
              'wholesalerPrice': product.wholesalerPrice,
              'retailerPrice': product.retailerPrice,
              'mechanicPrice': product.mechanicPrice,
              'stock': product.stock,
              'wholesalerId': product.wholesalerId,
              'imagePath': product.imagePath,
              'deleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          count++;
        }
      });
      return count;
    } catch (e) {
      debugPrint('Bulk add error: $e');
      return count;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      if (Constants.useRemote) {
        await _remote.delete('/products/$id');
        return true;
      }
      final db = await _dbService.database;
      await db.update('products', {'deleted': 1},
          where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('Delete product error: $e');
      return false;
    }
  }

  Future<bool> deleteProductsBulk(List<int> ids) async {
    if (ids.isEmpty) return true;
    try {
      if (Constants.useRemote) {
        await _remote.postJson('/products/delete-bulk', ids);
        return true;
      }
      final db = await _dbService.database;
      final batch = db.batch();
      for (final id in ids) {
        batch.update('products', {'deleted': 1},
            where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
      return true;
    } catch (e) {
      debugPrint('Bulk delete products error: $e');
      return false;
    }
  }

  Future<List<Product>> getDeletedProducts() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/admin/recycle-bin/products');
        return list
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps =
          await db.query('products', where: 'deleted = 1');
      return maps.map((p) => Product.fromJson(p)).toList();
    } catch (e) {
      debugPrint('Get deleted products error: $e');
      return [];
    }
  }

  Future<bool> restoreProduct(int id) async {
    try {
      if (Constants.useRemote) {
        await _remote.postJson('/admin/recycle-bin/products/$id/restore', {});
        return true;
      }
      final db = await _dbService.database;
      await db.update('products', {'deleted': 0},
          where: 'id = ?', whereArgs: [id]);
      return true;
    } catch (e) {
      debugPrint('Restore product error: $e');
      return false;
    }
  }

  void clearCache() {}
}
