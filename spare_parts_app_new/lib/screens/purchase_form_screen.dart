import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/purchase.dart';
import '../models/purchase_item.dart';
import '../services/purchase_service.dart';
import '../utils/app_theme.dart';

class PurchaseFormScreen extends StatefulWidget {
  final Purchase? purchase;
  const PurchaseFormScreen({super.key, this.purchase});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class ItemControllers {
  final TextEditingController productName;
  final TextEditingController partNumber;
  final TextEditingController quantity;
  final TextEditingController costPrice;
  final TextEditingController sellingPrice;
  final TextEditingController gst;
  final TextEditingController totalAmount;

  ItemControllers({
    String? productName,
    String? partNumber,
    String? quantity,
    String? costPrice,
    String? sellingPrice,
    String? gst,
    String? totalAmount,
  })  : productName = TextEditingController(text: productName),
        partNumber = TextEditingController(text: partNumber),
        quantity = TextEditingController(text: quantity ?? '0'),
        costPrice = TextEditingController(text: costPrice ?? '0'),
        sellingPrice = TextEditingController(text: sellingPrice ?? '0'),
        gst = TextEditingController(text: gst ?? '0'),
        totalAmount = TextEditingController(text: totalAmount ?? '0');

  void dispose() {
    productName.dispose();
    partNumber.dispose();
    quantity.dispose();
    costPrice.dispose();
    sellingPrice.dispose();
    gst.dispose();
    totalAmount.dispose();
  }
}

class ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  ActionItem({required this.icon, required this.label, required this.onTap, this.color});
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final PurchaseService _purchaseService = PurchaseService();
  
  late TextEditingController _supplierNameController;
  late TextEditingController _supplierMobileController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _discountController;
  late TextEditingController _totalAmountController;
  late TextEditingController _notesController;
  
  final List<ItemControllers> _itemControllers = [];
  
  DateTime _selectedDate = DateTime.now();
  File? _selectedFile;
  bool _isPdf = false;
  bool _isSaving = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    final p = widget.purchase;
    _supplierNameController = TextEditingController(text: p?.supplierName);
    _supplierMobileController = TextEditingController(text: p?.supplierMobile);
    _invoiceNumberController = TextEditingController(text: p?.invoiceNumber);
    _discountController = TextEditingController(text: p?.discount?.toString() ?? '0');
    _totalAmountController = TextEditingController(text: p?.totalAmount.toString());
    _notesController = TextEditingController(text: p?.notes);
    
    if (p != null && p.items.isNotEmpty) {
      for (var item in p.items) {
        _itemControllers.add(ItemControllers(
          productName: item.productName,
          partNumber: item.partNumber,
          quantity: item.quantity.toString(),
          costPrice: item.costPrice.toString(),
          sellingPrice: item.sellingPrice?.toString(),
          gst: item.gst?.toString(),
          totalAmount: item.totalAmount.toString(),
        ));
      }
    } else {
      _itemControllers.add(ItemControllers());
    }

