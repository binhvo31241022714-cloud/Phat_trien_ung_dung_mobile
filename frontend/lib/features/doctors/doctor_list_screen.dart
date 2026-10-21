import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/patient_data_provider.dart';
import '../shared/catalog_navigation.dart';
import '../shared/doctor_card.dart';
import 'doctor_detail_screen.dart';

class DoctorListScreen extends StatelessWidget {
  const DoctorListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final doctors = context.watch<PatientDataProvider>().doctors;
    if (doctors.isEmpty) {
      return const Center(child: Text('Chưa có thông tin bác sĩ.'));
    }
    return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: doctors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final d = doctors[index];
          return DoctorCard(
              doctor: d,
              onTap: () => CatalogNavigation.open(
                  context, 'Chi tiết bác sĩ', DoctorDetailScreen(doctor: d)));
        });
  }
}
