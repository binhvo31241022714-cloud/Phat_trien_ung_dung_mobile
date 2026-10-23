import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({required this.visit, super.key});
  final Visit visit;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final a = visitAppointment(data, visit);
    return RecordsPage(title: 'Chi tiết lần khám', children: [
      RecordCard(children: [
        const RecordHeading('Chi tiết lần khám'),
        RecordLine('Ngày khám', formatVietnameseDate(visit.visitedAt)),
        RecordLine('Dịch vụ', visitServices(data, visit)),
        RecordLine('Bác sĩ', visitDoctor(data, visit)),
        const Divider(height: 28),
        RecordSection('Chẩn đoán', visit.diagnosis),
        RecordSection('Điều trị', visit.treatment),
        RecordSection('Dặn dò', visit.note),
        if (visit.result != null)
          RecordButton('Xem kết quả khám',
              () => RecordsRoutes.open(context, RecordsRoutes.result, visit)),
        for (final p in data.prescriptions.where((p) => p.visitId == visit.id))
          RecordButton('Xem đơn thuốc',
              () => RecordsRoutes.open(context, RecordsRoutes.prescription, p)),
        if (a != null)
          for (final r in data.receipts.where((r) => r.appointmentId == a.id))
            RecordButton('Xem phiếu thanh toán',
                () => RecordsRoutes.open(context, RecordsRoutes.receipt, r)),
      ]),
      const Text('DỮ LIỆU DEMO · CHỈ ĐỌC',
          style: TextStyle(color: Color(0xFF666666), fontSize: 12))
    ]);
  }
}
