import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/catalog_provider.dart';

/// Nút lưu/bỏ lưu một mục qua /api/favorites.
/// [type] là "service", "combo" hoặc "doctor".
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({required this.type, required this.itemId, super.key});
  final String type;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final saved = catalog.isSaved(type, itemId);
    final pending = catalog.isPending(type, itemId);
    return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
            onPressed: pending
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final error = await catalog.toggleFavorite(type, itemId);
                    if (error != null) {
                      messenger.showSnackBar(SnackBar(
                          content: Text(saved
                              ? 'Chưa bỏ lưu được: $error'
                              : 'Chưa lưu được: $error')));
                    }
                  },
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            label: Text(saved ? 'Đã lưu · Bỏ lưu' : 'Lưu để xem sau')));
  }
}
