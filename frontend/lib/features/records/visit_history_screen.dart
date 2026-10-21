import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class VisitHistoryScreen extends StatelessWidget {
  const VisitHistoryScreen({required this.patientId, super.key});
  final String patientId;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final visits = data.visitsFor(patientId);
    return RecordsPage(title: 'Lịch sử khám', children: [
      const RecordHeading('Lịch sử khám và điều trị'),
      if (visits.isEmpty) const RecordEmpty('Chưa có lịch sử khám.'),
      for (final v in visits)
        RecordCard(
            onTap: () => RecordsRoutes.open(context, RecordsRoutes.visit, v),
            children: [
              Row(children: [
                Expanded(child: RecordHeading(visitServices(data, v))),
                const Icon(Icons.chevron_right, size: 20)
              ]),
              Text(
                  '${formatVietnameseDate(v.visitedAt)} · ${visitDoctor(data, v)}',
                  style: const TextStyle(color: Color(0xFF666666))),
              const SizedBox(height: 6),
              const RecordBadge('Đã hoàn thành', color: Colors.green),
            ]),
    ]);
  }
}
