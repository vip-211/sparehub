import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/image_utils.dart';

class OffersScreen extends StatefulWidget {
  final String? initialOfferType;
  const OffersScreen({super.key, this.initialOfferType});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductService _productService = ProductService();

  List<Product> _dailyOffers = [];
  List<Product> _weeklyOffers = [];
  bool _isLoadingDaily = true;
  bool _isLoadingWeekly = true;

  @override
  void initState() {
    super.initState();
    final idx = (widget.initialOfferType?.toUpperCase() == 'WEEKLY') ? 1 : 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: idx);
    _fetchDailyOffers();
    _fetchWeeklyOffers();
  }

  Future<void> _fetchDailyOffers() async {
    final products = await _productService.getProductsByOfferType('DAILY');
    if (mounted) {
      setState(() {
        _dailyOffers = products;
        _isLoadingDaily = false;
      });
    }
  }

  Future<void> _fetchWeeklyOffers() async {
    final products = await _productService.getProductsByOfferType('WEEKLY');
    if (mounted) {
      setState(() {
        _weeklyOffers = products;
        _isLoadingWeekly = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exclusive Offers',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          indicatorWeight: 3,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          tabs: const [
            Tab(text: 'Daily Offers', icon: Icon(Icons.today_rounded)),
            Tab(text: 'Weekly Deals', icon: Icon(Icons.date_range_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOfferList(_dailyOffers, _isLoadingDaily, _fetchDailyOffers),
          _buildOfferList(_weeklyOffers, _isLoadingWeekly, _fetchWeeklyOffers),
        ],
      ),
    );
  }

  Widget _buildOfferList(List<Product> products, bool isLoading,
      Future<void> Function() onRefresh) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No active offers at the moment.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: products.length,
        itemBuilder: (ctx, i) {
          final product = products[i];
          return _buildOfferCard(product);
        },
      ),
    );
  }

  Widget _buildOfferCard(Product product) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return FutureBuilder<double>(
        future: _productService.getPriceForUser(product),
        builder: (context, snapshot) {
          final price = snapshot.data ?? product.sellingPrice;
          final double discountPercent =
              product.mrp > 0 ? ((1 - (price / product.mrp)) * 100) : 0;

          return Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: Image(
                          image: getImageProvider(
                              product.imagePath ?? product.imageLink),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Icon(Icons.image_not_supported,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                      if (discountPercent > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${discountPercent.toStringAsFixed(0)}% OFF',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onError,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (product.mrp > price) ...[
                            const SizedBox(width: 4),
                            Text(
                              '₹${product.mrp.toStringAsFixed(0)}',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if ((product.offerMinQty ?? 0) > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Min Qty: ${product.offerMinQty}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          Text(
                            product.stock > 0 ? 'In Stock' : 'Out of Stock',
                            style: TextStyle(
                              color: product.stock > 0
                                  ? Colors.green.shade700
                                  : Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: product.stock > 0
                              ? () {
                                  cart.addItem(product, price);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('${product.name} added to cart'),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                              product.stock > 0
                                  ? 'Add to Cart'
                                  : 'Out of Stock',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        });
  }
}
