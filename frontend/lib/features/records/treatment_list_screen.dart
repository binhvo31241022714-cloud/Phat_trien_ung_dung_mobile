import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/patient_data_provider.dart';
import 'record_status.dart';
import 'records_widgets.dart';
import 'treatment_detail_screen.dart';

class TreatmentListScreen extends StatelessWidget {
  const TreatmentListScreen({required this.patientId, super.key});
  final String patientId;
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PatientDataProvider>().treatmentsFor(patientId);
    return RecordsPage(title: 'Liệu trình điều trị', children: [
      if (plans.isEmpty) const RecordEmpty('Chưa có liệu trình điều trị.'),
      if (plans.length == 1) TreatmentPlanCard(plan: plans.single),
      if (plans.length > 1)
        for (final p in plans)
          RecordCard(
              onTap: () =>
                  RecordsRoutes.open(context, RecordsRoutes.treatment, p),
              children: [
                Row(children: [
                  Expanded(child: RecordHeading(p.title)),
                  const Icon(Icons.chevron_right)
                ]),
                recordStatusBadge(treatmentStatusLabel(p)),
                Text('${p.completedVisits}/${p.totalVisits} buổi'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: p.progress),
              ]),
    ]);
  }
}
