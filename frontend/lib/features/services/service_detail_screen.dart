import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/network_image_or_icon.dart';
import '../../data/models/dental_service.dart';
import '../../data/models/doctor.dart';
import '../../providers/catalog_provider.dart';
import '../doctors/doctor_detail_screen.dart';
import '../shared/catalog_navigation.dart';
import '../shared/favorite_button.dart';

class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen(
      {required this.service, this.showRelated = true, super.key});
  final DentalService service;

  /// false khi mở từ mục "Dịch vụ thực hiện" của bác sĩ: ẩn "Bác sĩ thực
  /// hiện" để không đi vòng dịch vụ → bác sĩ → dịch vụ mãi.
  final bool showRelated;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    // Combo: đổi id dịch vụ bên trong sang tên (lấy từ danh sách đã tải).
    final included = [
      for (final id in service.serviceIds) catalog.serviceById(id)?.name ?? id
    ];
    // Dịch vụ mock trong đặt lịch có mã khác API nên không tra được bác sĩ.
    final related = service.fromApi && showRelated;
    final doctors = related ? catalog.doctorsFor(service) : const <Doctor>[];
    // Combo luôn hiện mục này (kể cả khi chưa có bác sĩ làm đủ); dịch vụ lẻ
    // không có bác sĩ thì ẩn.
    final showDoctors = related && (service.isCombo || doctors.isNotEmpty);
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
                      if (showDoctors) ...[
                        const SizedBox(height: 16),
                        const Text('Bác sĩ thực hiện',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        if (doctors.isEmpty)
                          const Text(
                              'Phòng khám sẽ sắp xếp bác sĩ phù hợp cho combo này.',
                              style: TextStyle(color: Color(0xFF666666))),
                        for (final d in doctors)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFDFE8F6),
                                  child: ClipOval(
                                      child: NetworkImageOrIcon(
                                          url: d.avatarUrl,
                                          icon: Icons.person_outline,
                                          color: const Color(0xFF247BF3),
                                          width: 40,
                                          height: 40))),
                              title: Text(d.fullName),
                              subtitle: Text(d.specialty),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => CatalogNavigation.open(
                                  context,
                                  'Chi tiết bác sĩ',
                                  DoctorDetailScreen(
                                      doctor: d, showRelated: false))),
                      ],
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
