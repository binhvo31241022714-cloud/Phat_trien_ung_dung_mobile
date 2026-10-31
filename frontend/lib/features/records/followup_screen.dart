import 'record_catalog_names.dart';
import 'record_status.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/patient_navigation.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';
import '../../data/models/patient_records.dart';

class FollowupScreen extends StatelessWidget {
  const FollowupScreen({required this.patientId, super.key});
  final String patientId;
  @override
  Widget build(BuildContext context) {
    return RecordCatalogNames(builder: (context, names) {
      final data = context.watch<PatientDataProvider>();
      final followups = data.followupsFor(patientId);
      final generation = data.sessionGeneration;
      return RecordsPage(title: 'Lịch tái khám', children: [
        if (names.status != null) names.status!,
        if (followups.isEmpty)
          const RecordEmpty('Chưa có lịch tái khám được đề xuất.'),
        for (final f in followups)
          RecordCard(children: [
            if (followupStatusLabel(f) case final status?)
              recordStatusBadge(status),
            RecordBadge(
                f.scheduledAt == null
                    ? 'Chưa có ngày đề xuất'
                    : (f.scheduledAt?.isAfter(DateTime.now()) ?? false)
                        ? 'Sắp tới'
                        : 'Ngày đề xuất đã qua',
                color: Colors.deepOrange),
            RecordHeading(f.note.isEmpty ? 'Lịch tái khám' : f.note),
            Text(recordDateTime(f.scheduledAt)),
            const SizedBox(height: 8),
            Text(names.doctor(f.doctorId, name: f.doctorName)),
            _bookingAction(context, names, data, f, generation),
            if (!(f.scheduledAt?.isAfter(DateTime.now()) ?? false))
              const Text('Vui lòng chọn ngày khám mới trong bước đặt lịch.',
                  style: TextStyle(color: Color(0xFF666666))),
          ]),
      ]);
    });
  }

  Widget _bookingAction(BuildContext context, ClinicalNames names,
      PatientDataProvider data, Followup f, int generation) {
    final catalog = names.catalog;
    final serviceId = names.apiMode
        ? f.serviceId
        : (data.services.any((s) => s.id == 'service-checkup')
            ? 'service-checkup'
            : null);
    final ready = !names.apiMode ||
        (catalog!.loaded && !catalog.loading && catalog.error == null);
    final exists = serviceId != null &&
        (names.apiMode
            ? catalog!.services.any((s) => s.id == serviceId && s.fromApi)
            : data.services.any((s) => s.id == serviceId));
    if (!ready || !exists) {
      final message = !ready
          ? 'Cần tải danh mục thành công trước khi đặt lịch tái khám.'
          : serviceId == null
              ? 'Chưa có chỉ định dịch vụ tái khám. Vui lòng liên hệ phòng khám để xác nhận.'
              : 'Dịch vụ tái khám hiện không có trong danh mục. Vui lòng liên hệ phòng khám.';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message),
        const OutlinedButton(onPressed: null, child: Text('Đặt lịch tái khám')),
      ]);
    }
    final doctorId = names.apiMode
        ? (catalog!.doctors.any((d) =>
                d.id == f.doctorId &&
                d.fromApi &&
                d.serviceIds.contains(serviceId))
            ? f.doctorId
            : null)
        : f.doctorId;
    return RecordButton('Đặt lịch tái khám', () {
      // A callback from an obsolete route/session must not open booking.
      if (!data.isSessionCurrent(generation) ||
          !data.followupsFor(patientId).any(
              (item) => item.id == f.id && item.patientId == f.patientId)) {
        return;
      }
      if (names.apiMode &&
          (!catalog!.loaded ||
              catalog.loading ||
              catalog.error != null ||
              !catalog.services.any((s) => s.id == serviceId && s.fromApi))) {
        return;
      }
      data.requestBookingFor(patientId);
      PatientNavigation.pendingBookingRequest = BookingRequest(
        replaceSelection: true,
        serviceIds: names.apiMode ? [serviceId] : null,
        restrictToServiceIds: names.apiMode,
        doctorId: names.apiMode ? doctorId : null,
        suggestedDate:
            names.apiMode && (f.scheduledAt?.isAfter(DateTime.now()) ?? false)
                ? f.scheduledAt
                : null,
        patientId: patientId,
      );
      PatientNavigation.selectTab(context, 1);
    });
  }
}
