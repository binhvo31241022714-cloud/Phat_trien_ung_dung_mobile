import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../providers/catalog_provider.dart';
import '../shared/catalog_navigation.dart';
import '../shared/doctor_card.dart';
import 'doctor_detail_screen.dart';

class DoctorListScreen extends StatelessWidget {
  const DoctorListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.firstLoading) return const LoadingView();
    if (!catalog.loaded && catalog.error != null) {
      return ErrorState(message: catalog.error!, onRetry: catalog.load);
    }
    final doctors = catalog.doctors;
    if (doctors.isEmpty) {
      return const EmptyState(
          title: 'Chưa có thông tin bác sĩ',
          message: 'Phòng khám chưa cập nhật đội ngũ bác sĩ.',
          icon: Icons.groups_outlined);
    }
    return RefreshIndicator(
        onRefresh: catalog.load,
        child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final d = doctors[index];
              return DoctorCard(
                  doctor: d,
                  onTap: () => CatalogNavigation.open(context,
                      'Chi tiết bác sĩ', DoctorDetailScreen(doctor: d)));
            }));
  }
}
