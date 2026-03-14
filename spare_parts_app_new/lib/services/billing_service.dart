import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/order.dart';

class BillingService {
  static Future<void> shareOnWhatsApp(Order order) async {
    final text = 'Hello, here is the invoice for Order #${order.id}.\n'
        'Total: Rs. ${order.totalAmount}\n'
        'Status: ${order.status}\n'
        'Items:\n' +
        order.items
            .map((item) => '- ${item.productName} x ${item.quantity}: Rs. ${item.price * item.quantity}')
            .join('\n');
    
    final encodedText = Uri.encodeComponent(text);
    final url = Uri.parse('whatsapp://send?text=$encodedText');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Fallback to web link if app not installed
      final webUrl = Uri.parse('https://wa.me/?text=$encodedText');
      await launchUrl(webUrl);
    }
  }

  static Future<void> generateInvoice(Order order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'SpareHub - INVOICE',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Order ID: #${order.id}'),
              pw.Text('Date: ${order.createdAt}'),
              pw.Text('Customer: ${order.customerName}'),
              pw.Text('Seller: ${order.sellerName}'),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Item', 'Qty', 'Price', 'Total'],
                data: order.items
                    .map(
                      (item) => [
                        item.productName,
                        item.quantity.toString(),
                        'Rs. ${item.price}',
                        'Rs. ${item.price * item.quantity}',
                      ],
                    )
                    .toList(),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Grand Total: ',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs. ${order.totalAmount}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/invoice_${order.id}.pdf");
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(file.path);
  }
}
