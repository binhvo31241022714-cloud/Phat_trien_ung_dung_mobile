import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/media/media_cache.dart';

export '../../core/media/media_cache.dart';

/// Hiện ảnh /api/media/:id (cần token nên không dùng NetworkImage thường).
class MediaImage extends StatefulWidget {
  const MediaImage(
    this.mediaId, {
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
    super.key,
  });

  final String mediaId;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  late Future<Uint8List> _future = MediaCache.load(widget.mediaId);

  @override
  void didUpdateWidget(MediaImage old) {
    super.didUpdateWidget(old);
    if (old.mediaId != widget.mediaId) {
      _future = MediaCache.load(widget.mediaId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return widget.error ??
                const Center(child: Icon(Icons.broken_image_outlined));
          }
          if (!snapshot.hasData) {
            return widget.placeholder ??
                const Center(
                    child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)));
          }
          return Image.memory(snapshot.data!,
              fit: widget.fit,
              gaplessPlayback: true,
              errorBuilder: (context, error, stack) => widget.error ??
                  const Center(child: Icon(Icons.broken_image_outlined)));
        },
      );
}