    if (p != null) _selectedDate = p.purchaseDate;
  }

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierMobileController.dispose();
    _invoiceNumberController.dispose();
    _discountController.dispose();
    _totalAmountController.dispose();
    _notesController.dispose();
    for (var c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _itemControllers.add(ItemControllers());
    });
  }

  void _removeItem(int index) {
    if (_itemControllers.length > 1) {
      setState(() {
        _itemControllers[index].dispose();
        _itemControllers.removeAt(index);
        _calculateGrandTotal();
      });
    }
  }

  void _calculateItemTotal(int index) {
    final c = _itemControllers[index];
    double qty = double.tryParse(c.quantity.text) ?? 0;
    double price = double.tryParse(c.costPrice.text) ?? 0;
    double gst = double.tryParse(c.gst.text) ?? 0;
    
    double total = (qty * price) + gst;
    c.totalAmount.text = total.toStringAsFixed(2);
    _calculateGrandTotal();
  }

  void _calculateGrandTotal() {
    double grandTotal = 0;
    for (var c in _itemControllers) {
      grandTotal += double.tryParse(c.totalAmount.text) ?? 0;
    }
    double discount = double.tryParse(_discountController.text) ?? 0;
    _totalAmountController.text = (grandTotal - discount).toStringAsFixed(2);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _isPdf = false;
      });
    }
  }

  Future<void> _scanBill() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.camera)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async => Navigator.pop(context, await picker.pickImage(source: ImageSource.gallery)),
            ),
          ],
        ),
      ),
    );

    if (picked == null) return;

    setState(() => _isScanning = true);
    try {
      final dataStr = await _purchaseService.scanBill(picked.path);
      final data = Map<String, dynamic>.from(jsonDecode(dataStr));

      if (data['error'] != null) {
        throw data['error'];
      }

      setState(() {
        if (data['supplierName'] != null) _supplierNameController.text = data['supplierName'];
        if (data['invoiceNumber'] != null) _invoiceNumberController.text = data['invoiceNumber'];
        if (data['purchaseDate'] != null) _selectedDate = DateTime.parse(data['purchaseDate']);
        if (data['discount'] != null) _discountController.text = data['discount'].toString();
        if (data['totalAmount'] != null) _totalAmountController.text = data['totalAmount'].toString();
        
        final items = data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          // Clear existing default item if it's empty
          if (_itemControllers.length == 1 && _itemControllers[0].productName.text.isEmpty) {
            _itemControllers[0].dispose();
            _itemControllers.clear();
          }

          for (var item in items) {
            _itemControllers.add(ItemControllers(
              productName: item['productName']?.toString(),
              partNumber: item['partNumber']?.toString(),
              quantity: item['quantity']?.toString(),
              costPrice: item['costPrice']?.toString(),
              gst: item['gst']?.toString(),
              totalAmount: item['totalAmount']?.toString(),
            ));
          }
        }
        
        if (data['totalQuantity'] != null) {
           _notesController.text = '${_notesController.text}\nTotal items detected: ${data['totalQuantity']}'.trim();
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill scanned successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _isPdf = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      String? fileUrl;
      if (_selectedFile != null) {
        fileUrl = await _purchaseService.uploadBill(_selectedFile!.path);
      }

      final purchase = Purchase(
        id: widget.purchase?.id,
        supplierName: _supplierNameController.text,
        supplierMobile: _supplierMobileController.text,
        invoiceNumber: _invoiceNumberController.text,
        purchaseDate: _selectedDate,
        items: _itemControllers.map((c) => PurchaseItem(
          productName: c.productName.text,
          partNumber: c.partNumber.text,
          quantity: int.parse(c.quantity.text),
          costPrice: double.parse(c.costPrice.text),
          sellingPrice: double.tryParse(c.sellingPrice.text),
          gst: double.tryParse(c.gst.text),
          totalAmount: double.parse(c.totalAmount.text),
        )).toList(),
        discount: double.tryParse(_discountController.text),
        totalAmount: double.parse(_totalAmountController.text),
        notes: _notesController.text,
        billImageUrl: _isPdf ? null : (fileUrl ?? widget.purchase?.billImageUrl),
        billPdfUrl: _isPdf ? (fileUrl ?? widget.purchase?.billPdfUrl) : null,
      );

      if (widget.purchase == null) {
        await _purchaseService.createPurchase(purchase);
      } else {
        await _purchaseService.updatePurchase(widget.purchase!.id!, purchase);
      }

      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.purchase == null ? 'Add Purchase' : 'Edit Purchase')),
      body: _isSaving 
          ? const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 10), Text('Saving Purchase...')],
            ))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionWithActions(
                      'Supplier Info',
                      [
                        ActionItem(icon: Icons.camera_alt, label: 'Scan Bill', onTap: _scanBill, color: Colors.green),
                        ActionItem(icon: Icons.add, label: 'Add Product', onTap: _addItem, color: AppTheme.primaryBlue),
                      ],
                    ),
                    _buildField(_supplierNameController, 'Supplier Name', required: true),
                    _buildField(_supplierMobileController, 'Supplier Mobile', keyboardType: TextInputType.phone),
                    _buildField(_invoiceNumberController, 'Invoice Number', required: true),
                    
                    const SizedBox(height: 20),
                    ..._itemControllers.asMap().entries.map((entry) {
                      int idx = entry.key;
                      ItemControllers c = entry.value;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSection('Product ${idx + 1}'),
                              if (_itemControllers.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () => _removeItem(idx),
                                ),
                            ],
                          ),
                          _buildField(c.productName, 'Product Name', required: true),
                          _buildField(c.partNumber, 'Part Number'),
                          Row(
                            children: [
                              Expanded(child: _buildField(c.quantity, 'Quantity', required: true, keyboardType: TextInputType.number, onChanged: (_) => _calculateItemTotal(idx))),
                              const SizedBox(width: 10),
                              Expanded(child: _buildField(c.costPrice, 'Cost Price', required: true, keyboardType: TextInputType.number, onChanged: (_) => _calculateItemTotal(idx))),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(child: _buildField(c.gst, 'GST/Tax', keyboardType: TextInputType.number, onChanged: (_) => _calculateItemTotal(idx))),
                              const SizedBox(width: 10),
                              Expanded(child: _buildField(c.sellingPrice, 'Selling Price', keyboardType: TextInputType.number)),
                            ],
                          ),
                          _buildField(c.totalAmount, 'Item Total', required: true, keyboardType: TextInputType.number, readOnly: true),
                          const Divider(height: 40),
                        ],
                      );
                    }).toList(),

                    _buildSection('Financial Summary'),
                    _buildField(_discountController, 'Discount Amount', keyboardType: TextInputType.number, onChanged: (_) => _calculateGrandTotal()),
                    _buildField(_totalAmountController, 'Grand Total', required: true, keyboardType: TextInputType.number, readOnly: true),
                    
                    const SizedBox(height: 20),
                    _buildSection('Other Info'),
                    _buildDatePicker(),
                    _buildField(_notesController, 'Notes', maxLines: 3),
                    
                    const SizedBox(height: 20),
                    _buildSection('Bill Attachment'),
                    _buildFilePicker(),
                    
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue, foregroundColor: Colors.white),
                        child: const Text('Save Purchase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
    );
  }

  Widget _buildSectionWithAction(String title, VoidCallback onAction, String actionLabel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSection(title),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add, size: 18),
          label: Text(actionLabel),
          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue),
        ),
      ],
    );
  }

  Widget _buildSectionWithActions(String title, List<ActionItem> actions) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSection(title),
        Row(
          children: actions.map((action) => TextButton.icon(
            onPressed: action.onTap,
            icon: Icon(action.icon, size: 18),
            label: Text(action.label),
            style: TextButton.styleFrom(foregroundColor: action.color ?? AppTheme.primaryBlue),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool required = false, TextInputType? keyboardType, bool readOnly = false, int maxLines = 1, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
        ),
        keyboardType: keyboardType,
        readOnly: readOnly,
        maxLines: maxLines,
        onChanged: onChanged,
        validator: required ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Purchase Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}'),
            const Icon(Icons.calendar_today, color: AppTheme.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return Column(
      children: [
        if (_selectedFile != null)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(_isPdf ? Icons.picture_as_pdf : Icons.image, color: AppTheme.primaryBlue),
                const SizedBox(width: 10),
                Expanded(child: Text(_selectedFile!.path.split('/').last, overflow: TextOverflow.ellipsis)),
                IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _selectedFile = null)),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _fileBtn(Icons.camera_alt, 'Camera', () => _pickImage(ImageSource.camera)),
            _fileBtn(Icons.image, 'Gallery', () => _pickImage(ImageSource.gallery)),
            _fileBtn(Icons.picture_as_pdf, 'PDF', _pickPdf),
          ],
        ),
      ],
    );
  }

  Widget _fileBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
