import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/dental_service.dart';
import '../../data/providers/patient_data_provider.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({required this.service, super.key});
  final DentalService service;
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
                          child: Icon(service.icon,
                              size: 36, color: const Color(0xFF247BF3))),
                      const SizedBox(height: 16),
                      Text(service.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(formatVnd(service.price),
                          style: const TextStyle(
                              fontSize: 20, color: Color(0xFF247BF3))),
                      Wrap(spacing: 8, children: [
                        Chip(
                            label: Text(
                                service.isCombo ? 'Combo' : service.category)),
                        Chip(label: Text('${service.durationMinutes} phút')),
                        const Chip(label: Text('Tư vấn tại phòng khám'))
                      ]),
                      const Text('Mô tả dịch vụ',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(service.description),
                      const SizedBox(height: 16),
                      const Text(
                          'Giá và thời gian chỉ là dữ liệu minh họa; bác sĩ sẽ xác nhận phương án thực tế.',
                          style: TextStyle(color: Color(0xFF666666))),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                              onPressed: () =>
                                  data.toggleSavedService(service.id),
                              icon: Icon(
                                  data.savedServiceIds.contains(service.id)
                                      ? Icons.bookmark
                                      : Icons.bookmark_border),
                              label: Text(
                                  data.savedServiceIds.contains(service.id)
                                      ? 'Đã lưu · Bỏ lưu'
                                      : 'Lưu để xem sau'))),
                    ]))));
  }
}
