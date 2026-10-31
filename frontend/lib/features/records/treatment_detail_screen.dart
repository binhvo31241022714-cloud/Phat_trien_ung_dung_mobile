import 'record_catalog_names.dart';
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
    return RecordCatalogNames(builder: (context, names) {
      return RecordCard(children: [
        if (names.status != null) names.status!,
        Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, children: [
          RecordHeading(plan.title),
          RecordBadge(names.apiMode
              ? 'Trạng thái chưa cập nhật'
              : plan.totalVisits > 0 && plan.completedVisits >= plan.totalVisits
                  ? 'Đã hoàn thành'
                  : 'Đang điều trị')
        ]),
        Text(
            '${!names.apiMode && plan.doctorId == null ? missingRecordInfo : names.doctor(plan.doctorId, name: plan.doctorName)} · ${plan.completedVisits}/${plan.totalVisits} buổi'),
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
          _TreatmentSessionCard(session: session),
        RecordButton('Xem ảnh trước – sau',
            () => RecordsRoutes.open(context, RecordsRoutes.photos, plan)),
      ]);
    });
  }
}

class _TreatmentSessionCard extends StatelessWidget {
  const _TreatmentSessionCard({required this.session});
  final TreatmentSession session;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final appointment = sessionAppointment(data, session);
    final visit = sessionVisit(data, session);
    final prescriptions = visit == null
        ? const <Prescription>[]
        : data.prescriptions.where((item) => item.visitId == visit.id).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                session.completed
                    ? Icons.check_circle_outline
                    : Icons.circle_outlined,
                color: session.completed ? Colors.green : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${session.title} · ${session.completed ? "Hoàn thành" : "Chưa hoàn thành"}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            if (session.scheduledAt != null) ...[
              const SizedBox(height: 4),
              Text(recordDateTime(session.scheduledAt!)),
            ],
            if (session.notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(session.notes),
            ],
            const SizedBox(height: 8),
            if (appointment != null)
              _SessionAction(
                label: 'Xem lịch hẹn',
                onPressed: () => RecordsRoutes.open(
                    context, RecordsRoutes.appointment, appointment.id),
              )
            else
              const Text('Chưa liên kết lịch hẹn.',
                  style: TextStyle(color: Colors.grey)),
            if (visit != null) ...[
              _SessionAction(
                label: 'Xem kết quả khám',
                onPressed: () =>
                    RecordsRoutes.open(context, RecordsRoutes.visit, visit),
              ),
              if (prescriptions.isNotEmpty)
                _SessionAction(
                  label: 'Xem đơn thuốc',
                  onPressed: () => RecordsRoutes.open(
                      context, RecordsRoutes.prescription, prescriptions.first),
                )
              else
                const Text('Chưa có đơn thuốc cho buổi này.',
                    style: TextStyle(color: Colors.grey)),
            ] else
              const Text('Chưa có hồ sơ khám cho buổi này.',
                  style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _SessionAction extends StatelessWidget {
  const _SessionAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(label),
        ),
      );
}
