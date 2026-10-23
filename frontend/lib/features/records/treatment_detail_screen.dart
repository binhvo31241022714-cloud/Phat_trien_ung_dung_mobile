import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class TreatmentDetailScreen extends StatelessWidget {
  const TreatmentDetailScreen({required this.plan, super.key});
  final TreatmentPlan plan;
  @override
  Widget build(BuildContext context) => RecordsPage(
      title: 'Chi tiết liệu trình', children: [TreatmentPlanCard(plan: plan)]);
}

class TreatmentPlanCard extends StatelessWidget {
  const TreatmentPlanCard({required this.plan, super.key});
  final TreatmentPlan plan;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    return RecordCard(children: [
      Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
        RecordHeading(plan.title),
        RecordBadge(
            plan.totalVisits > 0 && plan.completedVisits >= plan.totalVisits
                ? 'Đã hoàn thành'
                : 'Đang điều trị')
      ]),
      Text(
          '${plan.doctorId == null ? missingRecordInfo : doctorName(data, plan.doctorId)} · ${plan.completedVisits}/${plan.totalVisits} buổi'),
      const SizedBox(height: 12),
      LinearProgressIndicator(
          value: plan.progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: recordsBlue,
          backgroundColor: const Color(0xFFDCE6F5)),
      const SizedBox(height: 12),
      Text(plan.description),
      const SizedBox(height: 12),
      if (plan.sessions.isEmpty)
        const Text('Chưa có thông tin các buổi điều trị.'),
      for (final session in plan.sessions)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Icon(
                  session.completed ? Icons.check_circle_outline : Icons.circle,
                  color: session.completed ? Colors.green : Colors.grey,
                  size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      '${session.title} · ${session.completed ? "Hoàn thành" : "Chưa hoàn thành"}')),
            ])),
      RecordButton('Xem ảnh trước – sau',
          () => RecordsRoutes.open(context, RecordsRoutes.photos, plan)),
    ]);
  }
}
