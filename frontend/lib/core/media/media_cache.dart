import 'dart:typed_data';

import '../../data/services/media_service.dart';

/// Ảnh đã tải trong phiên đăng nhập, theo mediaId. Xóa khi đăng xuất.
class MediaCache {
  static final _items = <String, Future<Uint8List>>{};

  static Future<Uint8List> load(String mediaId) {
    final cached = _items[mediaId];
    if (cached != null) return cached;
    final future = MediaService.shared.bytes(mediaId);
    _items[mediaId] = future;
    // Lỗi thì bỏ khỏi cache để lần sau tải lại được.
    future.then((_) {}, onError: (_) {
      if (identical(_items[mediaId], future)) _items.remove(mediaId);
    });
    return future;
  }

  static void evict(String? mediaId) {
    if (mediaId != null) _items.remove(mediaId);
  }

  static void clear() => _items.clear();
}
