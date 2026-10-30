import 'booking_doctor_name.dart';

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import 'booking_controller.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    required this.controller,
    required this.onRecords,
    required this.onHome,
    super.key,
  });

  final BookingController controller;
  final VoidCallback onRecords;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final appointment = controller.created;

    // Màn hình thành công chỉ hiển thị sau khi đã có lịch được tạo.
    if (appointment == null) {
      return const Center(
        child: Text('Chưa có thông tin lịch hẹn.'),
      );
    }

    final data = controller.data;
    final profile = controller.profile;

    // Tìm người khám trong dữ liệu mẫu trước.
    // Dùng where().toList() để không phát sinh Bad state: No element.
    final localPatients = data.patients
        .where((patient) => patient.id == appointment.patientId)
        .toList();

    // Tìm người khám trong hồ sơ tài khoản thật.
    final currentProfile = profile?.profile;
    final isAccountHolder = currentProfile?.id == appointment.patientId;

    // Tìm người khám trong danh sách người thân từ API.
    final familyMembers = profile?.family
            .where((member) => member.id == appointment.patientId)
            .toList() ??
        [];

    final String patientName;

    if (localPatients.isNotEmpty) {
      patientName = localPatients.first.fullName;
    } else if (isAccountHolder && currentProfile != null) {
      patientName = currentProfile.fullName.trim().isNotEmpty
          ? currentProfile.fullName
          : currentProfile.email;
    } else if (familyMembers.isNotEmpty) {
      patientName = familyMembers.first.fullName;
    } else {
      // Không tìm thấy hồ sơ thì vẫn hiển thị màn hình,
      // thay vì làm toàn bộ giao diện chuyển sang màn hình đỏ.
      patientName = 'Người khám';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Đặt lịch thành công!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thông tin đặt lịch đã được ghi nhận. '
                'Vui lòng chờ phòng khám xác nhận.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 12),
              const Chip(
                label: Text(
                  'Chờ xác nhận',
                  style: TextStyle(color: Colors.deepOrange),
                ),
                backgroundColor: Color(0xFFFFE2D4),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Người khám: $patientName'),
                      const SizedBox(height: 8),
                      Text(
                        'Ngày giờ: ${appointment.hasValidScheduledAt ? formatVietnameseDateTime(appointment.scheduledAt) : "Chưa có thông tin ngày giờ"}',
                      ),
                      const SizedBox(height: 8),
                      BookingDoctorName(
                          controller: controller,
                          doctorId: appointment.doctorId,
                          payloadName: appointment.doctorName),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Tổng tiền'),
                          ),
                          Text(
                            formatVnd(appointment.totalPrice),
                            style: const TextStyle(
                              color: Color(0xFF247BF3),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (appointment.voucherCode != null &&
                          appointment.voucherCode!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Mã ưu đãi: ${appointment.voucherCode}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRecords,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  child: const Text('Xem hồ sơ'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onHome,
                  child: const Text('Về trang chủ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
