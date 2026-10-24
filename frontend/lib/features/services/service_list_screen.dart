import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../providers/catalog_provider.dart';
import '../shared/catalog_navigation.dart';
import '../shared/service_card.dart';
import 'service_detail_screen.dart';

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    if (catalog.firstLoading) return const LoadingView();
    if (!catalog.loaded && catalog.error != null) {
      return ErrorState(message: catalog.error!, onRetry: catalog.load);
    }
    // Dịch vụ lẻ trước, combo sau (thẻ combo có nhãn "Combo").
    final services = [...catalog.services, ...catalog.combos];
    if (services.isEmpty) {
      return const EmptyState(
          title: 'Chưa có dịch vụ',
          message: 'Phòng khám chưa cập nhật dịch vụ nào.',
          icon: Icons.medical_services_outlined);
    }
    return RefreshIndicator(
        onRefresh: catalog.load,
        child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final s = services[index];
              return ServiceCard(
                  service: s,
                  onTap: () => CatalogNavigation.open(context,
                      'Chi tiết dịch vụ', ServiceDetailScreen(service: s)));
            }));
  }
}
