import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class PrescriptionScreen extends StatelessWidget {
  const PrescriptionScreen({required this.prescription, super.key});
  final Prescription prescription;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final visits = data.visits.where((v) => v.id == prescription.visitId);
    return RecordsPage(title: 'Đơn thuốc', children: [
      RecordCard(children: [
        RecordLine('Ngày kê đơn', formatVietnameseDate(prescription.issuedAt)),
        RecordLine('Bác sĩ kê đơn',
            visits.isEmpty ? null : visitDoctor(data, visits.first)),
        if (prescription.items.isEmpty)
          const RecordEmpty('Không có thuốc được ghi nhận trong đơn này.'),
        for (final item in prescription.items)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RecordHeading(item.name),
            RecordLine('Liều dùng', item.dosage),
            RecordLine('Tần suất', item.frequency),
            RecordLine('Thời gian sử dụng', item.duration),
            const Divider()
          ]),
        RecordSection('Ghi chú', prescription.instructions),
        const Text('Đơn thuốc minh họa · Chỉ đọc',
            style: TextStyle(color: Color(0xFF666666))),
      ])
    ]);
  }
}
