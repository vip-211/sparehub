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
    double totalPurchase = _filteredPurchases.fold(0, (sum, p) => sum + p.totalAmount);
    double totalDaily = _filteredPurchases.fold(0, (sum, p) => sum + (p.dailyAmount ?? 0));
    double totalRemaining = _filteredPurchases.fold(0, (sum, p) => sum + (p.remainingAmount ?? 0));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderCard('Total Purchase', '₹${totalPurchase.toStringAsFixed(0)}', Icons.shopping_cart, Colors.blue),
              _buildHeaderCard('Total Paid', '₹${totalDaily.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.green),
              _buildHeaderCard('Total Remaining', '₹${totalRemaining.toStringAsFixed(0)}', Icons.money_off, Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Text('Total Entries: ${_filteredPurchases.length}', 
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
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
    // Group purchases by date
    final Map<String, List<Purchase>> grouped = {};
    for (var p in _filteredPurchases) {
      final dateStr = DateFormat('yyyy-MM-dd').format(p.purchaseDate);
      if (!grouped.containsKey(dateStr)) grouped[dateStr] = [];
      grouped[dateStr]!.add(p);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateStr = sortedDates[dateIndex];
        final purchasesInGroup = grouped[dateStr]!;
        final displayDate = DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
        final boughtTotal = purchasesInGroup.fold(0.0, (sum, p) => sum + p.totalAmount);
        final dailyTotal = purchasesInGroup.fold(0.0, (sum, p) => sum + (p.dailyAmount ?? 0));
        final remainingTotal = boughtTotal - dailyTotal;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(displayDate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (boughtTotal > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text('Total Money: ₹${boughtTotal.toStringAsFixed(0)}', 
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ),
                      GestureDetector(
                        onTap: () => _editDailyPaid(DateTime.parse(dateStr), dailyTotal),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Bought Money: ₹${dailyTotal.toStringAsFixed(0)}', 
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit, size: 10, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                      if (remainingTotal != 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text('Rem: ₹${remainingTotal.toStringAsFixed(0)}', 
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            ...purchasesInGroup.map((p) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(p.supplierName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.productName} (${p.quantity} units)'),
                    Text('Inv: ${p.invoiceNumber}'),
                    if (p.dailyAmount != null && p.dailyAmount! > 0)
                      Text('Daily Money: ₹${p.dailyAmount!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                    if (p.remainingAmount != null && p.remainingAmount! > 0)
                      Text('Remaining: ₹${p.remainingAmount!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
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
            )).toList(),
          ],
        );
      },
    );
  }

  Future<void> _editDailyPaid(DateTime date, double currentAmount) async {
    final controller = TextEditingController(text: currentAmount.toStringAsFixed(0));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bought Money'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount Paid (Bought Money)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final amount = double.tryParse(controller.text) ?? 0;
                await _purchaseService.updateDailyPaid(date, amount);
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true) _loadPurchases();
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
            if (p.dailyAmount != null && p.dailyAmount! > 0)
                _detailRow('Daily Money', '₹${p.dailyAmount!.toStringAsFixed(2)}'),
            if (p.remainingAmount != null && p.remainingAmount! > 0)
                _detailRow('Remaining Money', '₹${p.remainingAmount!.toStringAsFixed(2)}'),
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
