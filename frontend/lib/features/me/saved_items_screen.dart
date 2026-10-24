import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api_client.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/catalog_provider.dart';
import 'me_widgets.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});
  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  SavedCatalogItems? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Dịch vụ, combo, bác sĩ đã lưu lấy từ /api/favorites.
  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<CatalogProvider>().loadSavedItems();
      if (!mounted) return;
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Mở chi tiết; quay lại thì tải lại vì có thể đã bỏ lưu trong đó.
  Future<void> _open(String route, Object item) async {
    await Navigator.of(context).pushNamed(route, arguments: item);
    await _load();
  }

  Future<void> _remove(String type, String itemId) async {
    final error =
        await context.read<CatalogProvider>().toggleFavorite(type, itemId);
    if (!mounted) return;
    if (error != null) {
      meMessage(context, 'Chưa bỏ lưu được: $error');
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    // Bài viết vẫn là dữ liệu mock của module Nội dung.
    final articles = data.savedArticles;
    final items = _items;
    if (items == null) {
      return MePage(title: 'Đã lưu', children: [
        if (_error != null && !_loading)
          ErrorState(message: _error!, onRetry: _load)
        else
          const Padding(
              padding: EdgeInsets.only(top: 80), child: LoadingView()),
      ]);
    }
    final empty =
        articles.isEmpty && items.services.isEmpty && items.doctors.isEmpty;
    return MePage(title: 'Đã lưu', children: [
      if (_error != null)
        MeCard(
            child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text('Chưa tải lại được: $_error')),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ])),
      if (empty)
        const MeCard(
            child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: Column(children: [
                  Icon(Icons.bookmark_border, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('Chưa có nội dung đã lưu.',
                      style: TextStyle(color: Color(0xFF666666)))
                ])))),
      for (final a in articles)
        _SavedTile(
            a.title,
            'Bài viết',
            () => MeRoutes.open(context, MeRoutes.article, arguments: a),
            () => data.toggleSavedArticle(a.id)),
      for (final s in items.services)
        _SavedTile(
            s.name,
            s.isCombo ? 'Combo' : 'Dịch vụ',
            () => _open(MeRoutes.service, s),
            () => _remove(s.favoriteType, s.id)),
      for (final d in items.doctors)
        _SavedTile(d.fullName, 'Bác sĩ', () => _open(MeRoutes.doctor, d),
            () => _remove('doctor', d.id)),
    ]);
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile(this.title, this.category, this.onTap, this.onRemove);
  final String title, category;
  final VoidCallback onTap, onRemove;
  @override
  Widget build(BuildContext context) => MeCard(
      onTap: onTap,
      child: Row(children: [
        const Icon(Icons.bookmark, color: meBlue),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(category, style: const TextStyle(color: Color(0xFF666666)))
        ])),
        IconButton(
            tooltip: 'Bỏ lưu $title',
            onPressed: onRemove,
            icon: const Icon(Icons.bookmark_remove_outlined))
      ]));
}
