import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/horizontal_card_carousel.dart';
import '../../../core/widgets/network_image_or_icon.dart';
import '../../../data/models/doctor.dart';
import '../booking_controller.dart';

class SelectDoctorStep extends StatelessWidget {
  const SelectDoctorStep({
    required this.controller,
    required this.onDetail,
    super.key,
  });

  final BookingController controller;
  final ValueChanged<Doctor> onDetail;

  Widget indicator(bool selected) {
    return Icon(
      selected ? Icons.check_circle : Icons.radio_button_unchecked,
      color: selected ? const Color(0xFF247BF3) : Colors.grey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog;

    final allDoctors =
        catalog == null ? controller.data.doctors : catalog.doctors;

    final catalogReady = catalog == null || catalog.loaded;

    // Tổng hợp các dịch vụ riêng lẻ và dịch vụ trong combo.
    final selectedCombos = controller.services
        .where(
          (service) => service.isCombo && service.id == controller.comboId,
        )
        .toList();

    final invalidCombo = controller.comboId != null &&
        (selectedCombos.isEmpty || selectedCombos.first.serviceIds.isEmpty);

    final requiredServiceIds = <String>{
      ...controller.serviceIds,
    };

    for (final combo in selectedCombos) {
      requiredServiceIds.addAll(combo.serviceIds);
    }

    // Giữ nguyên dữ liệu mock khi chạy test cũ.
    // Khi dùng CatalogProvider/API, lọc theo serviceIds thật.
    final List<Doctor> doctors;

    if (catalog == null) {
      doctors = allDoctors;
    } else if (invalidCombo) {
      doctors = [];
    } else if (requiredServiceIds.isEmpty) {
      doctors = allDoctors;
    } else {
      doctors = allDoctors.where((doctor) {
        return requiredServiceIds.every(
          (serviceId) => doctor.serviceIds.contains(serviceId),
        );
      }).toList();
    }

    final canSelect = !controller.submitting &&
        controller.created == null &&
        catalogReady &&
        doctors.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canSelect ? () => controller.chooseDoctor(null) : null,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Để hệ thống tự chọn bác sĩ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor:
                  controller.doctorChosen && controller.doctorId == null
                      ? AppColors.primary
                      : AppColors.glassPurpleStrong,
              foregroundColor:
                  controller.doctorChosen && controller.doctorId == null
                      ? Colors.white
                      : AppColors.primaryDark,
              elevation: 1,
              shadowColor: const Color(0x14000675),
              padding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (catalog != null && !catalog.loaded) ...[
          if (catalog.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Đang tải danh sách bác sĩ...'),
                ],
              ),
            )
          else if (catalog.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 36,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    catalog.error!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: catalog.loading ? null : () => catalog.load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
        ] else if (doctors.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              invalidCombo
                  ? 'Combo chưa có danh sách dịch vụ hợp lệ. Vui lòng chọn combo khác.'
                  : 'Không có bác sĩ được phân công thực hiện tất cả dịch vụ đã chọn. Vui lòng đổi dịch vụ hoặc combo.',
              textAlign: TextAlign.center,
            ),
          )
        else
          HorizontalCardCarousel(
            label: 'Bác sĩ',
            itemCount: doctors.length,
            itemWidth: 156,
            itemHeight: 196,
            navigationCenterY: 70,
            showNavigation: doctors.length > 1,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              final selected =
                  controller.doctorChosen && controller.doctorId == doctor.id;
              return GestureDetector(
                onTap: controller.submitting || controller.created != null
                    ? null
                    : () => controller.chooseDoctor(doctor.id),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selected
                          ? [
                              AppColors.glassPurpleStrong,
                              const Color(0xFFD8CCFF)
                            ]
                          : [const Color(0xDFFFFFFF), AppColors.glassPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected ? AppColors.primary : Colors.white),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x18000675),
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 92,
                            width: double.infinity,
                            color: const Color(0x66D9CCFF),
                            child: NetworkImageOrIcon(
                              url: doctor.avatarUrl,
                              icon: Icons.person_rounded,
                              iconSize: 46,
                              color: AppColors.primary,
                              width: double.infinity,
                              height: 92,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: indicator(selected),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(doctor.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(doctor.specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5, color: AppColors.textSecondary)),
                      const Spacer(),
                      Row(children: [
                        Expanded(
                          child: Text(
                            '${doctor.experienceYears} năm kinh nghiệm',
                            style: const TextStyle(
                                fontSize: 9.5, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => onDetail(doctor),
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('Chi tiết',
                              style: TextStyle(
                                  fontSize: 9.5, color: AppColors.primary)),
                        ),
                      ]),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
