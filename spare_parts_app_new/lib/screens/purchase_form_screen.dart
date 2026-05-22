import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/purchase.dart';
import '../services/purchase_service.dart';
import '../utils/app_theme.dart';

class PurchaseFormScreen extends StatefulWidget {
  final Purchase? purchase;
  const PurchaseFormScreen({super.key, this.purchase});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final PurchaseService _purchaseService = PurchaseService();
  
  late TextEditingController _supplierNameController;
  late TextEditingController _supplierMobileController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _productNameController;
  late TextEditingController _partNumberController;
  late TextEditingController _quantityController;
  late TextEditingController _costPriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _gstController;
  late TextEditingController _totalAmountController;
  late TextEditingController _dailyAmountController;
  late TextEditingController _remainingAmountController;
  late TextEditingController _notesController;
  
  DateTime _selectedDate = DateTime.now();
  File? _selectedFile;
  bool _isPdf = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.purchase;
    _supplierNameController = TextEditingController(text: p?.supplierName);
    _supplierMobileController = TextEditingController(text: p?.supplierMobile);
    _invoiceNumberController = TextEditingController(text: p?.invoiceNumber);
    _productNameController = TextEditingController(text: p?.productName);
    _partNumberController = TextEditingController(text: p?.partNumber);
    _quantityController = TextEditingController(text: p?.quantity.toString());
    _costPriceController = TextEditingController(text: p?.costPrice.toString());
    _sellingPriceController = TextEditingController(text: p?.sellingPrice?.toString());
    _gstController = TextEditingController(text: p?.gst?.toString());
    _totalAmountController = TextEditingController(text: p?.totalAmount.toString());
    _dailyAmountController = TextEditingController(text: p?.dailyAmount?.toString());
    _remainingAmountController = TextEditingController(text: p?.remainingAmount?.toString());
    _notesController = TextEditingController(text: p?.notes);
    if (p != null) _selectedDate = p.purchaseDate;
  }

  void _calculateTotal() {
    double qty = double.tryParse(_quantityController.text) ?? 0;
    double price = double.tryParse(_costPriceController.text) ?? 0;
    double gst = double.tryParse(_gstController.text) ?? 0;
    
    double total = (qty * price) + gst;
    _totalAmountController.text = total.toStringAsFixed(2);
    _calculateRemaining();
  }

  void _calculateRemaining() {
    double total = double.tryParse(_totalAmountController.text) ?? 0;
    double daily = double.tryParse(_dailyAmountController.text) ?? 0;
    double remaining = total - daily;
    _remainingAmountController.text = remaining.toStringAsFixed(2);
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
        productName: _productNameController.text,
        partNumber: _partNumberController.text,
        quantity: int.parse(_quantityController.text),
        costPrice: double.parse(_costPriceController.text),
        sellingPrice: double.tryParse(_sellingPriceController.text),
        gst: double.tryParse(_gstController.text),
        totalAmount: double.parse(_totalAmountController.text),
        dailyAmount: double.tryParse(_dailyAmountController.text),
        remainingAmount: double.tryParse(_remainingAmountController.text),
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
                    _buildSection('Supplier Info'),
                    _buildField(_supplierNameController, 'Supplier Name', required: true),
                    _buildField(_supplierMobileController, 'Supplier Mobile', keyboardType: TextInputType.phone),
                    _buildField(_invoiceNumberController, 'Invoice Number', required: true),
                    
                    const SizedBox(height: 20),
                    _buildSection('Product Info'),
                    _buildField(_productNameController, 'Product Name', required: true),
                    _buildField(_partNumberController, 'Part Number'),
                    
                    const SizedBox(height: 20),
                    _buildSection('Pricing & Quantity'),
                    Row(
                      children: [
                        Expanded(child: _buildField(_quantityController, 'Quantity', required: true, keyboardType: TextInputType.number, onChanged: (_) => _calculateTotal())),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField(_costPriceController, 'Cost Price', required: true, keyboardType: TextInputType.number, onChanged: (_) => _calculateTotal())),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildField(_gstController, 'GST/Tax', keyboardType: TextInputType.number, onChanged: (_) => _calculateTotal())),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField(_sellingPriceController, 'Selling Price', keyboardType: TextInputType.number)),
                      ],
                    ),
                    _buildField(_totalAmountController, 'Total Amount', required: true, keyboardType: TextInputType.number, readOnly: true),
                    _buildField(_dailyAmountController, 'Daily Purchase Money (Optional)', keyboardType: TextInputType.number, onChanged: (_) => _calculateRemaining()),
                    _buildField(_remainingAmountController, 'Remaining Money (Optional)', keyboardType: TextInputType.number),
                    
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
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
