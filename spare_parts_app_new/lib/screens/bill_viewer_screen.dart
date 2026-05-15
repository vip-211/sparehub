import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../utils/image_utils.dart';
import '../utils/constants.dart';
import 'package:photo_view/photo_view.dart';

class BillViewerScreen extends StatelessWidget {
  final String url;
  final bool isPdf;

  const BillViewerScreen({super.key, required this.url, required this.isPdf});

  @override
  Widget build(BuildContext context) {
    final fullUrl = url.startsWith('http') ? url : '${Constants.serverUrl}$url';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Viewer'),
      ),
      body: isPdf
          ? SfPdfViewer.network(fullUrl)
          : PhotoView(
              imageProvider: getImageProvider(url),
              backgroundDecoration: const BoxDecoration(color: Colors.white),
            ),
    );
  }
}
