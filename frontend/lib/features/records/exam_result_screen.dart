import 'record_catalog_names.dart';
import 'package:flutter/material.dart';
import '../../data/models/patient_records.dart';
import 'records_widgets.dart';

class ExamResultScreen extends StatelessWidget {
  const ExamResultScreen({required this.visit, super.key});
  final Visit visit;
  @override
  Widget build(BuildContext context) => RecordCatalogNames(
      builder: (context, names) =>
          RecordsPage(title: 'Kết quả khám', children: [
            if (names.status != null) names.status!,
            RecordCard(children: [
              RecordLine('Ngày khám', recordDate(visit.visitedAt)),
              RecordLine('Bác sĩ', names.visitDoctor(visit)),
              RecordSection('Kết luận', visit.diagnosis),
              RecordSection('Ghi chú chuyên môn', visit.professionalNote),
              RecordSection('Nội dung kết quả', visit.result),
              Text(
                  names.apiMode && !visit.isDemo
                      ? 'Thông tin hồ sơ · Chỉ đọc'
                      : 'Thông tin minh họa · Chỉ đọc',
                  style: const TextStyle(color: Color(0xFF666666))),
            ])
          ]));
}
