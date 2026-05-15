import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shimmer/shimmer.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/translated_text.dart';
import '../services/product_service.dart';
import '../utils/image_utils.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class WholesalerShopScreen extends StatefulWidget {
  const WholesalerShopScreen({super.key});

  @override
  State<WholesalerShopScreen> createState() => _WholesalerShopScreenState();
}

class _WholesalerShopScreenState extends State<WholesalerShopScreen> {
  final ProductService _productService = ProductService();
  List<Product> _products = [];
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;
  Map<int, double> _prices = {};
  late PageController _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _bannerPageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final products = await _productService.getAllProducts(page: 0, size: 50);
      final bannerData = await _productService.getActiveBanners();
      final Map<int, double> prices = {};
      for (var p in products) {
        prices[p.id] = await _productService.getPriceForUser(p);
      }
      if (mounted) {
        setState(() {
          _products = products;
          _banners = (bannerData['banners'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
          _prices = prices;
          _isLoading = false;
        });
        _startBannerTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_banners.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _currentBannerIndex = (_currentBannerIndex + 1) % _banners.length;
      if (_bannerPageController.hasClients) {
        _bannerPageController.animateToPage(_currentBannerIndex,
            duration: const Duration(milliseconds: 800),
            curve: Curves.fastOutSlowIn);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softWhite,
      appBar: AppBar(
        title: const Text('Wholesaler Shop'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildShimmer()
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (_banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: _buildBannerSlider(),
                    ),
                  ),
                if (_products.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: _buildProductGrid(),
                  ),
              ],
            ),
    );
  }

  Widget _buildBannerSlider() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _bannerPageController,
            onPageChanged: (i) => setState(() => _currentBannerIndex = i),
            itemCount: _banners.length,
            itemBuilder: (context, i) {
              final b = _banners[i];
              return AnimatedBuilder(
                animation: _bannerPageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_bannerPageController.position.haveDimensions) {
                    value = _bannerPageController.page! - i;
                    value = (1 - (value.abs() * 0.1)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeInOut.transform(value) * 180,
                      width: Curves.easeInOut.transform(value) *
                          MediaQuery.of(context).size.width,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    if (b['productId'] != null) {
                      _loadAndShowProduct(b['productId']);
                    } else if (b['categoryId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryProductsScreen(
                            categoryId: b['categoryId'],
                            categoryName: b['categoryName'] ?? 'Category',
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          buildOptimizedImage(
                            b['imageUrl'] ?? b['imageLink'] ?? b['imagePath'],
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.6)
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(b['title'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                if (b['text'] != null)
                                  Text(b['text'],
                                      style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
              _banners.length,
              (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentBannerIndex == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: _currentBannerIndex == index
                          ? AppTheme.primaryBlue
                          : AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  )),
        ),
      ],
    );
  }

  void _loadAndShowProduct(dynamic productId) async {
    try {
      final p = await _productService.getProductById(productId is int ? productId : int.parse(productId.toString()));
      if (mounted) _showProductDetails(p);
    } catch (e) {
      debugPrint('Error loading product for banner: $e');
    }
  }

  Widget _buildProductGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final p = _products[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 50),
            child: GestureDetector(
              onTap: () => _showProductDetails(p),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03), blurRadius: 10)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            buildOptimizedImage(p.imageLink ?? p.imagePath),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.favorite_border,
                                    size: 18, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                  '₹${_prices[p.id]?.toStringAsFixed(0) ?? p.sellingPrice}',
                                  style: const TextStyle(
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                              const SizedBox(width: 8),
                              if (p.mrp > p.sellingPrice)
                                Text('₹${p.mrp}',
                                    style: TextStyle(
                                        color: Colors.grey.shade400,
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 12)),
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
        childCount: _products.length,
      ),
    );
  }

  void _showProductDetails(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailSheet(product: p),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No products found.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 16, mainAxisSpacing: 16),
        itemCount: 6,
        itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
      ),
    );
  }
}

class ProductDetailSheet extends StatefulWidget {
  final Product product;
  final bool isQuantityLocked;
  final int? initialQuantity;
  final int? bannerId;
  final int? offerId;

  const ProductDetailSheet({
    super.key,
    required this.product,
    this.isQuantityLocked = false,
    this.initialQuantity,
    this.bannerId,
    this.offerId,
  });

