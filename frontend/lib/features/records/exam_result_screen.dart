import 'record_catalog_names.dart';
import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
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
              RecordLine('Ngày khám', formatVietnameseDate(visit.visitedAt)),
              RecordLine('Bác sĩ', names.visitDoctor(visit)),
              RecordSection('Kết luận', visit.diagnosis),
              RecordSection('Ghi chú chuyên môn', visit.professionalNote),
              RecordSection('Nội dung kết quả', visit.result),
              const Text('Thông tin minh họa · Chỉ đọc',
                  style: TextStyle(color: Color(0xFF666666))),
            ])
          ]));
}
