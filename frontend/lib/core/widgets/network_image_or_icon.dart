import 'package:flutter/material.dart';

/// Hiện ảnh từ [url]; url rỗng hoặc tải ảnh lỗi thì hiện [icon].
class NetworkImageOrIcon extends StatelessWidget {
  const NetworkImageOrIcon({
    required this.url,
    required this.icon,
    this.iconSize = 24,
    this.color,
    this.width,
    this.height,
    super.key,
  });

  final String url;
  final IconData icon;
  final double iconSize;
  final Color? color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(icon, size: iconSize, color: color);
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
