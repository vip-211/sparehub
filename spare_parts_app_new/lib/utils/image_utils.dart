import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'constants.dart';

String _normalizeUrl(String path) {
  if (path.startsWith('http') || path.startsWith('blob:')) {
    return path;
  }
  if (path.startsWith('/api/files/display/')) {
    return '${Constants.serverUrl}$path';
  }
  // Handle relative paths from backend like /uploads/product1.jpg
  if (path.startsWith('/')) {
    return '${Constants.serverUrl}$path';
  }
  return path;
}

ImageProvider getImageProvider(String? path) {
  if (path == null || path.isEmpty) {
    return const AssetImage('assets/images/logo.png');
  }
  
  final normalizedPath = _normalizeUrl(path);
  
  if (normalizedPath.startsWith('http') || normalizedPath.startsWith('blob:')) {
    return CachedNetworkImageProvider(normalizedPath);
  }
  
  if (!kIsWeb) {
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
  }
  return const AssetImage('assets/images/logo.png');
}

Widget buildOptimizedImage(String? path, {BoxFit fit = BoxFit.cover, double? width, double? height, Widget? placeholder}) {
  if (path == null || path.isEmpty) {
    return placeholder ?? Image.asset('assets/images/logo.png', fit: fit, width: width, height: height);
  }

  final normalizedPath = _normalizeUrl(path);

  if (normalizedPath.startsWith('http') || normalizedPath.startsWith('blob:')) {
    return CachedNetworkImage(
      imageUrl: normalizedPath,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => placeholder ?? Container(
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => placeholder ?? const Icon(Icons.error_outline, color: Colors.red),
      memCacheWidth: width != null ? (width * 2).toInt() : null, // Optimize memory
    );
  }

  if (!kIsWeb) {
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: fit, width: width, height: height);
    }
  }

  return Image.asset('assets/images/logo.png', fit: fit, width: width, height: height);
}

String? getProductImage({
  String? uploadedImage, // First priority: image while creating/editing
  String? imageLink,     // Second priority: backend link
  String? imagePath,     // Third priority: backend path
  List<String>? imageLinks, // Legacy support for multiple links
  String? categoryImageLink, // Fourth priority: category link
  String? categoryImagePath, // Fifth priority: category path
}) {
  if (uploadedImage != null && uploadedImage.isNotEmpty) {
    return uploadedImage;
  }
  if (imageLink != null && imageLink.isNotEmpty) {
    return imageLink;
  }
  if (imagePath != null && imagePath.isNotEmpty) {
    return imagePath;
  }
  if (imageLinks != null && imageLinks.isNotEmpty) {
    return imageLinks.first;
  }
  if (categoryImageLink != null && categoryImageLink.isNotEmpty) {
    return categoryImageLink;
  }
  if (categoryImagePath != null && categoryImagePath.isNotEmpty) {
    return categoryImagePath;
  }
  return null;
}
