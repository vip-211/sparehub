import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shimmer/shimmer.dart';
import '../screens/category_products_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/wholesaler_shop_screen.dart';
import '../services/product_service.dart';
import '../services/order_service.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../widgets/cart_badge.dart';
import '../utils/image_utils.dart';
import '../utils/app_theme.dart';

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
  bool _isLoading = true;
  String _homeTitle = 'Parts Mitra';
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
    _searchController.dispose();
    _bannerPageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final allCats = await _productService.getCategories();
      final cats = allCats.where((c) => c['showOnHome'] == 1 || c['showOnHome'] == true).toList();
      final trending = await _productService.getTrendingProducts();
      final bannerData = await _productService.getActiveBanners();
      final homeTitle = await _productService.getCmsSetting('mechanic_home_title', 'Parts Mitra');
      
      if (mounted) {
        setState(() {
          _categories = cats;
          _banners = (bannerData['banners'] as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
          _hotDeals = trending;
          _homeTitle = homeTitle;
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
        _bannerPageController.animateToPage(_currentBannerIndex, duration: const Duration(milliseconds: 800), curve: Curves.fastOutSlowIn);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    return Scaffold(
      backgroundColor: AppTheme.softWhite,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(user),
            SliverToBoxAdapter(
              child: _isLoading ? _buildShimmer() : _buildContent(),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(user) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          child: Stack(
            children: [
              Positioned(
                right: -40, top: -40,
                child: Opacity(opacity: 0.1, child: Icon(Icons.settings_suggest, size: 200, color: Colors.white)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: getImageProvider(user?.shopImagePath),
                            child: user?.shopImagePath == null ? const Icon(Icons.person, color: AppTheme.primaryBlue) : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Good Morning,', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
                              Text(user?.name ?? 'Mechanic', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                            ],
                          ),
                        ),
                        const CartBadge(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _buildSearchBar(),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: (q) => Navigator.pushNamed(context, '/search', arguments: {'query': q}),
        decoration: InputDecoration(
          hintText: 'Search spare parts...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.mic_none, color: AppTheme.secondaryAmber), onPressed: () {}),
              IconButton(icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryBlue), onPressed: () {}),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Top Categories', () => Navigator.pushNamed(context, '/categories')),
        _buildCategoriesList(),
        const SizedBox(height: 24),
        _buildBannerSlider(),
        const SizedBox(height: 24),
        _buildSectionHeader('Trending Deals', () {}),
        _buildTrendingGrid(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.charcoalBlack)),
          GestureDetector(
            onTap: onTap,
            child: const Text('View All', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          return FadeInRight(
            delay: Duration(milliseconds: i * 100),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryProductsScreen(
                      categoryId: cat['id'],
                      categoryName: cat['name'],
                    ),
                  ),
                );
              },
              child: Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      height: 64, width: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: ClipOval(
                        child: Image(
                          image: getImageProvider(cat['imagePath'] ?? cat['categoryImagePath']),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.motorcycle, color: AppTheme.primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(cat['name'], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBannerSlider() {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 180,
      child: PageView.builder(
        controller: _bannerPageController,
        itemCount: _banners.length,
        itemBuilder: (context, i) {
          final b = _banners[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () {
                // If banner has product info, we could open it
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  image: DecorationImage(
                    image: getImageProvider(b['imageUrl'] ?? b['imagePath']),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(begin: Alignment.bottomRight, colors: [Colors.black.withOpacity(0.6), Colors.transparent]),
                  ),
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomLeft,
                  child: Text(b['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, mainAxisSpacing: 16, crossAxisSpacing: 16),
      itemCount: _hotDeals.length.clamp(0, 4),
      itemBuilder: (context, i) {
        final p = _hotDeals[i];
        return FadeInUp(
          delay: Duration(milliseconds: i * 150),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: getImageProvider(p.imageLink ?? p.imagePath ?? p.categoryImageLink ?? p.categoryImagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined),
                          ),
                          Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.favorite_border, size: 18, color: Colors.red))),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('₹${p.sellingPrice}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(width: 8),
                            Text('₹${p.mrp}', style: TextStyle(color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, fontSize: 12)),
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

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(children: List.generate(4, (_) => Expanded(child: Container(height: 80, margin: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))))),
            const SizedBox(height: 24),
            Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          ],
        ),
      ),
    );
  }
}
