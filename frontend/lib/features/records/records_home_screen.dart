import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../app/patient_navigation.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';
import '../shared/person_avatar.dart';
import 'appointment_api_status.dart';
import 'appointments_screen.dart';
import 'appointment_detail_screen.dart';
import 'visit_history_screen.dart';
import 'visit_detail_screen.dart';
import 'exam_result_screen.dart';
import 'prescription_screen.dart';
import 'payment_receipt_screen.dart';
import 'treatment_list_screen.dart';
import 'treatment_detail_screen.dart';
import 'treatment_photos_screen.dart';
import 'followup_screen.dart';

/// A navigator inside the records tab keeps MainShell's single bottom bar visible.
class RecordsHomeScreen extends StatefulWidget {
  const RecordsHomeScreen({super.key});
  @override
  State<RecordsHomeScreen> createState() => _RecordsHomeScreenState();
}

class _RecordsHomeScreenState extends State<RecordsHomeScreen> {
  final _navigator = GlobalKey<NavigatorState>();
  int _focusVersion = 0;
  bool _wasActive = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mỗi lần chuyển sang tab Hồ sơ thì tải lại lịch hẹn để thấy trạng thái mới.
    final active = MainShellScope.maybeOf(context)?.selectedIndex == 2;
    if (active &&
        !_wasActive &&
        AppConfig.current.dataSource == DataSource.api) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reloadAppointments(context);
      });
    }
    _wasActive = active;
    final data = context.watch<PatientDataProvider>();
    if (_focusVersion != data.recordsFocusVersion) {
      _focusVersion = data.recordsFocusVersion;
      final showAppointments = data.recordsShowAppointments;
      final id = data.appointmentPatientId;
      final appointmentId = data.recordsAppointmentId;
      final visit = data.recordsVisit;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = _navigator.currentState;
        navigator?.popUntil((r) => r.isFirst);
        if (visit != null) {
          navigator?.pushNamed(RecordsRoutes.visits, arguments: visit.patientId);
          navigator?.pushNamed(RecordsRoutes.visit, arguments: visit);
        } else if (appointmentId != null) {
          navigator?.pushNamed(RecordsRoutes.appointments, arguments: id);
          navigator?.pushNamed(RecordsRoutes.appointment,
              arguments: appointmentId);
        } else if (showAppointments) {
          navigator?.pushNamed(RecordsRoutes.appointments, arguments: id);
        }
      });
    }
  }

  Route<void> _route(RouteSettings settings) {
    final arg = settings.arguments;
    final page = switch (settings.name) {
      RecordsRoutes.appointments =>
        AppointmentsScreen(patientId: arg as String),
      RecordsRoutes.appointment =>
        AppointmentDetailScreen(appointmentId: arg as String),
      RecordsRoutes.visits => VisitHistoryScreen(patientId: arg as String),
      RecordsRoutes.visit => VisitDetailScreen(visit: arg as Visit),
      RecordsRoutes.result => ExamResultScreen(visit: arg as Visit),
      RecordsRoutes.prescription =>
        PrescriptionScreen(prescription: arg as Prescription),
      RecordsRoutes.receipt => PaymentReceiptScreen(receipt: arg as Receipt),
      RecordsRoutes.treatments => TreatmentListScreen(patientId: arg as String),
      RecordsRoutes.treatment =>
        TreatmentDetailScreen(plan: arg as TreatmentPlan),
      RecordsRoutes.photos => TreatmentPhotosScreen(plan: arg as TreatmentPlan),
      RecordsRoutes.followups => FollowupScreen(patientId: arg as String),
      _ => const _RecordsOverview(),
    };
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    final active = MainShellScope.maybeOf(context)?.selectedIndex == 2;
    return Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context)
              .textTheme
              .apply(bodyColor: Colors.black, displayColor: Colors.black),
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: recordsBlue),
          cardTheme: CardThemeData(
              color: const Color(0xFFF7F7F7),
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFD8D8D8)))),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 36),
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: const StadiumBorder())),
        ),
        child: NavigatorPopHandler<Object?>(
            enabled: active,
            onPopWithResult: (_) {
              if (active && (_navigator.currentState?.canPop() ?? false)) {
                _navigator.currentState!.pop();
              }
            },
            child: Navigator(key: _navigator, onGenerateRoute: _route)));
  }
}

