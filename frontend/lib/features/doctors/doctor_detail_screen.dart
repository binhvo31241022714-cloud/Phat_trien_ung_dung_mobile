import '../../core/theme/app_tokens.dart';
import '../../core/widgets/glass_selection_card.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/doctor.dart';
import '../../providers/catalog_provider.dart';
import '../services/service_detail_screen.dart';
import '../shared/booking_shortcut_button.dart';
import '../shared/catalog_navigation.dart';
import '../shared/doctor_profile_card.dart';

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
    const heading = TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary);
    return SingleChildScrollView(
        padding: AppTokens.pageInsets,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Dữ liệu mock trong đặt lịch không có trên máy chủ nên không lưu được.
          DoctorProfileCard(
              key: ValueKey('doctor-detail-card-${doctor.id}'),
              doctor: doctor,
              vertical: true,
              showSave: doctor.fromApi),
          if (doctor.introduction.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Giới thiệu', style: heading),
            const SizedBox(height: 8),
            Text(doctor.introduction),
          ],
          if (showRelated && services.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Dịch vụ thực hiện', style: heading),
            const SizedBox(height: 8),
            // Bấm vào dịch vụ để mở chi tiết.
            GlassSelectionCard(
                child: Wrap(spacing: 8, runSpacing: 4, children: [
              for (final s in services)
                ActionChip(
                    avatar: const Icon(Icons.chevron_right, size: 18),
                    label: Text(s.name),
                    onPressed: () => CatalogNavigation.open(
                        context,
                        'Chi tiết dịch vụ',
                        ServiceDetailScreen(
                            service: s,
                            showRelated: false,
                            doctorId: doctor.id))),
            ])),
          ],
          if (doctor.fromApi) ...[
            const SizedBox(height: 16),
            BookingShortcutButton(
                label: 'Đặt lịch với bác sĩ này', doctorId: doctor.id),
          ],
        ]));
  }
}
