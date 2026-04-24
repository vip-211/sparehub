import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:animate_do/animate_do.dart';
import '../screens/trending_products_screen.dart';
import '../screens/category_products_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/wholesaler_shop_screen.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/cart_badge.dart';
import '../widgets/quantity_selector.dart';
import '../utils/image_utils.dart';
import '../utils/constants.dart';
import 'package:shimmer/shimmer.dart';

class MechanicHomeScreen extends StatefulWidget {
  const MechanicHomeScreen({super.key});

  @override
  State<MechanicHomeScreen> createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends State<MechanicHomeScreen> {
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final TextEditingController _searchController = TextEditingController();
  List<Product> _hotDeals = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _banners = [];
  List<Order> _recentOrders = [];
  bool _isCarousel = false;
  int _autoScrollSpeed = 3;
  late PageController _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  bool _isLoading = true;
  String _homeTitle = 'Parts Mitra';
  String _bannerText = 'मार्केटमध्ये दर वाढले,\nparts mitra ॲप वर नाही.';
  String _bannerBtn = 'आता खरेदी करा';
  List<String> _layoutOrder = ['header', 'search_bar', 'categories', 'banner', 'hot_deals', 'recent_orders'];

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerPageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    if (!_isCarousel || _banners.length <= 1) return;
    
    _bannerTimer = Timer.periodic(Duration(seconds: _autoScrollSpeed), (timer) {
      if (_banners.isEmpty) return;
      _currentBannerIndex = (_currentBannerIndex + 1) % _banners.length;
      if (_bannerPageController.hasClients) {
        _bannerPageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    Navigator.pushNamed(context, '/search', arguments: {'query': query});
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
      Navigator.pushNamed(context, '/search', arguments: {'query': pn});
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
    return Icons.motorcycle;
  }

  Future<void> _loadData() async {
    try {
      final allCats = await _productService.getCategories();
      final cats = allCats.where((c) => c['showOnHome'] == 1 || c['showOnHome'] == true).toList();
      final featured = await _productService.getFeaturedProducts();
      final trending = await _productService.getTrendingProducts();
      final products = await _productService.getAllProducts(page: 0, size: 10);
      final bannerData = await _productService.getActiveBanners();
      final myOrders = await _orderService.getMyOrders();
      
      final banners = bannerData['banners'] as List? ?? [];
      final isCarousel = bannerData['isCarousel'] as bool? ?? false;
      final speed = (bannerData['autoScrollSpeed'] as num?)?.toInt() ?? 3;
      
      final homeTitle = await _productService.getCmsSetting('mechanic_home_title', 'Parts Mitra');
      final bannerText = await _productService.getCmsSetting('mechanic_banner_text', 'मार्केटमध्ये दर वाढले,\nparts mitra ॲप वर नाही.');
      final bannerBtn = await _productService.getCmsSetting('mechanic_banner_btn', 'आता खरेदी करा');
      final layoutStr = await _productService.getCmsSetting('mechanic_home_layout', 'header,search_bar,categories,banner,hot_deals,recent_orders');

      final Map<int, double> prices = {};
      for (var p in featured) {
        prices[p.id] = await _productService.getPriceForUser(p);
      }
      for (var p in trending) {
        prices[p.id] = await _productService.getPriceForUser(p);
      }
      for (var p in products) {
        prices[p.id] = await _productService.getPriceForUser(p);
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _banners = banners.map((e) => e as Map<String, dynamic>).toList();
          _recentOrders = myOrders.take(5).toList();
          _isCarousel = isCarousel;
          _autoScrollSpeed = speed;
          _hotDeals = trending.isNotEmpty
              ? trending
              : featured.isNotEmpty
                  ? featured
                  : products.where((p) => p.mrp > p.sellingPrice).toList();
          _prices = prices;
          _homeTitle = homeTitle;
          _bannerText = bannerText;
          _bannerBtn = bannerBtn;
          final List<String> newLayout = layoutStr.split(',').where((s) => s.trim().isNotEmpty).toList();
          if (newLayout.isNotEmpty) {
            _layoutOrder = newLayout;
          }
          _isLoading = false;
        });
        _startBannerAutoScroll();
      }
    } catch (e) {
      debugPrint('Error loading mechanic home data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<int, double> _prices = {};

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: FloatingActionButton(
          onPressed: () {
            // WhatsApp order logic
          },
          backgroundColor: const Color(0xFF25D366),
          child: const Icon(Icons.message, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(user),
            SliverToBoxAdapter(
              child: _isLoading 
                ? _buildShimmerLoading()
                : FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _layoutOrder.map((section) {
                        switch (section) {
                          case 'categories':
                            return _buildCategories();
                          case 'banner':
                            return _buildBanner();
                          case 'hot_deals':
                            return _buildHotDeals();
                          case 'recent_orders':
                            return _buildRecentOrders();
                          default:
                            return const SizedBox.shrink();
                        }
                      }).toList(),
                    ),
                  ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(user) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: true,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: Theme.of(context).primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withBlue(200),
                  ],
                ),
              ),
            ),
            // Abstract background pattern
            Positioned(
              right: -50,
              top: -50,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.settings, size: 250, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white24,
                          backgroundImage: getImageProvider(user?.shopImagePath),
                          child: user?.shopImagePath == null
                              ? const Icon(Icons.person, color: Colors.white, size: 30)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${user?.name ?? "Mechanic"} 👋',
                              style: const TextStyle(
                                color: Colors.white70, 
                                fontSize: 14, 
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5
                              ),
                            ),
                              Text(
                                _homeTitle,
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 26, 
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5
                                ),
                              ),
                          ],
                        ),
                      ),
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: CartBadge(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildSearchBar(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Hero(
      tag: 'search_bar',
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onSubmitted: _onSearchSubmitted,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Search part name, number...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
              prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).primaryColor, size: 28),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIconButton(Icons.mic_none_rounded, () {
                      // Voice search logic here
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice search coming soon!'))
                      );
                    }),
                    const SizedBox(width: 4),
                    _buildIconButton(Icons.qr_code_scanner_rounded, _scanQRCode),
                  ],
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 22),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(height: 25, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5))),
                Container(height: 20, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5))),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 5,
                itemBuilder: (_, __) => Container(
                  width: 80,
                  margin: const EdgeInsets.only(right: 15),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25))),
            const SizedBox(height: 30),
            Container(height: 25, width: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 15),
            Row(
              children: List.generate(2, (index) => Expanded(
                child: Container(
                  height: 240,
                  margin: const EdgeInsets.only(right: 15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Shop by Category', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/categories'),
                child: Text('View All', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return FadeInRight(
                delay: Duration(milliseconds: index * 100),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(
                          categoryId: cat['id'] is int ? cat['id'] : (cat['id'] as num).toInt(),
                          categoryName: cat['name'] as String,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 85,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Container(
                          width: 75,
                          height: 75,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
                            ],
                            border: Border.all(color: Colors.grey.shade50, width: 1),
                          ),
                          child: Center(
                            child: (cat['imageLink'] != null && (cat['imageLink'] as String).isNotEmpty) || (cat['imagePath'] != null && (cat['imagePath'] as String).isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Image(
                                      image: getImageProvider(cat['imageLink'] != null && (cat['imageLink'] as String).isNotEmpty ? cat['imageLink'] : cat['imagePath']),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Icon(
                                    cat['iconCodePoint'] != null
                                        ? IconData(cat['iconCodePoint'] as int, fontFamily: 'MaterialIcons')
                                        : _getCategoryIcon(cat['name']),
                                    size: 38,
                                    color: Theme.of(context).primaryColor),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          cat['name'], 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)
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
    );
  }

  Widget _buildRecentOrders() {
    if (_recentOrders.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Recent Orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/orders'),
                child: Text('View All', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _recentOrders.length,
          itemBuilder: (context, index) {
            final order = _recentOrders[index];
            final statusColor = _getStatusColor(order.status);
            
            return FadeInUp(
              delay: Duration(milliseconds: index * 100),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                  border: Border.all(color: Colors.grey.shade50, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 55, height: 55,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(18)
                      ),
                      child: Icon(Icons.shopping_bag_rounded, color: statusColor, size: 28),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order #${order.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          const SizedBox(height: 4),
                          Text(
                            '${order.items.length} items • ₹${order.totalAmount.toStringAsFixed(0)}', 
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600)
                          ),
                          if (order.status.toUpperCase() == 'DELIVERED' || order.status.toUpperCase() == 'COMPLETED')
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: () {
                                  final cart = Provider.of<CartProvider>(context, listen: false);
                                  cart.reorder(order.items);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Order #${order.id} items added to cart'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      action: SnackBarAction(label: 'CART', onPressed: () => Navigator.pushNamed(context, '/cart')),
                                    )
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Reorder',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING': return Colors.orange;
      case 'CONFIRMED': return Colors.blue;
      case 'SHIPPED': return Colors.purple;
      case 'DELIVERED':
      case 'COMPLETED': return Colors.green;
      case 'CANCELLED': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _onBannerBuyClick(Map<String, dynamic> banner) async {
    final productId = banner['productId'];
    debugPrint('Banner Buy Clicked: productId=$productId');
    if (productId == null) {
      debugPrint('productId is null. Cannot proceed.');
      return;
    }

    try {
      final product = await _productService.getProductById(productId);
      debugPrint('Product retrieved: $product');
      if (product == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found')));
        debugPrint('Product not found for productId: $productId');
        return;
      }

      debugPrint('Product stock: ${product.stock}');
      if (product.stock <= 0) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product is out of stock')));
        debugPrint('Product is out of stock: ${product.stock}');
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ProductDetailSheet(
            product: product,
            initialQuantity: banner['minimumQuantity'] ?? 1,
            isQuantityLocked: banner['quantityLocked'] ?? false,
            bannerId: banner['id'],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling banner buy click: $e');
    }
  }

  Widget _buildBanner() {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: _banners.length,
            onPageChanged: (index) {
              setState(() => _currentBannerIndex = index);
            },
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final String title = banner['title'] ?? '';
              final String? text = banner['text'];
              final String? imagePath = banner['imagePath'];
              final String? imageLink = banner['imageLink'];
              final bool isBuyEnabled = banner['buyEnabled'] ?? false;
              final String buttonText = banner['buttonText'] ?? 'Buy Now';
              
              final String? effectiveImage = imageLink != null && imageLink.isNotEmpty ? imageLink : imagePath;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (effectiveImage != null && effectiveImage.isNotEmpty)
                        Image(
                          image: getImageProvider(effectiveImage),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 50),
                            ),
                          ),
                        )
                      else
                        Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 50),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.black.withOpacity(0.2),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(25),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FadeInLeft(
                                    child: Text(
                                      title, 
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)
                                    ),
                                  ),
                                  if (text != null && text.isNotEmpty)
                                    FadeInLeft(
                                      delay: const Duration(milliseconds: 200),
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          text, 
                                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isBuyEnabled)
                              FadeInRight(
                                child: ElevatedButton(
                                  onPressed: () => _onBannerBuyClick(banner),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orangeAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _banners.asMap().entries.map((entry) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _currentBannerIndex == entry.key ? 24 : 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentBannerIndex == entry.key 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).primaryColor.withOpacity(0.2),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHotDeals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trending Parts 🔥', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/products/trending'),
                child: Text('See All', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _hotDeals.length,
            itemBuilder: (context, index) {
              final p = _hotDeals[index];
              final double discountPercent = p.mrp > 0 ? ((1 - (p.sellingPrice / p.mrp)) * 100) : 0;
              
              return FadeInUp(
                delay: Duration(milliseconds: index * 100),
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ProductDetailSheet(product: p),
                    );
                  },
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 16, bottom: 20, top: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                      border: Border.all(color: Colors.grey.shade50, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Hero(
                                    tag: 'product_${p.id}',
                                    child: Image(
                                      image: getImageProvider(getProductImage(
                                          imageLink: p.imageLink,
                                          imagePath: p.imagePath,
                                          imageLinks: p.imageLinks,
                                          categoryImageLink: p.categoryImageLink,
                                          categoryImagePath: p.categoryImagePath)),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  ),
                                ),
                              ),
                              if (discountPercent > 0)
                                Positioned(
                                  top: 20, left: 20,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Colors.redAccent, Colors.red]),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8)],
                                    ),
                                    child: Text(
                                      '${discountPercent.toStringAsFixed(0)}% OFF', 
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 20, right: 20,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: Icon(Icons.favorite_border_rounded, size: 18, color: Colors.grey.shade400),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('PN: ${p.partNumber}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('₹${(_prices[p.id] ?? p.sellingPrice).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 20)),
                                      if (p.mrp > p.sellingPrice)
                                        Text('₹${p.mrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, decoration: TextDecoration.lineThrough, color: Colors.grey, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  QuantitySelector(
                                    product: p,
                                    price: _prices[p.id] ?? p.sellingPrice,
                                    onAddToCart: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${p.name} added to cart'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          action: SnackBarAction(label: 'VIEW', onPressed: () => Navigator.pushNamed(context, '/cart')),
                                        )
                                      );
                                    },
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
          ),
        ),
      ],
    );
  }
}
