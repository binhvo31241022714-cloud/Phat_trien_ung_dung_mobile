import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class ExamResultScreen extends StatelessWidget {
  const ExamResultScreen({required this.visit, super.key});
  final Visit visit;
  @override
  Widget build(BuildContext context) =>
      RecordsPage(title: 'Kết quả khám', children: [
        RecordCard(children: [
          RecordLine('Ngày khám', formatVietnameseDate(visit.visitedAt)),
          RecordLine('Bác sĩ',
              visitDoctor(context.watch<PatientDataProvider>(), visit)),
          RecordSection('Kết luận', visit.diagnosis),
          RecordSection('Ghi chú chuyên môn', visit.professionalNote),
          RecordSection('Nội dung kết quả', visit.result),
          const Text('Thông tin minh họa · Chỉ đọc',
              style: TextStyle(color: Color(0xFF666666))),
        ])
      ]);
}