class _RecordsOverview extends StatelessWidget {
  const _RecordsOverview();
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final p = data.recordsPatient;
    final counts = [
      data
          .appointmentsFor(p.id)
          .where((a) =>
              a.status == AppointmentStatus.pending ||
              a.status == AppointmentStatus.confirmed)
          .length,
      data.visitsFor(p.id).length,
      data.treatmentsFor(p.id).length
    ];
    final labels = ['Lịch hẹn', 'Đã khám', 'Liệu trình'];
    final routes = [
      RecordsRoutes.appointments,
      RecordsRoutes.visits,
      RecordsRoutes.treatments
    ];
    return RecordsPage(title: 'Hồ sơ nha khoa', children: [
      RecordCard(children: [
        Row(children: [
          PersonAvatar(
              key: ValueKey('records-patient-avatar-${p.id}'),
              mediaId: p.avatarMediaId,
              radius: 28,
              icon: Icons.monitor_heart_outlined,
              iconColor: recordsBlue),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.fullName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    '${p.isPrimary ? "Bản thân" : p.relationship} · Mã bệnh nhân ${p.id}',
                    style: const TextStyle(color: Color(0xFF666666))),
              ]))
        ]),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
            key: ValueKey(p.id),
            initialValue: p.id,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.black),
            isExpanded: true,
            decoration: InputDecoration(
                isDense: true,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFCCCCCC)))),
            items: [
              for (final patient in data.patients)
                DropdownMenuItem(
                    value: patient.id,
                    child: PatientOptionLabel(
                        '${patient.fullName} (${patient.isPrimary ? "Bản thân" : patient.relationship})',
                        avatarMediaId: patient.avatarMediaId))
            ],
            onChanged: (id) {
              if (id != null) {
                if (AppConfig.current.dataSource == DataSource.api) {
                  data.selectPatient(id);
                }
                data.focusAppointmentsFor(id);
              }
            }),
      ]),
      Row(children: [
        for (var i = 0; i < 3; i++)
          Expanded(
              child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 8),
                  child: RecordCard(
                      onTap: () => RecordsRoutes.open(context, routes[i], p.id),
                      children: [
                        Center(
                            child: Text('${counts[i]}',
                                key: ValueKey('records-count-$i'),
                                style: const TextStyle(
                                    color: recordsBlue,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(height: 4),
                        Center(
                            child: Text(labels[i],
                                style:
                                    const TextStyle(color: Color(0xFF666666))))
                      ])))
      ]),
      const RecordHeading('Khám và điều trị'),
      _MenuCard(
          'Lịch hẹn',
          'Lịch sắp tới, chờ xác nhận và đã hủy',
          Icons.calendar_month_outlined,
          () => RecordsRoutes.open(context, RecordsRoutes.appointments, p.id)),
      _MenuCard(
          'Lịch sử khám',
          'Kết quả khám, chẩn đoán, đơn thuốc và thanh toán',
          Icons.assignment_outlined,
          () => RecordsRoutes.open(context, RecordsRoutes.visits, p.id)),
      _MenuCard(
          'Liệu trình điều trị',
          'Tiến độ, các buổi điều trị và ảnh trước – sau',
          Icons.checklist_outlined,
          () => RecordsRoutes.open(context, RecordsRoutes.treatments, p.id)),
      _MenuCard(
          'Lịch tái khám',
          'Các lịch tái khám được đề xuất',
          Icons.event_repeat_outlined,
          () => RecordsRoutes.open(context, RecordsRoutes.followups, p.id)),
      if (data.recordsAreDemoAndReadOnly)
        const Text('DỮ LIỆU DEMO · CHỈ ĐỌC',
            style: TextStyle(color: Color(0xFF666666), fontSize: 11)),
    ]);
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard(this.title, this.subtitle, this.icon, this.onTap);
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => RecordCard(onTap: onTap, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFDFE8F6),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: recordsBlue, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF666666)))
              ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ])
      ]);
}
