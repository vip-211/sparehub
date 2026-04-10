import 'dart:convert';
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
    try {
      await _remote.postMultipart(
        '/excel/upload',
        fileField: 'file',
        fileName: 'products.xlsx',
        bytes: bytes,
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        fields:
            categoryId != null ? {'categoryId': categoryId.toString()} : null,
      );
    } catch (e) {
      debugPrint('Excel upload error: $e');
      rethrow;
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
          int minOrderQty = 1;
          List<String> imageLinks = [];

          if (row.length >= 12) {
            wholesalerPrice = double.tryParse(getVal(5)) ?? 0;
            retailerPrice = double.tryParse(getVal(6)) ?? 0;
            mechanicPrice = double.tryParse(getVal(7)) ?? 0;
            stock = int.tryParse(getVal(8)) ?? 0;
            minOrderQty = int.tryParse(getVal(10)) ?? 1;
            String linksStr = getVal(11);
            if (linksStr.isNotEmpty) {
              imageLinks = linksStr.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            }
          } else if (row.length >= 9) {
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
              minOrderQty: minOrderQty,
              imageLinks: imageLinks,
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
      TextCellValue('Description'),
      TextCellValue('Min Order Qty'),
      TextCellValue('Image Links'),
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
        TextCellValue(p.description ?? ''),
        IntCellValue(p.minOrderQty),
        TextCellValue(p.imageLinks.join(';')),
      ]);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  Map<String, String> parseQRContent(String raw) {
    // Typical Honda/Spare Part QR format: "PARTNUMBER,MRP,..."
    // or just the part number. We try to extract Part Number and MRP.
    final Map<String, String> result = {'partNumber': raw.trim(), 'mrp': ''};

    // Try common delimiters: comma, pipe, tab
    final parts = raw.split(RegExp(r'[,|\t]')).map((e) => e.trim()).toList();

    if (parts.length >= 2) {
      final pn = parts[0].toUpperCase();
      result['partNumber'] = pn;

      // Look for MRP in subsequent parts
      for (int i = 1; i < parts.length; i++) {
        String p = parts[i].toUpperCase();
        // Remove "MRP" prefix if present
        p = p.replaceAll('MRP', '').trim();
        // Remove any non-numeric currency symbols
        p = p.replaceAll(RegExp(r'[^0-9\.]'), '').trim();

        if (RegExp(r'^\d+(\.\d+)?$').hasMatch(p)) {
          result['mrp'] = p;
          break;
        }
      }
    } else {
      // Try space as delimiter if only 1 part found by other delimiters
      final spaceParts =
          raw.split(RegExp(r'\s+')).map((e) => e.trim()).toList();
      if (spaceParts.length >= 2) {
        result['partNumber'] = spaceParts[0].toUpperCase();
        for (int i = 1; i < spaceParts.length; i++) {
          String p = spaceParts[i].toUpperCase();
          p = p.replaceAll('MRP', '').trim();
          p = p.replaceAll(RegExp(r'[^0-9\.]'), '').trim();
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(p)) {
            result['mrp'] = p;
            break;
          }
        }
      }
    }

    // If no MRP found yet, check if the raw string contains MRP followed by a number
    if (result['mrp']!.isEmpty) {
      final mrpMatch = RegExp(r'MRP[:\s]*(\d+(\.\d+)?)', caseSensitive: false)
          .firstMatch(raw);
      if (mrpMatch != null) {
        result['mrp'] = mrpMatch.group(1)!;
      }
    }

    // Clean up result partNumber (URLs etc.)
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

  Future<List<Product>> getFeaturedProducts() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/products/featured');
        return list
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps =
          await db.query('products', where: 'isFeatured = 1 AND deleted = 0');
      return maps.map((p) => Product.fromJson(p)).toList();
    } catch (e) {
      debugPrint('Get featured products error: $e');
      return [];
    }
  }

  Future<void> updateFeaturedStatus(List<int> productIds, bool isFeatured) async {
    try {
      if (Constants.useRemote) {
        await _remote.postJson('/products/featured', {
          'ids': productIds,
          'isFeatured': isFeatured,
        });
        return;
      }
      final db = await _dbService.database;
      await db.update(
        'products',
        {'isFeatured': isFeatured ? 1 : 0},
        where: 'id IN (${productIds.join(',')})',
      );
    } catch (e) {
      debugPrint('Update featured status error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/categories');
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      final db = await _dbService.database;
      return await db.query('categories',
          where: 'deleted = 0', orderBy: 'displayOrder ASC');
    } catch (e) {
      debugPrint('Get categories error: $e');
      return [];
    }
  }

  Future<void> updateCategory(int id,
      {String? name, String? imagePath, int? displayOrder, int? iconCodePoint, bool? showOnHome}) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (imagePath != null) data['imagePath'] = imagePath;
      if (displayOrder != null) data['displayOrder'] = displayOrder;
      if (iconCodePoint != null) data['iconCodePoint'] = iconCodePoint;
      if (showOnHome != null) data['showOnHome'] = showOnHome ? 1 : 0;

      if (Constants.useRemote) {
        await _remote.putJson('/categories/$id', data);
        return;
      }
      final db = await _dbService.database;
      await db.update('categories', data, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Update category error: $e');
      rethrow;
    }
  }

  Future<String> getCmsSetting(String key, String defaultValue) async {
    try {
      if (Constants.useRemote) {
        final res = await _remote.getJson('/cms/settings/$key');
        return res['value'] ?? defaultValue;
      }
      final db = await _dbService.database;
      final rows = await db
          .query('cms_settings', where: 'key = ?', whereArgs: [key], limit: 1);
      if (rows.isNotEmpty) return rows.first['value'] as String;
    } catch (e) {
      debugPrint('Get CMS setting error: $e');
    }
    return defaultValue;
  }

  Future<void> setCmsSetting(String key, String value) async {
    try {
      if (Constants.useRemote) {
        await _remote.putJson('/cms/settings/$key', {'value': value});
        return;
      }
      final db = await _dbService.database;
      await db.insert('cms_settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Set CMS setting error: $e');
      rethrow;
    }
  }

  Future<Product?> getProductById(int id) async {
    try {
      if (Constants.useRemote) {
        final res = await _remote.getJson('/products/$id');
        return Product.fromJson(res);
      }
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps =
          await db.query('products', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        return Product.fromJson(maps.first);
      }
    } catch (e) {
      debugPrint('Get product by ID error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> getActiveBanners() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/banners/active');
        return {
          'banners': list.map((e) => e as Map<String, dynamic>).toList(),
          'isCarousel': true,
          'autoScrollSpeed': 3,
        };
      }
      return {'banners': [], 'isCarousel': false, 'autoScrollSpeed': 3};
    } catch (e) {
      debugPrint('Get active banners error: $e');
      return {'banners': [], 'isCarousel': false, 'autoScrollSpeed': 3};
    }
  }

  Future<Map<String, dynamic>> getActiveOffers() async {
    try {
      if (Constants.useRemote) {
        final list = await _remote.getList('/offers/active');
        return {
          'offers': list.map((e) => e as Map<String, dynamic>).toList(),
        };
      }
      return {'offers': []};
    } catch (e) {
      debugPrint('Get active offers error: $e');
      return {'offers': []};
    }
  }

  Future<List<Product>> getProductsByCategory(int categoryId,
      {int page = 0, int size = 20}) async {
    try {
      if (Constants.useRemote) {
        final data = await _remote
            .getJson('/products?categoryId=$categoryId&page=$page&size=$size');
        final List<dynamic> list = data['content'];
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

        // Only show enabled products to regular users
        return products.where((p) => p.enabled).toList();
      }
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'categoryId = ? AND deleted = 0',
        whereArgs: [categoryId],
        limit: size,
        offset: page * size,
        orderBy: 'id DESC',
      );
      return maps.map((p) => Product.fromJson(p)).toList();
    } catch (e) {
      debugPrint('Get products by category error: $e');
      return [];
    }
  }

  Future<List<Product>> getAllProducts({int page = 0, int size = 20}) async {
    try {
      if (Constants.useRemote) {
        final data = await _remote.getJson('/products?page=$page&size=$size');
        final List<dynamic> list = data['content'];
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

        // Only show enabled products to regular users
        return products.where((p) => p.enabled).toList();
      }
      final db = await _dbService.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where: 'deleted = 0',
        limit: size,
        offset: page * size,
        orderBy: 'id DESC',
      );
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
        return enabledOnly;
      }
      if (user.roles.contains(Constants.roleRetailer)) {
        return enabledOnly;
      }
      if (user.roles.contains(Constants.roleMechanic)) {
        return enabledOnly;
      }
      return enabledOnly.where((p) => p.sellingPrice > 0).toList();
    } catch (e) {
      debugPrint('Local get products error: $e');
      return [];
    }
  }

  Future<List<Product>> searchProducts(String query,
      {int page = 0, int size = 10}) async {
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
        final data = await _remote.getJson(
          '/products/search?query=${Uri.encodeComponent(correctedQuery)}&page=$page&size=$size',
        );
        final List<dynamic> list = data['content'];
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
          return products;
        }
        if (user.roles.contains(Constants.roleRetailer)) {
          return products;
        }
        if (user.roles.contains(Constants.roleMechanic)) {
          return products;
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
        limit: size,
        offset: page * size,
      );
      final List<Map<String, dynamic>> aliasMatches = await db.rawQuery(
        'SELECT p.* FROM products p INNER JOIN product_aliases a ON a.productId = p.id WHERE a.alias LIKE ? LIMIT ? OFFSET ?',
        ['%$correctedQuery%', size, page * size],
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
        return enabledOnly;
      }
      if (user.roles.contains(Constants.roleRetailer)) {
        return enabledOnly;
      }
      if (user.roles.contains(Constants.roleMechanic)) {
        return enabledOnly;
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

  Future<List<Product>> getProductsByOfferType(String offerType,
      {int page = 0, int size = 20}) async {
    try {
      if (Constants.useRemote) {
        final data = await _remote
            .getJson('/products/offers?type=$offerType&page=$page&size=$size');
        final List<dynamic> list = data['content'];
        return list
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      // Local mode fallback: not fully implemented but returns empty
      return [];
    } catch (e) {
      debugPrint('Get products by offer error: $e');
      return [];
    }
  }

  Future<bool> setProductOffer(int productId, String offerType,
      {bool notifyWhatsApp = false,
      bool notifyInApp = true,
      int? minQty}) async {
    try {
      if (Constants.useRemote) {
        final path =
            '/admin/products/$productId/offer?offerType=$offerType&notifyWhatsApp=$notifyWhatsApp&notifyInApp=$notifyInApp${minQty != null ? '&minQty=$minQty' : ''}';
        await _remote.postJson(path, {});
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Set product offer error: $e');
      return false;
    }
  }

  void clearCache() {}
}
