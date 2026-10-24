import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/network_image_or_icon.dart';
import '../../data/models/dental_service.dart';
import '../../providers/catalog_provider.dart';
import '../shared/favorite_button.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({required this.service, super.key});
  final DentalService service;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    // Combo: đổi id dịch vụ bên trong sang tên (lấy từ danh sách đã tải).
    final included = [
      for (final id in service.serviceIds) catalog.serviceById(id)?.name ?? id
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
                              url: service.imageUrl,
                              icon: service.icon,
                              iconSize: 36,
                              color: const Color(0xFF247BF3),
                              width: double.infinity,
                              height: 150)),
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
                        if (service.durationMinutes > 0)
                          Chip(label: Text('${service.durationMinutes} phút')),
                        const Chip(label: Text('Tư vấn tại phòng khám'))
                      ]),
                      if (included.isNotEmpty) ...[
                        const Text('Gồm các dịch vụ',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        for (final name in included)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $name')),
                        const SizedBox(height: 12),
                      ],
                      const Text('Mô tả dịch vụ',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text(service.description.isEmpty
                          ? 'Chưa có mô tả.'
                          : service.description),
                      const SizedBox(height: 16),
                      Text(
                          service.fromApi
                              ? 'Bác sĩ sẽ xác nhận phương án và chi phí thực tế khi thăm khám.'
                              : 'Giá và thời gian chỉ là dữ liệu minh họa; bác sĩ sẽ xác nhận phương án thực tế.',
                          style: const TextStyle(color: Color(0xFF666666))),
                      const SizedBox(height: 12),
                      // Dữ liệu mock trong đặt lịch không có trên máy chủ nên
                      // không lưu được.
                      if (service.fromApi)
                        FavoriteButton(
                            type: service.favoriteType, itemId: service.id),
                    ]))));
  }
}
