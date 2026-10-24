import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/api_client.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/catalog_provider.dart';
import 'me_widgets.dart';

/// Các tab lọc của màn hình Đã lưu.
enum _SavedTab { all, services, doctors, articles }

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});
  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  SavedCatalogItems? _items;
  String? _error;
  bool _loading = true;
  _SavedTab _tab = _SavedTab.all;

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

  /// Mở chi tiết; quay lại thì tải lại để khớp với máy chủ.
  Future<void> _open(String route, Object item) async {
    await Navigator.of(context).pushNamed(route, arguments: item);
    await _load();
  }

  /// Bỏ lưu. Danh sách và số lượng trên tab đổi ngay vì được lọc theo
  /// CatalogProvider.isSaved, không cần tải lại cả màn hình.
  Future<void> _remove(String type, String itemId) async {
    final error =
        await context.read<CatalogProvider>().toggleFavorite(type, itemId);
    if (!mounted || error == null) return;
    meMessage(context, 'Chưa bỏ lưu được: $error');
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final catalog = context.watch<CatalogProvider>();
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
    final services = items.services
        .where((s) => catalog.isSaved(s.favoriteType, s.id))
        .toList();
    final doctors =
        items.doctors.where((d) => catalog.isSaved('doctor', d.id)).toList();

    // Tab "Bài viết" chỉ hiện khi có bài viết đã lưu. Nếu đang chọn tab đó
    // mà bỏ lưu hết thì quay về "Tất cả".
    final tab =
        _tab == _SavedTab.articles && articles.isEmpty ? _SavedTab.all : _tab;
    final tabs = <_SavedTab, String>{
      _SavedTab.all:
          'Tất cả (${services.length + doctors.length + articles.length})',
      _SavedTab.services: 'Dịch vụ (${services.length})',
      _SavedTab.doctors: 'Bác sĩ (${doctors.length})',
      if (articles.isNotEmpty)
        _SavedTab.articles: 'Bài viết (${articles.length})',
    };
    bool show(_SavedTab t) => tab == _SavedTab.all || tab == t;
    final empty = switch (tab) {
      _SavedTab.all => services.isEmpty && doctors.isEmpty && articles.isEmpty,
      _SavedTab.services => services.isEmpty,
      _SavedTab.doctors => doctors.isEmpty,
      _SavedTab.articles => articles.isEmpty,
    };
    final emptyText = switch (tab) {
      _SavedTab.all => 'Chưa có nội dung đã lưu.',
      _SavedTab.services => 'Bạn chưa lưu dịch vụ nào.',
      _SavedTab.doctors => 'Bạn chưa lưu bác sĩ nào.',
      _SavedTab.articles => 'Bạn chưa lưu bài viết nào.',
    };

    return MePage(title: 'Đã lưu', children: [
      // Cùng kiểu chip lọc với màn hình Thông báo.
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final entry in tabs.entries)
              Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                  child: ChoiceChip(
                      label: Text(entry.value),
                      selected: tab == entry.key,
                      showCheckmark: false,
                      selectedColor: Colors.black,
                      labelStyle: TextStyle(
                          color: tab == entry.key ? Colors.white : Colors.grey),
                      onSelected: (_) => setState(() => _tab = entry.key)))
          ])),
      if (_error != null)
        MeCard(
            child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text('Chưa tải lại được: $_error')),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ])),
      if (empty)
        MeCard(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                    child: Column(children: [
                  const Icon(Icons.bookmark_border, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(emptyText,
                      style: const TextStyle(color: Color(0xFF666666)))
                ])))),
      if (show(_SavedTab.articles))
        for (final a in articles)
          _SavedTile(
              a.title,
              'Bài viết',
              () => MeRoutes.open(context, MeRoutes.article, arguments: a),
              () => data.toggleSavedArticle(a.id)),
      if (show(_SavedTab.services))
        for (final s in services)
          _SavedTile(
              s.name,
              s.isCombo ? 'Combo' : 'Dịch vụ',
              () => _open(MeRoutes.service, s),
              () => _remove(s.favoriteType, s.id)),
      if (show(_SavedTab.doctors))
        for (final d in doctors)
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
