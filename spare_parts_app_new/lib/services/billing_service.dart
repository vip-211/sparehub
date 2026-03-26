import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';
import 'settings_service.dart';
import '../utils/constants.dart';

class BillingService {
  static Future<void> shareOnWhatsApp(Order order) async {
    final businessName =
        SettingsService.getCachedRemoteSetting('BUSINESS_NAME', 'Parts Mitra');
    final text = 'Hello, here is the order summary from $businessName.\n\n'
            'Order ID: #SH-${order.id}\n'
            'Customer: ${order.customerName}\n'
            'Total: Rs. ${order.totalAmount.toStringAsFixed(2)}\n'
            'Status: ${order.status}\n\n'
            'Items:\n' +
        order.items
            .map((item) =>
                '- ${item.productName} x ${item.quantity}: Rs. ${(item.price * item.quantity).toStringAsFixed(2)}')
            .join('\n') +
        '\n\nThank you for choosing $businessName!';

    final encodedText = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?text=$encodedText');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        // Fallback to web link if app not installed
        final webUrl = Uri.parse('https://wa.me/?text=$encodedText');
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  static Future<void> shareInvoice(Order order) async {
    try {
      final pdfBytes = await _generatePdfBytes(order);
      final output = await getTemporaryDirectory();
      final filePath = "${output.path}/invoice_${order.id}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      final businessName = SettingsService.getCachedRemoteSetting(
          'BUSINESS_NAME', 'Parts Mitra');
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Invoice for Order #SH-${order.id} from $businessName',
        subject: 'Invoice #SH-${order.id}',
      );
    } catch (e) {
      debugPrint('Error sharing invoice: $e');
    }
  }

  static Future<void> generateInvoice(Order order) async {
    try {
      final pdfBytes = await _generatePdfBytes(order);
      final output = await getTemporaryDirectory();
      final filePath = "${output.path}/invoice_${order.id}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      await OpenFile.open(file.path);
    } catch (e) {
      debugPrint('Error generating/opening invoice: $e');
    }
  }

  static Future<Uint8List> _generatePdfBytes(Order order) async {
    final pdf = pw.Document();

    // Fetch business settings
    final businessName =
        SettingsService.getCachedRemoteSetting('BUSINESS_NAME', 'Parts Mitra');
    final businessAddress = SettingsService.getCachedRemoteSetting(
        'BUSINESS_ADDRESS', '123, Auto Parts Market, Industrial Area');
    final businessPhone = SettingsService.getCachedRemoteSetting(
        'BUSINESS_PHONE', '+91 9876543210');
    final businessEmail = SettingsService.getCachedRemoteSetting(
        'BUSINESS_EMAIL', 'info@partsmitra.com');

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a')
        .format(DateTime.tryParse(order.createdAt) ?? DateTime.now());

    // Try to load logo
    pw.MemoryImage? logoImage;
    try {
      final logoUrl = Constants.logoUrl;
      if (logoUrl.isNotEmpty) {
        final bytes =
            (await NetworkAssetBundle(Uri.parse(logoUrl)).load(logoUrl))
                .buffer
                .asUint8List();
        logoImage = pw.MemoryImage(bytes);
      }
    } catch (_) {
      // Silently ignore logo load errors
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null)
                      pw.Image(logoImage, height: 60)
                    else
                      pw.Text(
                        businessName,
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text(businessAddress,
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Phone: $businessPhone | Email: $businessEmail',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                    pw.Text('Order #SH-${order.id}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: $dateStr'),
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 4),
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: _getPdfStatusColor(order.status),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        order.status.toUpperCase(),
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 40),
            pw.Divider(thickness: 2, color: PdfColors.red),
            pw.SizedBox(height: 20),

            // Bill To Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                              color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(order.customerName,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('Customer ID: #${order.customerId}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SELLER:',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                              color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(order.sellerName,
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text('Seller ID: #${order.sellerId}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // Items Table
            pw.TableHelper.fromTextArray(
              headers: ['Description', 'Qty', 'Unit Price', 'Total Amount'],
              data: order.items.map((item) {
                return [
                  item.productName,
                  item.quantity.toString(),
                  'Rs. ${item.price.toStringAsFixed(2)}',
                  'Rs. ${(item.price * item.quantity).toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),

            pw.SizedBox(height: 20),

            // Summary Section
            pw.Row(
              children: [
                pw.Expanded(flex: 2, child: pw.Container()),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:'),
                          pw.Text(
                              'Rs. ${order.totalAmount.toStringAsFixed(2)}'),
                        ],
                      ),
                      if (order.pointsRedeemed > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Points Redeemed:',
                                style:
                                    const pw.TextStyle(color: PdfColors.green)),
                            pw.Text('- Rs. ${order.pointsRedeemed}',
                                style:
                                    const pw.TextStyle(color: PdfColors.green)),
                          ],
                        ),
                      ],
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('GRAND TOTAL:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14)),
                          pw.Text('Rs. ${order.totalAmount.toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 16,
                                  color: PdfColors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 50),

            // Footer Section
            pw.Divider(color: PdfColors.grey300),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Terms & Conditions:',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('1. Goods once sold will not be taken back.',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('2. Warranty as per manufacturer policy.',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.SizedBox(height: 20),
                    pw.Container(
                      width: 120,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: PdfColors.grey700),
                        ),
                      ),
                    ),
                    pw.Text('Authorized Signatory',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text('Thank you for choosing $businessName!',
                  style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey600)),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static PdfColor _getPdfStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return PdfColors.orange;
      case 'APPROVED':
      case 'PACKED':
        return PdfColors.blue;
      case 'OUT_FOR_DELIVERY':
        return PdfColors.amber;
      case 'DELIVERED':
        return PdfColors.green;
      case 'CANCELLED':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }
}
