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
import '../services/ai_training_service.dart';

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
  final AITrainingService _aiTraining = AITrainingService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _translator = GoogleTranslator();

  List<Product> _products = [];
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;
  Map<int, double> _prices = {};

  bool _isLoading = false;
  bool _isMoreLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _currentPage = 0;
  final int _pageSize = 20;

  bool _isListening = false;
  bool _showExtraIcons = false;
  bool _isGridView = true;
  Timer? _debounce;
  bool _voiceAdding = false;

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
        setState(() => _categories = cats);
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

  void _fetchProductsByCategory(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    await _fetchProducts(reset: true);
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
            setState(() {
              _searchController.text = text;
              if (text.isNotEmpty) {
                _searchProducts(text);
              }
            });
          },
          localeId: 'en_US',
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
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
      try {
        await _aiTraining.submitVoiceAdd(
          query: finalQuery,
          productId: product.id,
          productName: product.name,
          price: price,
        );
      } catch (_) {}
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice add failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _voiceAdding = false);
    }
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : color,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.white : color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
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
                      color: isListening ? Colors.red : Colors.blue,
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
                      style: TextStyle(color: Colors.blue),
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
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length + (_isMoreLoading ? 2 : 0),
      itemBuilder: (ctx, i) {
        if (i >= products.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final p = products[i];
        final price = _prices[p.id] ?? p.sellingPrice;
        final bool isOutOfStock = p.stock <= 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                // Navigate to detail if needed
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image(
                              image: getImageProvider(p.imagePath ??
                                  p.imageLink ??
                                  p.categoryImageLink ??
                                  p.categoryImagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: Icon(Icons.image_not_supported_outlined,
                                    size: 32,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.3)),
                              ),
                            ),
                          ),
                        ),
                        if (isOutOfStock)
                          Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              color: Colors.black.withOpacity(0.4),
                            ),
                            child: const Center(
                              child: Text(
                                'SOLD OUT',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              isOutOfStock ? Icons.close : Icons.check_circle,
                              size: 14,
                              color: isOutOfStock
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.partNumber,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (cart.items.containsKey(p.id))
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 16),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        final item = cart.items[p.id]!;
                                        if (item.quantity <= (item.minQty ?? 1)) {
                                          cart.removeItem(p.id);
                                        } else {
                                          cart.decrementItem(p.id);
                                        }
                                      },
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    Text(
                                      '${cart.items[p.id]!.quantity}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 16),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => cart.addItem(p, price),
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isOutOfStock
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                      : Theme.of(context).colorScheme.primary,
                                  foregroundColor: isOutOfStock
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.3)
                                      : Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: isOutOfStock
                                    ? null
                                    : () {
                                        cart.addItem(p, price);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('${p.name} added to cart'),
                                            behavior: SnackBarBehavior.floating,
                                            duration:
                                                const Duration(seconds: 1),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        );
                                      },
                                child: const Text(
                                  'BUY',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () => _fetchProducts(reset: true),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              hintStyle: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.close_rounded,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant),
                                      onPressed: () {
                                        _searchController.clear();
                                        _fetchInitialData();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withOpacity(0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                                    width: 1),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                            onChanged: _onSearchChanged,
                            onSubmitted: _searchProducts,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _isGridView = !_isGridView),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            _isGridView
                                ? Icons.grid_view_rounded
                                : Icons.view_list_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildActionChip(
                          icon: _showExtraIcons
                              ? Icons.close_rounded
                              : Icons.auto_awesome_rounded,
                          label: 'Tools',
                          color: Theme.of(context).colorScheme.secondary,
                          onTap: () => setState(
                              () => _showExtraIcons = !_showExtraIcons),
                        ),
                        if (_showExtraIcons) ...[
                          const SizedBox(width: 8),
                          _buildActionChip(
                            icon: _isListening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            label: 'Voice',
                            color: Theme.of(context).colorScheme.error,
                            onTap: _listen,
                            isActive: _isListening,
                          ),
                          const SizedBox(width: 8),
                          _buildActionChip(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scan',
                            color: Theme.of(context).colorScheme.primary,
                            onTap: _scanQRCode,
                          ),
                          const SizedBox(width: 8),
                          _buildActionChip(
                            icon: Icons.add_shopping_cart_rounded,
                            label: 'Quick Add',
                            color: Theme.of(context).colorScheme.tertiary,
                            onTap: _voiceAddToCart,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            if (_categories.isNotEmpty)
              Container(
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length + 1,
                  itemBuilder: (ctx, i) {
                    final isSelected = i == 0
                        ? _selectedCategoryId == null
                        : _selectedCategoryId == _categories[i - 1]['id'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label:
                            Text(i == 0 ? 'All' : _categories[i - 1]['name']),
                        selected: isSelected,
                        onSelected: (_) => _fetchProductsByCategory(
                            i == 0 ? null : _categories[i - 1]['id']),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        elevation: isSelected ? 4 : 0,
                        pressElevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    );
                  },
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
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              const Text('Connecting to server...',
                                  style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              const Text('The first load may take up to 45s',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: _isGridView
                                  ? _buildProductGrid(_products, cart)
                                  : ListView.builder(
                                      controller: _scrollController,
                                      itemCount: _products.length,
                                      itemBuilder: (ctx, i) {
                                        final product = _products[i];
                                        final price = _prices[product.id] ??
                                            product.sellingPrice;
                                        final bool isOutOfStock =
                                            product.stock <= 0;
                                        final double discountPercent =
                                            product.mrp > 0
                                                ? ((1 - (price / product.mrp)) *
                                                    100)
                                                : 0;

                                        return Column(
                                          children: [
                                            Card(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 8,
                                              ),
                                              child: InkWell(
                                                onTap: () {
                                                  final authProvider =
                                                      Provider.of<AuthProvider>(
                                                    context,
                                                    listen: false,
                                                  );
                                                  final isRestricted = authProvider
                                                              .user?.roles
                                                              .contains(Constants
                                                                  .roleAdmin) ==
                                                          true ||
                                                      authProvider.user?.roles
                                                              .contains(Constants
                                                                  .roleSuperManager) ==
                                                          true;

                                                  if (isRestricted) {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) =>
                                                          AlertDialog(
                                                        title: const Text(
                                                            'Admin Action'),
                                                        content: const Text(
                                                          'What would you like to do?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(
                                                                      context)
                                                                  .pop();
                                                              cart.addItem(
                                                                  product,
                                                                  price);
                                                              ScaffoldMessenger
                                                                  .of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    '${product.name} added to cart',
                                                                  ),
                                                                  duration:
                                                                      const Duration(
                                                                    seconds: 1,
                                                                  ),
                                                                  backgroundColor:
                                                                      Colors
                                                                          .blue,
                                                                ),
                                                              );
                                                            },
                                                            child: const Text(
                                                                'Add to Cart (Test)'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.of(
                                                                      context)
                                                                  .pop();
                                                              Navigator.of(
                                                                      context)
                                                                  .push(
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          EditProductScreen(
                                                                    product:
                                                                        product,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            child: const Text(
                                                                'Edit Product'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  } else if (!isOutOfStock) {
                                                    cart.addItem(
                                                        product, price);
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${product.name} added to cart',
                                                        ),
                                                        duration:
                                                            const Duration(
                                                                seconds: 1),
                                                        backgroundColor:
                                                            Colors.blue,
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
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
                                                            width: 60,
                                                            height: 60,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .grey[200],
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              image:
                                                                  DecorationImage(
                                                                image: getImageProvider(product
                                                                        .imagePath ??
                                                                    product
                                                                        .imageLink ??
                                                                    product
                                                                        .categoryImageLink ??
                                                                    product
                                                                        .categoryImagePath),
                                                                fit: BoxFit
                                                                    .cover,
                                                                onError: (exception,
                                                                        stackTrace) =>
                                                                    debugPrint(
                                                                        'Image load error'),
                                                              ),
                                                            ),
                                                          ),
                                                          if (product.stock >
                                                                  0 &&
                                                              product.stock <=
                                                                  5)
                                                            Positioned(
                                                              top: 0,
                                                              right: 0,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(2),
                                                                decoration:
                                                                    const BoxDecoration(
                                                                  color: Colors
                                                                      .orange,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                ),
                                                                child: const Icon(
                                                                    Icons
                                                                        .warning_amber,
                                                                    size: 12,
                                                                    color: Colors
                                                                        .white),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(width: 12),
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
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Text(
                                                              'Part: ${product.partNumber}',
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                  fontSize: 13),
                                                            ),
                                                            Text(
                                                              'Stock: ${isOutOfStock ? "Out of Stock" : product.stock}',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: (product.stock >
                                                                            0 &&
                                                                        product.stock <=
                                                                            5)
                                                                    ? Colors
                                                                        .orange
                                                                        .shade700
                                                                    : Colors
                                                                        .grey,
                                                                fontWeight: (product.stock >
                                                                            0 &&
                                                                        product.stock <=
                                                                            5)
                                                                    ? FontWeight
                                                                        .bold
                                                                    : null,
                                                              ),
                                                            ),
                                                            if (discountPercent >
                                                                0)
                                                              Container(
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        top: 4),
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .red
                                                                      .shade50,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: Text(
                                                                  '${discountPercent.toStringAsFixed(0)}% OFF',
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .red,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        11,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      // Trailing Prices and Button
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .end,
                                                        children: [
                                                          if (product.mrp >
                                                              price)
                                                            Text(
                                                              '₹${product.mrp.toStringAsFixed(0)}',
                                                              style:
                                                                  const TextStyle(
                                                                decoration:
                                                                    TextDecoration
                                                                        .lineThrough,
                                                                color:
                                                                    Colors.grey,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          Text(
                                                            '₹$price',
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.blue,
                                                              fontSize: 17,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
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
                                                                    content:
                                                                        Text(
                                                                      '${product.name} added to cart',
                                                                    ),
                                                                    duration: const Duration(
                                                                        seconds:
                                                                            1),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .blue,
                                                                  ),
                                                                );
                                                              },
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        0),
                                                                minimumSize:
                                                                    const Size(
                                                                        60, 32),
                                                                backgroundColor:
                                                                    Colors.blue,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                                shape:
                                                                    RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                              ),
                                                              child: const Text(
                                                                  'Add',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          13)),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (i == _products.length - 1 &&
                                                _isMoreLoading)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 16),
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
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
