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
  Map<int, double> _prices = {};
  bool _isLoading = false;
  bool _isListening = false;
  bool _showExtraIcons = false;
  Timer? _debounce;
  bool _voiceAdding = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialProducts();
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
        _fetchInitialProducts();
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
      final qtyMatch = RegExp(r'(\\d+)\\s*(pcs|pieces|qty|quantity|nos|no)?').allMatches(lower).toList();
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
      final pnMatch = RegExp(r'[a-z0-9\\-_/\\.]+', caseSensitive: false).allMatches(query).map((m) => m.group(0)!).toList();
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
      _searchController.text = result;
      _searchProducts(result);
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

  ImageProvider _getImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      return const AssetImage('assets/images/logo.png');
    }
    if (path.startsWith('http')) {
      return NetworkImage(path);
    }
    if (path.startsWith('/api/files/display/')) {
      return NetworkImage('${Constants.baseUrl}$path');
    }
    return FileImage(File(path));
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
                          _fetchInitialProducts();
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
                    onPressed: _scanQRCode,
                    icon: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.green,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final partNumber =
                          await _ocrService.pickAndExtractPartNumber();
                      if (partNumber != null) {
                        _searchController.text = partNumber;
                        _searchProducts(partNumber);
                      }
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.green),
                  ),
                  IconButton(
                    onPressed: _listen,
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.green,
                    ),
                  ),
                IconButton(
                  onPressed: _voiceAddToCart,
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.green),
                ),
                  IconButton(
                    onPressed: _showRequestDialog,
                    icon: const Icon(Icons.assignment_add, color: Colors.blue),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (ctx, i) {
                      final product = _products[i];
                      final price = _prices[product.id] ?? product.sellingPrice;
                      final bool isOutOfStock = product.stock <= 0;
                      final double discountPercent = product.mrp > 0
                          ? ((1 - (price / product.mrp)) * 100)
                          : 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: Stack(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                  image: DecorationImage(
                                    image: _getImageProvider(product.imagePath),
                                    fit: BoxFit.cover,
                                    onError: (exception, stackTrace) =>
                                        const Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                              ),
                              if (product.stock > 0 && product.stock <= 5)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.warning_amber,
                                        size: 10, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Part: ${product.partNumber} | Stock: ${isOutOfStock ? "Out of Stock" : product.stock}',
                                style: TextStyle(
                                  color: (product.stock > 0 && product.stock <= 5)
                                      ? Colors.orange.shade700
                                      : null,
                                  fontWeight: (product.stock > 0 && product.stock <= 5)
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                              if (discountPercent > 0)
                                Text(
                                  '${discountPercent.toStringAsFixed(0)}% OFF',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (product.mrp > price)
                                Text(
                                  '₹${product.mrp.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              Text(
                                '₹$price',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            if (authProvider.user?.roles.contains('admin') ??
                                false) {
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
                                      child: const Text('Add to Cart'),
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
                                      child: const Text('Edit'),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: cart.items.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _placeOrder,
              label: Text('Checkout (₹${cart.totalAmount})'),
              icon: const Icon(Icons.shopping_cart_checkout),
              backgroundColor: Colors.blue,
            )
          : null,
    );
  }
}
