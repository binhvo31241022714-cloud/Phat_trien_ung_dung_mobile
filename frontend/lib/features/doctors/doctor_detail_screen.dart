import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/doctor.dart';
import '../../data/providers/patient_data_provider.dart';

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({required this.doctor, super.key});
  final Doctor doctor;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
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
                          decoration: BoxDecoration(
                              color: const Color(0xFFDFE8F6),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.person_outline,
                              size: 36, color: Color(0xFF247BF3))),
                      const SizedBox(height: 16),
                      Text(doctor.fullName,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(doctor.specialty,
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 18)),
                      Wrap(spacing: 8, children: [
                        Chip(label: Text('☆ ${doctor.rating}')),
                        Chip(
                            label: Text(
                                '${doctor.experienceYears} năm kinh nghiệm'))
                      ]),
                      const Text('Giới thiệu',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(doctor.introduction),
                      const SizedBox(height: 16),
                      const Text('Chuyên môn',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      Chip(label: Text(doctor.specialty)),
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                              onPressed: () =>
                                  data.toggleSavedDoctor(doctor.id),
                              icon: Icon(data.savedDoctorIds.contains(doctor.id)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border),
                              label: Text(
                                  data.savedDoctorIds.contains(doctor.id)
                                      ? 'Đã lưu · Bỏ lưu'
                                      : 'Lưu để xem sau'))),
                    ]))));
  }
}
