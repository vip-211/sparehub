import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/purchase.dart';
import '../services/purchase_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'purchase_form_screen.dart';
import 'bill_viewer_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminPurchaseScreen extends StatefulWidget {
  const AdminPurchaseScreen({super.key});

  @override
  State<AdminPurchaseScreen> createState() => _AdminPurchaseScreenState();
}

class _AdminPurchaseScreenState extends State<AdminPurchaseScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  List<Purchase> _purchases = [];
  List<Purchase> _filteredPurchases = [];
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final data = await _purchaseService.getAllPurchases();
      setState(() {
        _purchases = data;
        _filteredPurchases = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading purchases: $e')),
      );
    }
  }

  void _filterPurchases(String query) {
    setState(() {
      _filteredPurchases = _purchases.where((p) {
        final matchesQuery = p.supplierName.toLowerCase().contains(query.toLowerCase()) ||
            p.productName.toLowerCase().contains(query.toLowerCase()) ||
            p.invoiceNumber.toLowerCase().contains(query.toLowerCase());
        
        if (_selectedDateRange == null) return matchesQuery;
        
        final date = p.purchaseDate;
        final matchesDate = date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
            date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
            
        return matchesQuery && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _filterPurchases(_searchController.text);
    }
  }

  Future<void> _exportExcel() async {
    try {
      final start = _selectedDateRange?.start;
      final end = _selectedDateRange?.end;
      
      String url = '${Constants.baseUrl}/purchases/export/excel';
      if (start != null && end != null) {
        final s = DateFormat('yyyy-MM-dd').format(start);
        final e = DateFormat('yyyy-MM-dd').format(end);
        url += '?start=$s&end=$e';
      }
      
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportExcel,
            tooltip: 'Export Excel',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPurchases,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPurchases.isEmpty
                    ? const Center(child: Text('No purchases found'))
                    : _buildPurchaseList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PurchaseFormScreen()),
          );
          if (result == true) _loadPurchases();
        },
        label: const Text('Add Purchase'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    double total = _filteredPurchases.fold(0, (sum, p) => sum + p.totalAmount);
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryBlue.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildHeaderCard('Total Entries', _filteredPurchases.length.toString(), Icons.list_alt),
          _buildHeaderCard('Total Spend', '₹${total.toStringAsFixed(0)}', Icons.account_balance_wallet),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryBlue),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Supplier/Invoice...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: _filterPurchases,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.date_range, color: _selectedDateRange != null ? AppTheme.primaryBlue : null),
            onPressed: _selectDateRange,
          ),
          if (_selectedDateRange != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _selectedDateRange = null);
                _filterPurchases(_searchController.text);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPurchaseList() {
    return ListView.builder(
      itemCount: _filteredPurchases.length,
      itemBuilder: (context, index) {
        final p = _filteredPurchases[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(p.supplierName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p.productName} (${p.quantity} units)'),
                Text('Inv: ${p.invoiceNumber} | ${DateFormat('dd MMM yyyy').format(p.purchaseDate)}'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${p.totalAmount.toStringAsFixed(2)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 16)),
                if (p.billImageUrl != null || p.billPdfUrl != null)
                  const Icon(Icons.attachment, size: 16, color: Colors.grey),
              ],
            ),
            onTap: () => _showPurchaseDetails(p),
          ),
        );
      },
    );
  }

  void _showPurchaseDetails(Purchase p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Purchase Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            _detailRow('Supplier', p.supplierName),
            _detailRow('Mobile', p.supplierMobile ?? 'N/A'),
            _detailRow('Invoice', p.invoiceNumber),
            _detailRow('Date', DateFormat('dd MMM yyyy').format(p.purchaseDate)),
            _detailRow('Product', p.productName),
            _detailRow('Part No', p.partNumber ?? 'N/A'),
            _detailRow('Quantity', p.quantity.toString()),
            _detailRow('Cost Price', '₹${p.costPrice.toStringAsFixed(2)}'),
            _detailRow('Total', '₹${p.totalAmount.toStringAsFixed(2)}'),
            if (p.notes != null && p.notes!.isNotEmpty) _detailRow('Notes', p.notes!),
            const SizedBox(height: 20),
            Row(
              children: [
                if (p.billImageUrl != null || p.billPdfUrl != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillViewerScreen(
                              url: p.billImageUrl ?? p.billPdfUrl!,
                              isPdf: p.billPdfUrl != null,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('View Bill'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(p),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _confirmDelete(Purchase p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase'),
        content: const Text('Are you sure you want to delete this purchase entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close sheet
              try {
                await _purchaseService.deletePurchase(p.id!);
                _loadPurchases();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
