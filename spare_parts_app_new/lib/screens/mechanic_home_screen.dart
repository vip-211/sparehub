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
  final FocusNode _searchFocusNode = FocusNode();
  List<Product> _hotDeals = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = true;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  Timer? _debounce;
  String _homeTitle = 'Parts Mitra';
  late PageController _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _removeOverlay();
        });
      } else if (_searchController.text.length >= 2 && _suggestions.isNotEmpty) {
        _showOverlay();
      }
    });
    _loadData();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 40,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 65),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _suggestions.map((s) => ListTile(
                    leading: const Icon(Icons.search, size: 18, color: AppTheme.primaryBlue),
                    title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(s['partNumber'] ?? '', style: const TextStyle(fontSize: 12)),
                    trailing: Text('₹${s['price']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    onTap: () {
                      _searchController.text = s['name'];
                      _removeOverlay();
                      Navigator.pushNamed(context, '/search', arguments: {'query': s['name']});
                    },
                  )).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _bannerPageController.dispose();
    _bannerTimer?.cancel();
    _debounce?.cancel();
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
      });
      _removeOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final list = await _productService.getSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = list;
        });
        if (list.isNotEmpty && _searchFocusNode.hasFocus) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
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
      clipBehavior: Clip.none,
      backgroundColor: AppTheme.primaryBlue,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          child: Stack(
            clipBehavior: Clip.none,
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          onSubmitted: (q) {
            _removeOverlay();
            Navigator.pushNamed(context, '/search', arguments: {'query': q});
          },
          decoration: InputDecoration(
            hintText: 'Search spare parts...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 28),
            suffixIcon: Container(
              margin: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  _buildSearchActionIcon(Icons.mic_none_rounded, AppTheme.secondaryAmber, () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice search coming soon!')));
                  }),
                  _buildSearchActionIcon(Icons.qr_code_scanner_rounded, AppTheme.primaryBlue, () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner coming soon!')));
                  }),
                ],
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: color, size: 24),
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
        const SizedBox(height: 32),
        _buildBannerSlider(),
        const SizedBox(height: 32),
        _buildSectionHeader('Trending Deals', () => Navigator.pushNamed(context, '/search', arguments: {'query': ''})),
        _buildTrendingGrid(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.charcoalBlack, letterSpacing: -0.5)),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Text('View All', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w800, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.primaryBlue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    if (_categories.isEmpty && !_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text('No categories available', style: TextStyle(color: Colors.grey)),
      ));
    }
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final imgPath = cat['imageLink'] ?? cat['imagePath'] ?? cat['categoryImageLink'] ?? cat['categoryImagePath'];
          
          return FadeInRight(
            delay: Duration(milliseconds: i * 50),
            child: Container(
              width: 85,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
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
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 68,
                        width: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: getImageProvider(imgPath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.primaryBlue.withOpacity(0.05),
                                  child: const Icon(Icons.category_outlined, color: AppTheme.primaryBlue, size: 30),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        cat['name'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.charcoalBlack),
                      ),
                    ],
                  ),
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
    return Column(
      children: [
        SizedBox(
          height: 190,
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
                    value = (1 - (value.abs() * 0.2)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeInOut.transform(value) * 190,
                      width: Curves.easeInOut.transform(value) * MediaQuery.of(context).size.width,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {
                    if (b['categoryId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryProductsScreen(
                            categoryId: b['categoryId'],
                            categoryName: b['categoryName'] ?? 'Category',
                          ),
                        ),
                      );
                    } else {
                      Navigator.pushNamed(context, '/search', arguments: {'query': b['title'] ?? ''});
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: getImageProvider(b['imageUrl'] ?? b['imageLink'] ?? b['imagePath'] ?? b['categoryImageLink'] ?? b['categoryImagePath']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: AppTheme.primaryBlue.withOpacity(0.1),
                              child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.primaryBlue),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (b['subtitle'] != null)
                                  Text(b['subtitle'].toString().toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                                const SizedBox(height: 4),
                                Text(b['title'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
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
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentBannerIndex == index ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: _currentBannerIndex == index ? AppTheme.primaryBlue : AppTheme.primaryBlue.withOpacity(0.2),
            ),
          )),
        ),
      ],
    );
  }

  Widget _buildTrendingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        childAspectRatio: 0.7, 
        mainAxisSpacing: 20, 
        crossAxisSpacing: 20
      ),
      itemCount: _hotDeals.length.clamp(0, 4),
      itemBuilder: (context, i) {
        final p = _hotDeals[i];
        final discount = p.mrp > p.sellingPrice ? (((p.mrp - p.sellingPrice) / p.mrp) * 100).round() : 0;
        
        return FadeInUp(
          delay: Duration(milliseconds: i * 100),
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
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: getImageProvider(p.imageLink ?? p.imagePath ?? p.categoryImageLink ?? p.categoryImagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.primaryBlue.withOpacity(0.05),
                              child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.primaryBlue, size: 30),
                            ),
                          ),
                          if (discount > 0)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                child: Text('$discount% OFF', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.favorite_border, size: 18, color: Colors.red)
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2, color: AppTheme.charcoalBlack)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${p.sellingPrice}', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(width: 6),
                            if (discount > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text('₹${p.mrp}', style: TextStyle(color: Colors.grey.shade400, decoration: TextDecoration.lineThrough, fontSize: 12)),
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