  @override
  State<ProductDetailSheet> createState() => ProductDetailSheetState();
}

class ProductDetailSheetState extends State<ProductDetailSheet> {
  int _currentImageIndex = 0;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: (widget.product.sellingPrice).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _showFullScreenGallery(BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            title: Text(
              '${initialIndex + 1}/${images.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: getImageProvider(images[index]),
                initialScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: images[index]),
              );
            },
            itemCount: images.length,
            loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator(color: Colors.white)),
            pageController: PageController(initialPage: initialIndex),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final cart = Provider.of<CartProvider>(context, listen: false);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final bool isMechanic = user?.roles.contains(Constants.roleMechanic) ?? false;

    final List<String> images = [
      if (p.imageLink != null && p.imageLink!.isNotEmpty) p.imageLink!,
      if (p.imagePath != null && p.imagePath!.isNotEmpty) p.imagePath!,
      ...p.imageLinks.where((e) => e.isNotEmpty),
    ];

    if (images.isEmpty) {
      final catImg = p.categoryImageLink ?? p.categoryImagePath;
      if (catImg != null && catImg.isNotEmpty) images.add(catImg);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppTheme.softWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48, height: 5,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Gallery Card
                  FadeInDown(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Stack(
                        children: [
                          if (images.isNotEmpty)
                            CarouselSlider.builder(
                              itemCount: images.length,
                              options: CarouselOptions(
                                height: 300,
                                viewportFraction: 1.0,
                                onPageChanged: (idx, _) => setState(() => _currentImageIndex = idx),
                              ),
                              itemBuilder: (context, idx, _) => GestureDetector(
                                onTap: () => _showFullScreenGallery(context, images, idx),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: buildOptimizedImage(
                                    images[idx],
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                  ),
                                ),
                              ),
                            )
                          else
                            const Center(child: Icon(Icons.image_not_supported_outlined, size: 80, color: Colors.grey)),
                          
                          if (images.length > 1)
                            Positioned(
                              bottom: 20, left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: images.asMap().entries.map((entry) {
                                  return Container(
                                    width: _currentImageIndex == entry.key ? 20.0 : 8.0,
                                    height: 8.0,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      color: _currentImageIndex == entry.key ? AppTheme.primaryBlue : Colors.grey.shade300,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Product Info
                  FadeInLeft(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Text(p.categoryName?.toUpperCase() ?? 'GENERAL', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                            ),
                            if (p.stock > 0)
                              const Row(children: [Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 16), SizedBox(width: 4), Text('In Stock', style: TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.w800, fontSize: 12))]),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TranslatedText(p.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.charcoalBlack, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Text('SKU: ${p.partNumber}', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  // Price Section
                  FadeInUp(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BEST PRICE', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${p.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.primaryBlue)),
                                  if (p.mrp > p.sellingPrice) ...[
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text('₹${p.mrp.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, decoration: TextDecoration.lineThrough, color: Colors.grey.shade400, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (p.mrp > p.sellingPrice)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: AppTheme.accentGreen, borderRadius: BorderRadius.circular(12)),
                              child: Text('${((p.mrp - p.sellingPrice) / p.mrp * 100).toStringAsFixed(0)}% OFF', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (widget.offerId != null || widget.bannerId != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Special Deal Price',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter agreed price',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.amber.shade50,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Description
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Product Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.charcoalBlack)),
                        const SizedBox(height: 12),
                        TranslatedText(
                          p.description ?? 'High-quality replacement part built for durability and precision performance.',
                          style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 120), // Bottom padding for CTA
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          FadeInUp(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: p.stock > 0 ? () {
                          final double? customPrice = double.tryParse(_priceController.text);
                          cart.addItem(
                            p, 
                            customPrice ?? p.sellingPrice, 
                            quantity: widget.initialQuantity ?? p.minOrderQty,
                            isLocked: widget.isQuantityLocked,
                            bannerId: widget.bannerId,
                            offerId: widget.offerId,
                          );
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${p.name} added to cart'), backgroundColor: AppTheme.primaryBlue, behavior: SnackBarBehavior.floating),
                          );
                        } : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: AppTheme.primaryBlue.withOpacity(0.4),
                        ),
                        child: const Text('ADD TO CART', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
