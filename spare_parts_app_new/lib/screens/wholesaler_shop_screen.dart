// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../services/settings_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/product_service.dart';
import '../services/ocr_service.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/order_service.dart';
import '../models/order.dart';
import '../utils/image_utils.dart';
import 'order_confirmation_screen.dart';
import 'cart_screen.dart';
import '../utils/constants.dart';

import 'package:spare_parts_app/screens/edit_product_screen.dart';
import 'package:spare_parts_app/providers/auth_provider.dart';

class WholesalerShopScreen extends StatefulWidget {
  const WholesalerShopScreen({super.key});

  @override
  State<WholesalerShopScreen> createState() => _WholesalerShopScreenState();
}

class _WholesalerShopScreenState extends State<WholesalerShopScreen> {
  final _translator = GoogleTranslator();
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final OCRService _ocrService = OCRService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  Map<int, double> _prices = {};

  bool _isLoading = true;
  bool _isMoreLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _currentPage = 0;
  final int _pageSize = 20;

  bool _isListening = false;
  bool _voiceAdding = false;
  bool _showExtraIcons = false;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchInitialData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isMoreLoading &&
        _hasMore &&
        !_isLoading) {
      _fetchMoreProducts();
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _fetchCategories();
      await _fetchProducts(reset: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final cats = await _productService.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      rethrow;
    }
  }

  Future<void> _fetchProducts({bool reset = false}) async {
    if (!mounted) return;

    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMore = true;
        _products = [];
        _errorMessage = null;
      });
    }

    try {
      final List<Product> newProducts;
      if (_selectedCategoryId != null) {
        newProducts = await _productService.getProductsByCategory(
          _selectedCategoryId!,
          page: _currentPage,
          size: _pageSize,
        );
      } else {
        newProducts = await _productService.getAllProducts(
          page: _currentPage,
          size: _pageSize,
        );
      }

      final Map<int, double> newPrices = {};
      for (var p in newProducts) {
        newPrices[p.id] = await _productService.getPriceForUser(p);
      }

      if (mounted) {
        setState(() {
          if (reset) {
            _products = newProducts;
            _prices = newPrices;
          } else {
            _products.addAll(newProducts);
            _prices.addAll(newPrices);
          }
          _isLoading = false;
          _isMoreLoading = false;
          _hasMore = newProducts.length >= _pageSize;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMoreLoading = false;
          if (reset) _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load products: $e')),
        );
      }
    }
  }

  Future<void> _fetchMoreProducts() async {
    if (_isMoreLoading || !_hasMore) return;

    setState(() {
      _isMoreLoading = true;
      _currentPage++;
    });

    await _fetchProducts(reset: false);
  }

  void _onCategorySelected(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _fetchProducts(reset: true);
  }

  void _onSearchChanged(String val) {
    _applyFilters();
  }

  void _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result != null) {
        int? selectedCategoryId;

        if (mounted) {
          final dialogResult = await showDialog<int>(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Target Category'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Select a category to assign all imported products to:'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('Auto-categorize (AI)'),
                        ),
                        ..._categories.map((c) => DropdownMenuItem<int>(
                              value: c['id'] as int?,
                              child: Text(c['name'] ?? ''),
                            )),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedCategoryId = val),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, -1), // Cancel
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selectedCategoryId),
                    child: const Text('Start Import'),
                  ),
                ],
              ),
            ),
          );

          if (dialogResult == -1) return;
          selectedCategoryId = dialogResult;
        }

        setState(() => _isLoading = true);
        Uint8List? bytes = result.files.first.bytes;
        if (bytes == null && !kIsWeb && result.files.first.path != null) {
          bytes = await File(result.files.first.path!).readAsBytes();
        }

        if (bytes == null) {
          throw Exception('Could not read file data');
        }

        if (Constants.useRemote) {
          await _productService.uploadExcel(bytes,
              categoryId: selectedCategoryId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Imported successfully!')),
            );
            _fetchProducts(reset: true);
          }
        } else {
          final count = await _productService.importProductsFromExcel(bytes,
              categoryId: selectedCategoryId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Imported $count products locally!Base')),
            );
            _fetchProducts(reset: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _exportExcel() async {
    try {
      final bytes = await _productService.exportProductsToExcel();
      if (kIsWeb) {
        // Handle web export if needed or just use printing/download
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/products_export.xlsx');
        await file.writeAsBytes(bytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to ${file.path}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredProducts = _products.where((p) {
        final matchesSearch = q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.partNumber.toLowerCase().contains(q);
        // Note: category filtering is now handled at API level via reset: true
        return matchesSearch;
      }).toList();
    });
  }

  Future<void> _voiceAddToCart() async {
    if (_voiceAdding) return;
    final cart = Provider.of<CartProvider>(context, listen: false);
    try {
      final available = await _speech.initialize(
        onStatus: (_) {},
        onError: (_) {},
      );
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice not available')),
        );
        return;
      }
      setState(() => _voiceAdding = true);
      String spoken = '';
      await _speech.listen(
        onResult: (val) {
          spoken = val.recognizedWords;
        },
        localeId: 'en_US',
      );
      // Wait briefly to accumulate final result
      await Future.delayed(const Duration(seconds: 2));
      await _speech.stop();
      if (spoken.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Did not catch that.')),
        );
        return;
      }
      try {
        final t = await _translator.translate(spoken, to: 'en');
        spoken = t.text;
      } catch (_) {}
      final lower = spoken.toLowerCase();
      final qtyMatch = RegExp(r'(\d+)\s*(pcs|pieces|qty|quantity|nos|no)?')
          .allMatches(lower)
          .toList();
      int qty = 1;
      if (qtyMatch.isNotEmpty) {
        qty = int.tryParse(qtyMatch.last.group(1)!) ?? 1;
      }
      String query = lower;
      for (final stop in [
        'add',
        'to cart',
        'cart',
        'qty',
        'quantity',
        'pieces',
        'pcs',
        'of',
        'please',
        'piece'
      ]) {
        query = query.replaceAll(stop, ' ');
      }
      // Try to extract part number-like tokens first
      final pnMatch = RegExp(r'[a-z0-9\-_/\.]+', caseSensitive: false)
          .allMatches(query)
          .map((m) => m.group(0)!)
          .toList();
      String finalQuery = query.trim();
      if (pnMatch.isNotEmpty) {
        finalQuery = pnMatch.join(' ').trim();
      }
      if (finalQuery.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Say product name or part number')),
        );
        return;
      }
      final results = await _productService.searchProducts(finalQuery);
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No product found for "$finalQuery"')),
        );
        return;
      }
      final product = results.first;
      final price = await _productService.getPriceForUser(product);
      for (int i = 0; i < qty; i++) {
        cart.addItem(product, price);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $qty x ${product.name} to cart')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice add failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _voiceAdding = false);
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => setState(() => _isListening = false),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) async {
            String text = val.recognizedWords;
            try {
              final t = await _translator.translate(text, to: 'en');
              text = t.text;
            } catch (_) {}
            setState(() {
              _searchController.text = text;
              _onSearchChanged(text);
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _showRequestDialog() {
    final TextEditingController requestController = TextEditingController();
    XFile? pickedImage;
    bool isListening = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Request Custom Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: requestController,
                decoration: const InputDecoration(
                  hintText: 'Describe the product',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isListening ? Icons.mic : Icons.mic_none,
                      color: isListening ? Colors.red : Colors.redAccent,
                    ),
                    onPressed: () async {
                      if (!isListening) {
                        final available = await _speech.initialize(
                          onStatus: (_) {},
                          onError: (_) {},
                        );
                        if (available) {
                          setDialogState(() => isListening = true);
                          _speech.listen(
                            onResult: (val) async {
                              String text = val.recognizedWords;
                              try {
                                final t = await _translator.translate(
                                  text,
                                  to: 'en',
                                );
                                text = t.text;
                              } catch (_) {}
                              setDialogState(
                                () => requestController.text = text,
                              );
                            },
                          );
                        }
                      } else {
                        setDialogState(() => isListening = false);
                        _speech.stop();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.photo),
                    onPressed: () async {
                      final picker = ImagePicker();
                      pickedImage = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      setDialogState(() {});
                    },
                  ),
                  if (pickedImage != null)
                    const Text(
                      'Photo selected',
                      style: TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = requestController.text.trim();
                if (text.isEmpty) return;
                final id = await _orderService.createOrderRequest(
                  text,
                  photoPath: pickedImage?.path,
                );
                if (id != null && mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request submitted')),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ocrService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scanQRCode() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Scan Product QR')),
        body: MobileScanner(
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              Navigator.pop(ctx, barcodes.first.rawValue);
            }
          },
        ),
      ),
    );

    if (result != null) {
      final parsed = _productService.parseQRContent(result);
      final pn = parsed['partNumber']!;
      final mrp = parsed['mrp']!;

      _searchController.text = pn;
      _onSearchChanged(pn);

      if (mrp.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanned Part: $pn | MRP: ₹$mrp')),
        );
      }
    }
  }

  void _placeOrder() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.items.isEmpty) return;

    final wholesalerId = _products.isNotEmpty ? _products[0].wholesalerId : 1;

    final success = await _orderService.createOrder(
      wholesalerId,
      cart.items.values.toList(),
    );

    if (success != null) {
      cart.clear();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(order: success),
        ),
      );
    }
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 14,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 10,
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 20,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    name = name.toLowerCase();
    if (name.contains('engine')) return Icons.settings_input_component;
    if (name.contains('body')) return Icons.directions_car;
    if (name.contains('brake')) return Icons.stop_circle;
    if (name.contains('tyre') || name.contains('tire')) return Icons.adjust;
    if (name.contains('oil')) return Icons.opacity;
    if (name.contains('light')) return Icons.lightbulb;
    if (name.contains('battery')) return Icons.battery_full;
    if (name.contains('suspension')) return Icons.architecture;
    return Icons.category;
  }

  Widget _buildProductGrid(List<Product> products, CartProvider cart) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final p = products[i];
        final price = _prices[p.id] ?? p.sellingPrice;
        final bool isOutOfStock = p.stock <= 0;

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          color: Theme.of(context).colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: getImageProvider(p.imagePath ??
                          p.imageLink ??
                          p.categoryImageLink ??
                          p.categoryImagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Icon(Icons.image_not_supported,
                            size: 40,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.3)),
                      ),
                    ),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isOutOfStock ? Icons.close : Icons.check,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          if (!isOutOfStock)
                            InkWell(
                              onTap: () {
                                cart.addItem(p, price);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${p.name} added'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.add_shopping_cart,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final userStr =
        SharedPreferences.getInstance().then((p) => p.getString('user'));

    return FutureBuilder<String?>(
        future: userStr,
        builder: (context, snapshot) {
          bool isMechanic = false;
          if (snapshot.hasData && snapshot.data != null) {
            final user = jsonDecode(snapshot.data!);
            final roles = user['roles'] as List<dynamic>?;
            if (roles != null && roles.contains(Constants.roleMechanic)) {
              isMechanic = true;
            }
          }

          return Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search product or part #',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _isGridView = !_isGridView),
                            icon: Icon(_isGridView
                                ? Icons.view_list
                                : Icons.grid_view),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                avatar: Icon(Icons.grid_view,
                                    size: 18,
                                    color: _selectedCategoryId == null
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .primary),
                                label: const Text('All'),
                                selected: _selectedCategoryId == null,
                                onSelected: (selected) =>
                                    _onCategorySelected(null),
                                selectedColor:
                                    Theme.of(context).colorScheme.primary,
                                labelStyle: TextStyle(
                                    color: _selectedCategoryId == null
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onPrimary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface),
                                checkmarkColor:
                                    Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            ..._categories.map((cat) {
                              final id = cat['id'] as int;
                              final name = cat['name'] as String;
                              final bool isSelected = _selectedCategoryId == id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  avatar: Icon(_getCategoryIcon(name),
                                      size: 18,
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary),
                                  label: Text(name),
                                  selected: isSelected,
                                  onSelected: (selected) =>
                                      _onCategorySelected(selected ? id : null),
                                  selectedColor:
                                      Theme.of(context).colorScheme.primary,
                                  labelStyle: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface),
                                  checkmarkColor:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _errorMessage != null && _products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  'Connection Error',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!.contains('Failed host lookup')
                                      ? 'Could not connect to the server. Please check your internet connection or wait for the server to wake up.'
                                      : _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _fetchInitialData,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry Connection'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isLoading && _products.isEmpty
                          ? _buildSkeleton()
                          : RefreshIndicator(
                              onRefresh: () => _fetchProducts(reset: true),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _isGridView
                                        ? _buildProductGrid(
                                            _filteredProducts, cart)
                                        : ListView.builder(
                                            controller: _scrollController,
                                            itemCount: _filteredProducts.length,
                                            itemBuilder: (ctx, i) {
                                              final product =
                                                  _filteredProducts[i];
                                              final price =
                                                  _prices[product.id] ??
                                                      product.sellingPrice;
                                              final bool isOutOfStock =
                                                  product.stock <= 0;
                                              final double discountPercent =
                                                  product.mrp > 0
                                                      ? ((1 -
                                                              (price /
                                                                  product
                                                                      .mrp)) *
                                                          100)
                                                      : 0;

                                              return Card(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                elevation: 4,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  onTap: () {
                                                    if (!isOutOfStock) {
                                                      cart.addItem(
                                                          product, price);
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              '${product.name} added to cart'),
                                                          duration:
                                                              const Duration(
                                                                  seconds: 1),
                                                          backgroundColor:
                                                              Colors.blue,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.white,
                                                          Colors.grey.shade50
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            12.0),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        // Leading Image
                                                        Stack(
                                                          children: [
                                                            Container(
                                                              width: 80,
                                                              height: 80,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .white,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .black
                                                                        .withOpacity(
                                                                            0.05),
                                                                    blurRadius:
                                                                        4,
                                                                    offset:
                                                                        const Offset(
                                                                            0,
                                                                            2),
                                                                  ),
                                                                ],
                                                                image:
                                                                    DecorationImage(
                                                                  image: getImageProvider(
                                                                      product
                                                                          .imagePath),
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  onError: (e,
                                                                          _) =>
                                                                      debugPrint(
                                                                          'Image error: $e'),
                                                                ),
                                                              ),
                                                            ),
                                                            if (product.stock >
                                                                    0 &&
                                                                product.stock <=
                                                                    5)
                                                              Positioned(
                                                                top: 4,
                                                                right: 4,
                                                                child:
                                                                    Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          4),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .orange,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors
                                                                            .black
                                                                            .withOpacity(0.2),
                                                                        blurRadius:
                                                                            4,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: const Icon(
                                                                      Icons
                                                                          .warning_amber,
                                                                      size: 14,
                                                                      color: Colors
                                                                          .white),
                                                                ),
                                                              ),
                                                            if (discountPercent >
                                                                0)
                                                              Positioned(
                                                                bottom: 0,
                                                                left: 0,
                                                                right: 0,
                                                                child:
                                                                    Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          2),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .red
                                                                        .withOpacity(
                                                                            0.8),
                                                                    borderRadius:
                                                                        const BorderRadius
                                                                            .vertical(
                                                                      bottom: Radius
                                                                          .circular(
                                                                              12),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    '${discountPercent.toStringAsFixed(0)}% OFF',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          10,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            width: 16),
                                                        // Title and Subtitle
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                product.name,
                                                                style:
                                                                    const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 16,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                              const SizedBox(
                                                                  height: 6),
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .blue
                                                                      .shade50,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Text(
                                                                  'Part: ${product.partNumber}',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Colors
                                                                        .blue
                                                                        .shade700,
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 6),
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .inventory_2_outlined,
                                                                    size: 14,
                                                                    color: isOutOfStock
                                                                        ? Colors
                                                                            .red
                                                                        : (product.stock <=
                                                                                5
                                                                            ? Colors.orange
                                                                            : Colors.grey),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Text(
                                                                    isOutOfStock
                                                                        ? "Out of Stock"
                                                                        : "Stock: ${product.stock}",
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: isOutOfStock
                                                                          ? Colors
                                                                              .red
                                                                          : (product.stock <= 5
                                                                              ? Colors.orange.shade700
                                                                              : Colors.grey.shade700),
                                                                      fontWeight: product.stock <= 5
                                                                          ? FontWeight
                                                                              .bold
                                                                          : FontWeight
                                                                              .normal,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // Trailing Prices and Button
                                                        const SizedBox(
                                                            width: 8),
                                                        Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .end,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .end,
                                                              children: [
                                                                if (product
                                                                        .mrp >
                                                                    price)
                                                                  Text(
                                                                    '₹${product.mrp.toStringAsFixed(0)}',
                                                                    style:
                                                                        const TextStyle(
                                                                      decoration:
                                                                          TextDecoration
                                                                              .lineThrough,
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                Text(
                                                                  '₹${price.toStringAsFixed(0)}',
                                                                  style:
                                                                      TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                    color: Colors
                                                                        .green
                                                                        .shade700,
                                                                    fontSize:
                                                                        20,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                                height: 12),
                                                            if (!isOutOfStock)
                                                              ElevatedButton(
                                                                onPressed: () {
                                                                  cart.addItem(
                                                                      product,
                                                                      price);
                                                                  ScaffoldMessenger.of(
                                                                          context)
                                                                      .showSnackBar(
                                                                    SnackBar(
                                                                      content: Text(
                                                                          '${product.name} added to cart'),
                                                                      duration: const Duration(
                                                                          seconds:
                                                                              1),
                                                                      backgroundColor:
                                                                          Colors
                                                                              .blue,
                                                                    ),
                                                                  );
                                                                },
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          16),
                                                                  minimumSize:
                                                                      const Size(
                                                                          80,
                                                                          36),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .green
                                                                          .shade600,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                  elevation: 2,
                                                                  shape:
                                                                      RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10),
                                                                  ),
                                                                ),
                                                                child:
                                                                    const Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Icon(
                                                                        Icons
                                                                            .add_shopping_cart,
                                                                        size:
                                                                            16),
                                                                    SizedBox(
                                                                        width:
                                                                            4),
                                                                    Text('Add',
                                                                        style: TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.bold)),
                                                                  ],
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                  if (_isMoreLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
            floatingActionButton: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'voice_search_wholesaler',
                  onPressed: _listen,
                  backgroundColor: _isListening ? Colors.red : Colors.green,
                  child:
                      Icon(_isListening ? Icons.mic : Icons.mic_none, size: 30),
                ),
                if (cart.items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: 'cart_fab',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                    label: Text('Cart (₹${cart.totalAmount})'),
                    icon: const Icon(Icons.shopping_cart),
                    backgroundColor: Colors.green,
                  ),
                ],
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'menu_fab',
                  onPressed: () async {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (ctx) => SafeArea(
                        child: Wrap(
                          children: [
                            if (!isMechanic)
                              ListTile(
                                leading: const Icon(Icons.add_shopping_cart),
                                title: const Text('Voice Add to Cart'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _voiceAddToCart();
                                },
                              ),
                            ListTile(
                              leading: const Icon(Icons.qr_code_scanner),
                              title: const Text('Scan QR'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _scanQRCode();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Scan by Camera (OCR)'),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final partNumber = await _ocrService
                                    .pickAndExtractPartNumber();
                                if (partNumber != null) {
                                  _searchController.text = partNumber;
                                  _onSearchChanged(partNumber);
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.assignment_add,
                                  color: Colors.blue),
                              title: const Text('Request Custom Order'),
                              onTap: () {
                                Navigator.pop(ctx);
                                _showRequestDialog();
                              },
                            ),
                            // Bulk Import/Export removed for mechanics and general users
                          ],
                        ),
                      ),
                    );
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),
          );
        });
  }
}
