import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/patient_data_provider.dart';
import '../shared/catalog_navigation.dart';
import '../shared/service_card.dart';
import 'service_detail_screen.dart';

class ServiceListScreen extends StatelessWidget {
  const ServiceListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final services = context.watch<PatientDataProvider>().services;
    if (services.isEmpty) return const Center(child: Text('Chưa có dịch vụ.'));
    return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final s = services[index];
          return ServiceCard(
              service: s,
              onTap: () => CatalogNavigation.open(context, 'Chi tiết dịch vụ',
                  ServiceDetailScreen(service: s)));
        });
  }
}
