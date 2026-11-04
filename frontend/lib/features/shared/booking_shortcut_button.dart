import 'package:flutter/material.dart';

import '../../app/patient_navigation.dart';

/// Nút mở tab Đặt lịch với bác sĩ/dịch vụ/combo chọn sẵn.
/// Chỉ hiện trong MainShell và khi không ở tab Đặt lịch: chi tiết mở ngay
/// trong bước chọn của đặt lịch thì đã đang đặt lịch rồi, và chuyển sang
/// chính tab đó không làm BookingScreen đọc yêu cầu mới.
class BookingShortcutButton extends StatelessWidget {
  const BookingShortcutButton(
      {this.label = 'Đặt lịch',
      this.doctorId,
      this.serviceId,
      this.serviceIds,
      this.comboId,
      this.onPressed,
      super.key});
  final String label;
  final String? doctorId;

  /// Rút gọn cho một dịch vụ; gộp vào [serviceIds] khi mở Đặt lịch.
  final String? serviceId;
  final List<String>? serviceIds;
  final String? comboId;

  /// Việc thêm sau khi mở Đặt lịch (nếu có).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shell = MainShellScope.maybeOf(context);
    if (shell == null || shell.selectedIndex == 1) {
      return const SizedBox.shrink();
    }
    final ids = serviceIds ?? (serviceId == null ? null : [serviceId!]);
    return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed: () {
                  PatientNavigation.openBooking(context,
                      doctorId: doctorId, serviceIds: ids, comboId: comboId);
                  onPressed?.call();
                },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(label))));
  }
}
