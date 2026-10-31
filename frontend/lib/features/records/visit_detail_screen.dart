import 'record_catalog_names.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/network/api_client.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({required this.visit, super.key});
  final Visit visit;
  @override
  Widget build(BuildContext context) {
    return RecordCatalogNames(builder: (context, names) {
      final data = context.watch<PatientDataProvider>();
      final activeTreatments = data.treatmentPlans
          .where((plan) =>
              plan.patientId == visit.patientId &&
              plan.completedVisits < plan.totalVisits)
          .toList();
      return RecordsPage(title: 'Chi tiết lần khám', children: [
        if (names.status != null) names.status!,
        RecordCard(children: [
          const RecordHeading('Chi tiết lần khám'),
          RecordLine('Ngày khám', formatVietnameseDate(visit.visitedAt)),
          RecordLine('Dịch vụ', names.visitServices(visit)),
          RecordLine('Bác sĩ', names.visitDoctor(visit)),
          const Divider(height: 28),
          RecordSection('Chẩn đoán', visit.diagnosis),
          RecordSection('Điều trị', visit.treatment),
          RecordSection('Dặn dò', visit.note),
          if (visit.result != null)
            RecordButton('Xem kết quả khám',
                () => RecordsRoutes.open(context, RecordsRoutes.result, visit)),
          for (final p
              in data.prescriptions.where((p) => p.visitId == visit.id))
            RecordButton(
                'Xem đơn thuốc',
                () =>
                    RecordsRoutes.open(context, RecordsRoutes.prescription, p)),
          if (!data.recordsAreDemoAndReadOnly && activeTreatments.isNotEmpty)
            RecordButton(
                'Thêm vào liệu trình khám',
                () => _chooseTreatment(
                      context,
                      data,
                      activeTreatments,
                    )),
          for (final r in data.receipts.where((r) => r.belongsToVisit(visit)))
            RecordButton('Xem phiếu thanh toán',
                () => RecordsRoutes.open(context, RecordsRoutes.receipt, r)),
        ]),
        if (data.recordsAreDemoAndReadOnly)
          const Text('DỮ LIỆU DEMO · CHỈ ĐỌC',
              style: TextStyle(color: Color(0xFF666666), fontSize: 12))
      ]);
    });
  }

  Future<void> _chooseTreatment(
    BuildContext context,
    PatientDataProvider data,
    List<TreatmentPlan> treatments,
  ) async {
    final selected = await showDialog<TreatmentPlan>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Chọn liệu trình đang khám'),
        children: [
          for (final treatment in treatments)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(treatment),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    border: Border.all(
                      color: const Color(0xFF9FC3FF),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.medical_services_outlined,
                          color: recordsBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          treatment.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: recordsBlue),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (selected == null || !context.mounted) return;

    final availableSessions = selected.sessions
        .where((session) =>
            session.id.isNotEmpty &&
            session.visitId == null &&
            !session.completed)
        .toList();
    final chosenSession = await showDialog<TreatmentSession>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Chọn buổi trong "${selected.title}"'),
        children: [
          if (availableSessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Liệu trình không còn buổi trống.'),
            ),
          for (final session in availableSessions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(session),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FD),
                    border: Border.all(
                      color: const Color(0xFFC9D8EE),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note_outlined, color: recordsBlue),
                      const SizedBox(width: 10),
                      Expanded(child: Text(session.title)),
                      const Icon(Icons.chevron_right, color: recordsBlue),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (chosenSession == null || !context.mounted) return;

    try {
      await data.linkVisitToTreatment(
        treatmentId: selected.id,
        visitId: visit.id,
        sessionId: chosenSession.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm lần khám vào liệu trình.')),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}
