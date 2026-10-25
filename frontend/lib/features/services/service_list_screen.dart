import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/text_search.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/dental_service.dart';
import '../../providers/catalog_provider.dart';
import '../shared/catalog_filters.dart';
import '../shared/catalog_navigation.dart';
import '../shared/service_card.dart';
import 'service_detail_screen.dart';

enum _Kind { all, service, combo }

enum _Sort { normal, priceAsc, priceDesc }

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});
  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Kind _kind = _Kind.all;
  _Sort _sort = _Sort.normal;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Lọc theo tên (không phân biệt dấu), loại, rồi sắp xếp theo giá.
  List<DentalService> _visible(CatalogProvider catalog) {
    final list = [
      if (_kind != _Kind.combo) ...catalog.services,
      if (_kind != _Kind.service) ...catalog.combos,
    ].where((s) => matchesSearch(s.name, _query)).toList();
    if (_sort == _Sort.priceAsc) list.sort((a, b) => a.price - b.price);
    if (_sort == _Sort.priceDesc) list.sort((a, b) => b.price - a.price);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.firstLoading) return const LoadingView();
    if (!catalog.loaded && catalog.error != null) {
      return ErrorState(message: catalog.error!, onRetry: catalog.load);
    }
    if (catalog.services.isEmpty && catalog.combos.isEmpty) {
      return const EmptyState(
          title: 'Chưa có dịch vụ',
          message: 'Phòng khám chưa cập nhật dịch vụ nào.',
          icon: Icons.medical_services_outlined);
    }
    final services = _visible(catalog);
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            // Hàng 1: ô tìm kiếm + nút sắp xếp. Hàng 2: chip lọc đủ chỗ.
            Row(children: [
              Expanded(
                  child: CatalogSearchField(
                      controller: _search,
                      hint: 'Tìm dịch vụ theo tên',
                      onChanged: (v) => setState(() => _query = v))),
              const SizedBox(width: 4),
              PopupMenuButton<_Sort>(
                  tooltip: 'Sắp xếp',
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: _Sort.normal, child: Text('Mặc định')),
                        PopupMenuItem(
                            value: _Sort.priceAsc, child: Text('Giá tăng dần')),
                        PopupMenuItem(
                            value: _Sort.priceDesc,
                            child: Text('Giá giảm dần')),
                      ],
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.sort, size: 20),
                        Text(
                            switch (_sort) {
                              _Sort.normal => 'Mặc định',
                              _Sort.priceAsc => 'Giá tăng',
                              _Sort.priceDesc => 'Giá giảm',
                            },
                            style: const TextStyle(fontSize: 11)),
                      ]))),
            ]),
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerLeft,
                child: SingleChoiceChips<_Kind>(
                    options: const {
                      _Kind.all: 'Tất cả',
                      _Kind.service: 'Dịch vụ',
                      _Kind.combo: 'Combo',
                    },
                    selected: _kind,
                    onSelected: (v) => setState(() => _kind = v))),
          ])),
      Expanded(
          child: RefreshIndicator(
              onRefresh: catalog.load,
              child: services.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 40),
                      EmptyState(
                          title: 'Không tìm thấy dịch vụ phù hợp',
                          message: 'Thử từ khóa khác hoặc chọn "Tất cả".',
                          icon: Icons.search_off),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: services.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final s = services[index];
                        return ServiceCard(
                            service: s,
                            onTap: () => CatalogNavigation.open(
                                context,
                                'Chi tiết dịch vụ',
                                ServiceDetailScreen(service: s)));
                      }))),
    ]);
  }
}
