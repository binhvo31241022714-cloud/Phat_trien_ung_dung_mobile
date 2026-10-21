import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../booking_controller.dart';

class ConfirmBookingStep extends StatelessWidget {
  const ConfirmBookingStep({required this.controller, super.key});
  final BookingController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final patient = c.data.patients.firstWhere((p) => p.id == c.patientId);
    final doctor = c.doctorId == null
        ? 'Để hệ thống phân công'
        : c.data.doctors.firstWhere((d) => d.id == c.doctorId).fullName;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Người khám',
                    style: TextStyle(color: Color(0xFF666666))),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(patient.fullName,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600)))
              ]),
              const Divider(height: 32),
              const Text('Dịch vụ đã chọn',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              for (final s
                  in c.data.services.where((s) => c.serviceIds.contains(s.id)))
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Expanded(child: Text(s.name)),
                      const SizedBox(width: 8),
                      Text(formatVnd(s.price))
                    ])),
              const Divider(height: 24),
              Text('Bác sĩ: $doctor'),
              const SizedBox(height: 12),
              Text(
                  'Ngày khám: ${c.date == null ? "Chưa chọn" : formatVietnameseDate(c.date!)}'),
              const SizedBox(height: 12),
              Text('Giờ khám: ${c.time ?? "Chưa chọn"}'),
              const SizedBox(height: 12),
              const Text('Mã ưu đãi (nếu có)',
                  style: TextStyle(color: Color(0xFF666666))),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        initialValue: c.voucher,
                        onChanged: (v) => c.voucher = v,
                        decoration: const InputDecoration(
                            hintText: 'Ví dụ: DENTAL10'))),
                TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Mã ưu đãi chưa được hỗ trợ trong bản demo'))),
                    child: const Text('Áp dụng'))
              ]),
              const SizedBox(height: 12),
              const Text('Ghi chú cho phòng khám',
                  style: TextStyle(color: Color(0xFF666666))),
              TextFormField(
                  initialValue: c.note,
                  onChanged: (v) => c.note = v,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                      hintText: 'Ví dụ: Tôi thường bị ê buốt răng...')),
              const Divider(height: 32),
              Row(children: [
                const Expanded(child: Text('Tạm tính')),
                Text(formatVnd(c.total))
              ]),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(
                    child: Text('Tổng cộng',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Text(formatVnd(c.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF247BF3),
                        fontSize: 18))
              ]),
            ])));
  }
}
