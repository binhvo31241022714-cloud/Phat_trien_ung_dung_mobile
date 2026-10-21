import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class AppointmentDetailScreen extends StatelessWidget {
  const AppointmentDetailScreen({required this.appointmentId, super.key});
  final String appointmentId;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final a = data.appointments.firstWhere((a) => a.id == appointmentId);
    return RecordsPage(title: 'Chi tiết lịch hẹn', children: [
      RecordCard(children: [
        appointmentBadge(a),
        RecordLine('Mã lịch hẹn', a.id),
        RecordLine('Bệnh nhân',
            data.patients.firstWhere((p) => p.id == a.patientId).fullName),
        RecordLine('Dịch vụ', serviceNames(data, a.serviceIds)),
        RecordLine('Bác sĩ', doctorName(data, a.doctorId)),
        RecordLine('Ngày giờ', recordDateTime(a.scheduledAt)),
        RecordLine('Ghi chú', a.note),
        RecordLine(
            'Tổng tiền', a.totalPrice > 0 ? formatVnd(a.totalPrice) : null),
        const Text(
            'Lịch hẹn demo. Thao tác hủy chỉ cập nhật dữ liệu trong ứng dụng.',
            style: TextStyle(color: Color(0xFF666666))),
        if (data.canCancelAppointment(a))
          RecordButton('Hủy lịch', () async {
            final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                      title: const Text('Hủy lịch hẹn?'),
                      content: const Text(
                          'Lịch hẹn sẽ được giữ lại với trạng thái Đã hủy trong bản demo.'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Giữ lịch')),
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Xác nhận hủy'))
                      ],
                    ));
            if (confirmed == true && context.mounted) {
              final cancelled = data.cancelAppointment(a.id);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(cancelled
                      ? 'Đã hủy lịch hẹn demo.'
                      : 'Lịch hẹn không còn đủ điều kiện hủy.')));
            }
          }),
      ])
    ]);
  }
}
