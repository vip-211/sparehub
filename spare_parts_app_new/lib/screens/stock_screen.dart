import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../models/product.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final ProductService _service = ProductService();
  final TextEditingController _search = TextEditingController();
  List<Product> _results = [];
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final list = await _service.getAllProducts(page: 0, size: 20);
      setState(() => _results = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _searchNow(String q) async {
    if (q.trim().isEmpty) {
      _loadInitial();
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final list = await _service.searchProducts(q, page: 0, size: 20);
      setState(() => _results = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search by part name or number',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _searchNow,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: CircularProgressIndicator(),
            ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = _results[i];
                final low = p.stock > 0 && p.stock <= 5;
                final out = p.stock <= 0;
                return ListTile(
                  leading: const Icon(Icons.build),
                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Part: ${p.partNumber ?? 'N/A'}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        out ? 'Out of stock' : 'Stock: ${p.stock}',
                        style: TextStyle(
                          color: out
                              ? Colors.red
                              : (low ? Colors.orange : Colors.green),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('₹${p.sellingPrice.toStringAsFixed(0)}'),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
