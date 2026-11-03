import '../../core/theme/app_tokens.dart';
import '../../core/widgets/glass_selection_card.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/network_image_or_icon.dart';
import '../../data/models/doctor.dart';
import '../../providers/catalog_provider.dart';
import '../services/service_detail_screen.dart';
import '../shared/booking_shortcut_button.dart';
import '../shared/catalog_navigation.dart';
import '../shared/favorite_button.dart';

class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen(
      {required this.doctor, this.showRelated = true, super.key});
  final Doctor doctor;

  /// false khi mở từ mục "Bác sĩ thực hiện" của dịch vụ: ẩn "Dịch vụ thực
  /// hiện" để không đi vòng bác sĩ → dịch vụ → bác sĩ mãi.
  final bool showRelated;
  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    // Dịch vụ bác sĩ làm, lấy từ danh sách đã tải; mã không tìm thấy thì bỏ qua.
    final services = [
      for (final id in doctor.serviceIds)
        if (catalog.serviceById(id) case final s?) s
    ];
    return SingleChildScrollView(
        padding: AppTokens.pageInsets,
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
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(14)),
                          child: NetworkImageOrIcon(
                              url: doctor.avatarUrl,
                              alignment: Alignment.topCenter,
                              icon: Icons.person_outline,
                              iconSize: 36,
                              color: AppColors.primary,
                              width: double.infinity,
                              height: 150)),
                      const SizedBox(height: 10),
                      Text(doctor.fullName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(doctor.specialty,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 16)),
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
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Text(doctor.introduction),
                        const SizedBox(height: 10),
                      ],
                      if (showRelated && services.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text('Dịch vụ thực hiện',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        // Bấm vào dịch vụ để mở chi tiết.
                        GlassSelectionCard(
                            child: Wrap(spacing: 8, runSpacing: 4, children: [
                          for (final s in services)
                            ActionChip(
                                avatar:
                                    const Icon(Icons.chevron_right, size: 18),
                                label: Text(s.name),
                                onPressed: () => CatalogNavigation.open(
                                    context,
                                    'Chi tiết dịch vụ',
                                    ServiceDetailScreen(
                                        service: s,
                                        showRelated: false,
                                        doctorId: doctor.id))),
                        ])),
                        const SizedBox(height: 10),
                      ],
                      // Dữ liệu mock trong đặt lịch không có trên máy chủ nên
                      // không lưu được.
                      if (doctor.fromApi) ...[
                        FavoriteButton(type: 'doctor', itemId: doctor.id),
                        BookingShortcutButton(
                            label: 'Đặt lịch với bác sĩ này',
                            doctorId: doctor.id),
                      ],
                    ]))));
  }
}
