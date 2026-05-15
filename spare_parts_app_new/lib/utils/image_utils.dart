import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'constants.dart';
import '../widgets/app_loading.dart';

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

Widget buildOptimizedImage(
  String? path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget? placeholder,
  BorderRadius? borderRadius,
}) {
  final fallback = placeholder ??
      Container(
        width: width,
        height: height,
        color: Colors.grey.shade100,
        child: Icon(Icons.inventory_2_outlined, color: Colors.grey.shade400),
      );

  Widget clip(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius, child: child);
  }

  if (path == null || path.isEmpty) {
    final double? w = (width != null && width.isFinite) ? width : null;
    final double? h = (height != null && height.isFinite) ? height : null;
    return clip(Image.asset('assets/images/logo.png',
        fit: fit, width: w, height: h));
  }

  final normalizedPath = _normalizeUrl(path);

  if (normalizedPath.startsWith('http') || normalizedPath.startsWith('blob:')) {
    final double? w = (width != null && width.isFinite) ? width : null;
    final double? h = (height != null && height.isFinite) ? height : null;

    return clip(
      CachedNetworkImage(
        imageUrl: normalizedPath,
        fit: fit,
        width: w,
        height: h,
        fadeInDuration: const Duration(milliseconds: 320),
        fadeOutDuration: const Duration(milliseconds: 160),
        placeholderFadeInDuration: const Duration(milliseconds: 180),
        imageBuilder: (context, imageProvider) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Image(
              image: imageProvider, fit: fit, width: w, height: h),
        ),
        placeholder: (context, url) => AppShimmer(
          child: SkeletonBox(
              width: w ?? 100,
              height: h ?? 100,
              radius: 0),
        ),
        errorWidget: (context, url, error) => fallback,
        memCacheWidth: w != null ? (w * 2).toInt() : null,
      ),
    );
  }

  if (!kIsWeb) {
    final file = File(path);
    if (file.existsSync()) {
      return clip(Image.file(file, fit: fit, width: width, height: height));
    }
  }

  return clip(Image.asset('assets/images/logo.png',
      fit: fit, width: width, height: height));
}

String? getProductImage({
  String? uploadedImage, // First priority: image while creating/editing
  String? imageLink, // Second priority: backend link
  String? imagePath, // Third priority: backend path
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
