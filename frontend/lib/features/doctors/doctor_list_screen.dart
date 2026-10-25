import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/text_search.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../providers/catalog_provider.dart';
import '../shared/catalog_filters.dart';
import '../shared/catalog_navigation.dart';
import '../shared/doctor_card.dart';
import 'doctor_detail_screen.dart';

class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key});
  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  final _search = TextEditingController();
  String _query = '';

  /// '' là tất cả chuyên khoa.
  String _specialty = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.firstLoading) return const LoadingView();
    if (!catalog.loaded && catalog.error != null) {
      return ErrorState(message: catalog.error!, onRetry: catalog.load);
    }
    if (catalog.doctors.isEmpty) {
      return const EmptyState(
          title: 'Chưa có thông tin bác sĩ',
          message: 'Phòng khám chưa cập nhật đội ngũ bác sĩ.',
          icon: Icons.groups_outlined);
    }
    // Chuyên khoa lấy từ dữ liệu thật, không trùng, theo thứ tự xuất hiện.
    final specialties = {
      for (final d in catalog.doctors)
        if (d.specialty.isNotEmpty) d.specialty
    };
    final specialty = specialties.contains(_specialty) ? _specialty : '';
    final doctors = catalog.doctors
        .where((d) => specialty.isEmpty || d.specialty == specialty)
        .where((d) => matchesSearch(d.fullName, _query))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            CatalogSearchField(
                controller: _search,
                hint: 'Tìm bác sĩ theo tên',
                onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerLeft,
                child: SingleChoiceChips<String>(
                    options: {
                      '': 'Tất cả',
                      for (final s in specialties) s: s,
                    },
                    selected: specialty,
                    onSelected: (v) => setState(() => _specialty = v))),
          ])),
      Expanded(
          child: RefreshIndicator(
              onRefresh: catalog.load,
              child: doctors.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 40),
                      EmptyState(
                          title: 'Không tìm thấy bác sĩ phù hợp',
                          message: 'Thử từ khóa khác hoặc chọn "Tất cả".',
                          icon: Icons.search_off),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: doctors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final d = doctors[index];
                        return DoctorCard(
                            doctor: d,
                            onTap: () => CatalogNavigation.open(
                                context,
                                'Chi tiết bác sĩ',
                                DoctorDetailScreen(doctor: d)));
                      }))),
    ]);
  }
}
