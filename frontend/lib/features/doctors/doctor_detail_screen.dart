import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/network_image_or_icon.dart';
import '../../data/models/doctor.dart';
import '../../providers/catalog_provider.dart';
import '../shared/favorite_button.dart';

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({required this.doctor, super.key});
  final Doctor doctor;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final services = [
      for (final id in doctor.serviceIds) catalog.serviceById(id)?.name ?? id
    ];
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          height: 150,
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                              color: const Color(0xFFDFE8F6),
                              borderRadius: BorderRadius.circular(14)),
                          child: NetworkImageOrIcon(
                              url: doctor.avatarUrl,
                              icon: Icons.person_outline,
                              iconSize: 36,
                              color: const Color(0xFF247BF3),
                              width: double.infinity,
                              height: 150)),
                      const SizedBox(height: 16),
                      Text(doctor.fullName,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(doctor.specialty,
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 18)),
                      Wrap(spacing: 8, children: [
                        if (doctor.hasRating)
                          Chip(label: Text('☆ ${doctor.rating}')),
                        Chip(
                            label: Text(
                                '${doctor.experienceYears} năm kinh nghiệm'))
                      ]),
                      if (doctor.introduction.isNotEmpty) ...[
                        const Text('Giới thiệu',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(doctor.introduction),
                        const SizedBox(height: 16),
                      ],
                      const Text('Chuyên môn',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      Wrap(spacing: 8, children: [
                        Chip(label: Text(doctor.specialty)),
                        for (final name in services) Chip(label: Text(name)),
                      ]),
                      // Dữ liệu mock trong đặt lịch không có trên máy chủ nên
                      // không lưu được.
                      if (doctor.fromApi)
                        FavoriteButton(type: 'doctor', itemId: doctor.id),
                    ]))));
  }
}
