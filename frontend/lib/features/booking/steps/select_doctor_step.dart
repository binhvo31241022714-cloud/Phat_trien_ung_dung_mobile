import 'package:flutter/material.dart';

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
        Card(
          child: ListTile(
            onTap: canSelect ? () => controller.chooseDoctor(null) : null,
            leading: const Icon(
              Icons.shuffle,
              color: Color(0xFF247BF3),
            ),
            title: const Text(
              'Để hệ thống chọn bác sĩ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Hệ thống sẽ chọn bác sĩ phù hợp với các dịch vụ đã chọn.',
            ),
            trailing: indicator(
              controller.doctorChosen && controller.doctorId == null,
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
          for (final doctor in doctors)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: controller.submitting || controller.created != null
                      ? null
                      : () => controller.chooseDoctor(doctor.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFEAF2FF),
                              child: Icon(
                                Icons.person_outline,
                                color: Color(0xFF247BF3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doctor.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    doctor.specialty,
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  if (doctor.experienceYears > 0)
                                    Text(
                                      '${doctor.experienceYears} năm kinh nghiệm',
                                      style: const TextStyle(
                                        color: Color(0xFF666666),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            indicator(
                              controller.doctorChosen &&
                                  controller.doctorId == doctor.id,
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => onDetail(doctor),
                            child: const Text(
                              'Xem thông tin chi tiết ›',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
