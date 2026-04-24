
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'constants.dart';

ImageProvider getImageProvider(String? path) {
  if (path == null || path.isEmpty) {
    return const AssetImage('assets/images/logo.png');
  }
  if (path.startsWith('http') || path.startsWith('blob:')) {
    return NetworkImage(path);
  }
  if (path.startsWith('/api/files/display/')) {
    return NetworkImage('${Constants.serverUrl}$path');
  }
  if (!kIsWeb) {
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
  }
  return const AssetImage('assets/images/logo.png');
}

String? getProductImage({
  String? imageLink,
  String? imagePath,
  List<String>? imageLinks,
  String? categoryImageLink,
  String? categoryImagePath,
}) {
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
