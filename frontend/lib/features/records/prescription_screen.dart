import 'record_catalog_names.dart';
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
    return RecordCatalogNames(builder: (context, names) {
      final data = context.watch<PatientDataProvider>();
      return RecordsPage(title: 'Đơn thuốc', children: [
        if (names.status != null) names.status!,
        RecordCard(children: [
          RecordLine(
              'Ngày kê đơn', formatVietnameseDate(prescription.issuedAt)),
          RecordLine('Bác sĩ kê đơn', names.prescriptionDoctor(prescription)),
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
          if (data.recordsAreDemoAndReadOnly)
            const Text('Đơn thuốc minh họa · Chỉ đọc',
                style: TextStyle(color: Color(0xFF666666))),
        ])
      ]);
    });
  }
}
