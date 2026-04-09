import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/product_service.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/image_utils.dart';
import '../utils/constants.dart';
import '../widgets/cart_badge.dart';
import 'wholesaler_shop_screen.dart'; // For ProductDetailSheet
import 'category_products_screen.dart';

class MechanicHomeScreen extends StatefulWidget {
  const MechanicHomeScreen({super.key});

  @override
  State<MechanicHomeScreen> createState() => _MechanicHomeScreenState();
}

class _MechanicHomeScreenState extends State<MechanicHomeScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();
  List<Product> _hotDeals = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _homeTitle = 'Parts Mitra';
  String _bannerText = 'मार्केटमध्ये दर वाढले,\nparts mitra ॲप वर नाही.';
  String _bannerBtn = 'आता खरेदी करा';
  List<String> _layoutOrder = ['header', 'search_bar', 'categories', 'banner', 'hot_deals'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final products = await _productService.getAllProducts(page: 0, size: 10);
      
      final homeTitle = await _productService.getCmsSetting('mechanic_home_title', 'Parts Mitra');
      final bannerText = await _productService.getCmsSetting('mechanic_banner_text', 'मार्केटमध्ये दर वाढले,\nparts mitra ॲप वर नाही.');
      final bannerBtn = await _productService.getCmsSetting('mechanic_banner_btn', 'आता खरेदी करा');
      final layoutStr = await _productService.getCmsSetting('mechanic_home_layout', 'header,search_bar,categories,banner,hot_deals');

      final Map<int, double> prices = {};
      for (var p in featured) {
        prices[p.id] = await _productService.getPriceForUser(p);
      }
      for (var p in products) {
        prices[p.id] = await _productService.getPriceForUser(p);
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _hotDeals = featured.isNotEmpty
              ? featured
              : products.where((p) => p.mrp > p.sellingPrice).toList();
          _prices = prices;
          _homeTitle = homeTitle;
          _bannerText = bannerText;
          _bannerBtn = bannerBtn;
          _layoutOrder = layoutStr.split(',').where((s) => s.isNotEmpty).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<int, double> _prices = {};

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _layoutOrder.map((section) {
              switch (section) {
                case 'header':
                  return _buildHeader(user);
                case 'search_bar':
                  return _buildSearchBar();
                case 'categories':
                  return _buildCategories();
                case 'banner':
                  return _buildBanner();
                case 'hot_deals':
                  return _buildHotDeals();
                default:
                  return const SizedBox.shrink();
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _scanQRCode,
            child: CircleAvatar(
              backgroundImage: getImageProvider(user?.shopImagePath),
              onBackgroundImageError: (e, s) => debugPrint('Profile image error: $e'),
              child: user?.shopImagePath == null
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _scanQRCode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_homeTitle,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
                if (user?.name != null)
                  Text(user!.name!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          const Spacer(),
          const CartBadge(),
          IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scanQRCode),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onSubmitted: _onSearchSubmitted,
          decoration: InputDecoration(
            hintText: 'Search with Part Name',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _onSearchSubmitted(_searchController.text),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Bike Brands', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              return GestureDetector(
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
                  width: 80,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      cat['imagePath'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image(
                                      image: getImageProvider(cat['imagePath']),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    cat['iconCodePoint'] != null
                                        ? IconData(cat['iconCodePoint'] as int,
                                            fontFamily: 'MaterialIcons')
                                        : _getCategoryIcon(cat['name']),
                                    size: 30,
                                    color: Colors.blue),
                      const SizedBox(height: 4),
                      Text(cat['name'],
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.blue, Colors.indigo]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20, top: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_bannerText, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(_bannerBtn, style: const TextStyle(color: Colors.black, backgroundColor: Colors.yellow, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Positioned(right: 10, bottom: 10, child: Opacity(opacity: 0.3, child: Icon(Icons.handyman, size: 100, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildHotDeals() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Hot Deals ⚡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            itemCount: _hotDeals.length,
            itemBuilder: (context, index) {
              final p = _hotDeals[index];
              return GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ProductDetailSheet(product: p),
                  );
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                              child: Image(
                                image: getImageProvider(p.imageLink ?? p.imagePath),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'HOT',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('₹${(_prices[p.id] ?? p.sellingPrice).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('₹${p.mrp.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                                const SizedBox(width: 6),
                                Text(
                                  '${((1 - (_prices[p.id] ?? p.sellingPrice) / p.mrp) * 100).toStringAsFixed(0)}% OFF',
                                  style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
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
      ],
    );
  }
}
