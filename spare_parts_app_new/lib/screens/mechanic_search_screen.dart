// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:translator/translator.dart';
import '../services/product_service.dart';
import '../services/ocr_service.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../services/order_service.dart';
import 'order_confirmation_screen.dart';
import '../utils/image_utils.dart';
import '../utils/constants.dart';

import 'package:spare_parts_app/providers/auth_provider.dart';
import 'package:spare_parts_app/screens/edit_product_screen.dart';

class MechanicSearchScreen extends StatefulWidget {
  const MechanicSearchScreen({super.key});

  @override
  State<MechanicSearchScreen> createState() => _MechanicSearchScreenState();
}

class _MechanicSearchScreenState extends State<MechanicSearchScreen> {
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final OCRService _ocrService = OCRService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _searchController = TextEditingController();
  final _translator = GoogleTranslator();
  List<Product> _products = [];
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  Map<int, double> _prices = {};
  bool _isLoading = false;
  bool _isListening = false;
  bool _showExtraIcons = false;
  bool _isGridView = true;
  Timer? _debounce;
  bool _voiceAdding = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  void _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _productService.getAllProducts(),
        _productService.getCategories(),
      ]);

      final products = results[0] as List<Product>;
      final categories = results[1] as List<Map<String, dynamic>>;

      final Map<int, double> prices = {};
      for (var p in products) {
        prices[p.id] = await _productService.getPriceForUser(p);
      }

      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _prices = prices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  void _fetchProductsByCategory(int? categoryId) async {
    setState(() {
      _isLoading = true;
      _selectedCategoryId = categoryId;
    });

    List<Product> products;
    if (categoryId == null) {
      products = await _productService.getAllProducts();
    } else {
      products = await _productService.getProductsByCategory(categoryId);
    }

    final Map<int, double> prices = {};
    for (var p in products) {
      prices[p.id] = await _productService.getPriceForUser(p);
    }

    if (mounted) {
      setState(() {
        _products = products;
        _prices = prices;
        _isLoading = false;
      });
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
            // No need to translate if we are listening in English
            setState(() {
              _searchController.text = text;
              if (text.isNotEmpty) {
                _searchProducts(text);
              }
            });
          },
          // Try to support multiple locales
          localeId: 'en_US', // Defaults or can be set dynamically
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _fetchInitialProducts() async {
    setState(() => _isLoading = true);
    final products = await _productService.getAllProducts();
    final Map<int, double> prices = {};
    for (var p in products) {
      prices[p.id] = await _productService.getPriceForUser(p);
    }

    if (mounted) {
      setState(() {
        _products = products;
        _prices = prices;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length >= 2) {
        _searchProducts(query);
      } else if (query.isEmpty) {
        _fetchProductsByCategory(_selectedCategoryId);
      }
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
      final qtyMatch = RegExp(r'(\\d+)\\s*(pcs|pieces|qty|quantity|nos|no)?')
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
      final pnMatch = RegExp(r'[a-z0-9\\-_/\\.]+', caseSensitive: false)
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
          SnackBar(content: Text('No product found for \"$finalQuery\"')),
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

  void _searchProducts(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    final products = await _productService.searchProducts(query);
    final Map<int, double> prices = {};
    for (var p in products) {
      prices[p.id] = await _productService.getPriceForUser(p);
    }

    if (mounted) {
      setState(() {
        _products = products;
        _prices = prices;
        _isLoading = false;
      });
    }
  }

  void _scanQRCode() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('Scan Part QR')),
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
      _searchProducts(pn);

      if (mrp.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanned Part: $pn | MRP: ₹$mrp')),
        );
      }
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
                      color: isListening ? Colors.red : Colors.green,
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
                    Text(
                      'Photo selected',
                      style: const TextStyle(color: Colors.green),
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
                try {
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
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
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
                        color: Colors.grey[200],
                        child: Icon(Icons.image_not_supported,
                            size: 40, color: Colors.grey[400]),
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
                          color: isOutOfStock ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isOutOfStock ? Icons.close : Icons.check,
                          size: 14,
                          color: Colors.white,
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
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.blue,
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
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_shopping_cart,
                                    size: 20, color: Colors.white),
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

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search product or part #',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchInitialData();
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: _searchProducts,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  color: Colors.blue,
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _showExtraIcons = !_showExtraIcons),
                  icon: Icon(
                    _showExtraIcons
                        ? Icons.remove_circle_outlined
                        : Icons.add_circle_outlined,
                    color: Colors.green,
                  ),
                ),
                if (_showExtraIcons) ...[
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.green,
                    ),
                    onPressed: _listen,
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                    onPressed: _scanQRCode,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart,
                        color: Colors.orange),
                    onPressed: _voiceAddToCart,
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.purple),
                    onPressed: _showRequestDialog,
                  ),
                ],
              ],
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(Icons.grid_view,
                            size: 18,
                            color: _selectedCategoryId == null
                                ? Colors.white
                                : Colors.blue),
                        label: const Text('All Products'),
                        selected: _selectedCategoryId == null,
                        onSelected: (_) => _fetchProductsByCategory(null),
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                            color: _selectedCategoryId == null
                                ? Colors.white
                                : Colors.black),
                        checkmarkColor: Colors.white,
                      ),
                    );
                  }
                  final cat = _categories[i - 1];
                  final bool isSelected = _selectedCategoryId == cat['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(_getCategoryIcon(cat['name']),
                          size: 18,
                          color: isSelected ? Colors.white : Colors.blue),
                      label: Text(cat['name']),
                      selected: isSelected,
                      onSelected: (_) => _fetchProductsByCategory(cat['id']),
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black),
                      checkmarkColor: Colors.white,
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isGridView
                    ? _buildProductGrid(_products, cart)
                    : ListView.builder(
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final product = _products[i];
                          final price =
                              _prices[product.id] ?? product.sellingPrice;
                          final bool isOutOfStock = product.stock <= 0;
                          final double discountPercent = product.mrp > 0
                              ? ((1 - (price / product.mrp)) * 100)
                              : 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: InkWell(
                              onTap: () {
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                final isRestricted = authProvider.user?.roles
                                            .contains(Constants.roleAdmin) ==
                                        true ||
                                    authProvider.user?.roles.contains(
                                            Constants.roleSuperManager) ==
                                        true;

                                if (isRestricted) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Admin Action'),
                                      content: const Text(
                                        'What would you like to do?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            cart.addItem(product, price);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${product.name} added to cart',
                                                ),
                                                duration: const Duration(
                                                  seconds: 1,
                                                ),
                                                backgroundColor: Colors.blue,
                                              ),
                                            );
                                          },
                                          child:
                                              const Text('Add to Cart (Test)'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    EditProductScreen(
                                                  product: product,
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text('Edit Product'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (!isOutOfStock) {
                                  cart.addItem(product, price);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${product.name} added to cart',
                                      ),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: Colors.blue,
                                    ),
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Leading Image
                                    Stack(
                                      children: [
                                        Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: getImageProvider(
                                                  product.imagePath),
                                              fit: BoxFit.cover,
                                              onError:
                                                  (exception, stackTrace) =>
                                                      debugPrint(
                                                          'Image load error'),
                                            ),
                                          ),
                                        ),
                                        if (product.stock > 0 &&
                                            product.stock <= 5)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                  Icons.warning_amber,
                                                  size: 12,
                                                  color: Colors.white),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    // Title and Subtitle
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Part: ${product.partNumber}',
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13),
                                          ),
                                          Text(
                                            'Stock: ${isOutOfStock ? "Out of Stock" : product.stock}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: (product.stock > 0 &&
                                                      product.stock <= 5)
                                                  ? Colors.orange.shade700
                                                  : Colors.grey,
                                              fontWeight: (product.stock > 0 &&
                                                      product.stock <= 5)
                                                  ? FontWeight.bold
                                                  : null,
                                            ),
                                          ),
                                          if (discountPercent > 0)
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(top: 4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${discountPercent.toStringAsFixed(0)}% OFF',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    // Trailing Prices and Button
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (product.mrp > price)
                                          Text(
                                            '₹${product.mrp.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        Text(
                                          '₹$price',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (!isOutOfStock)
                                          ElevatedButton(
                                            onPressed: () {
                                              cart.addItem(product, price);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${product.name} added to cart',
                                                  ),
                                                  duration: const Duration(
                                                      seconds: 1),
                                                  backgroundColor: Colors.blue,
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 0),
                                              minimumSize: const Size(60, 32),
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text('Add',
                                                style: TextStyle(fontSize: 13)),
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
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'voice_search',
            onPressed: _listen,
            backgroundColor: _isListening ? Colors.red : Colors.green,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 30),
          ),
          if (cart.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'checkout',
              onPressed: _placeOrder,
              label: Text('Checkout (₹${cart.totalAmount})'),
              icon: const Icon(Icons.shopping_cart_checkout),
              backgroundColor: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }
}
