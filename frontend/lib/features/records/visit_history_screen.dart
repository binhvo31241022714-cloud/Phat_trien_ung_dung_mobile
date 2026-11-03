import '../../core/constants/app_colors.dart';
import 'record_catalog_names.dart';
import 'record_status.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class VisitHistoryScreen extends StatelessWidget {
  const VisitHistoryScreen({required this.patientId, super.key});
  final String patientId;
  @override
  Widget build(BuildContext context) {
    return RecordCatalogNames(builder: (context, names) {
      final data = context.watch<PatientDataProvider>();
      final visits = data.visitsFor(patientId);
      return RecordsPage(
          title: 'Lịch sử khám',
          patientId: patientId,
          children: [
            if (names.status != null) names.status!,
            if (visits.isEmpty) const RecordEmpty('Chưa có hồ sơ khám.'),
            for (final v in visits)
              RecordCard(
                  onTap: () =>
                      RecordsRoutes.open(context, RecordsRoutes.visit, v),
                  children: [
                    Row(children: [
                      Expanded(child: RecordHeading(names.visitServices(v))),
                      const Icon(Icons.chevron_right, size: 20)
                    ]),
                    Text('${recordDate(v.visitedAt)} · ${names.visitDoctor(v)}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    recordStatusBadge(visitStatusLabel(v)),
                  ]),
          ]);
    });
  }
}
