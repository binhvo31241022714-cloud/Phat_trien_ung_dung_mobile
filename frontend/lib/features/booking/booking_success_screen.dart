import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import 'booking_controller.dart';

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen(
      {required this.controller,
      required this.onRecords,
      required this.onHome,
      super.key});
  final BookingController controller;
  final VoidCallback onRecords;
  final VoidCallback onHome;
  @override
  Widget build(BuildContext context) {
    final a = controller.created!;
    final data = controller.data;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 30),
                  const SizedBox(height: 16),
                  const Text('Đặt lịch thành công!',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Yêu cầu đặt lịch đã được tạo trong bản demo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF666666))),
                  const Chip(
                      label: Text('Chờ xác nhận',
                          style: TextStyle(color: Colors.deepOrange)),
                      backgroundColor: Color(0xFFFFE2D4)),
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Người khám: ${data.patients.firstWhere((p) => p.id == a.patientId).fullName}'),
                                const SizedBox(height: 8),
                                Text(
                                    'Ngày giờ: ${formatVietnameseDateTime(a.scheduledAt)}'),
                                const SizedBox(height: 8),
                                Text(
                                    'Bác sĩ: ${a.doctorId == null ? "Chờ phân công" : data.doctors.firstWhere((d) => d.id == a.doctorId).fullName}'),
                                const SizedBox(height: 8),
                                Row(children: [
                                  const Expanded(child: Text('Tổng tiền')),
                                  Text(formatVnd(a.totalPrice),
                                      style: const TextStyle(
                                          color: Color(0xFF247BF3),
                                          fontSize: 18))
                                ]),
                              ]))),
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: onRecords,
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.black),
                          child: const Text('Xem hồ sơ'))),
                  const SizedBox(height: 8),
                  SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                          onPressed: onHome,
                          child: const Text('Về trang chủ'))),
                ]))));
  }
}
