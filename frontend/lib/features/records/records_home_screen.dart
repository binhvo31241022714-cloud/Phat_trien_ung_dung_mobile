import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../app/patient_navigation.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient_records.dart';
import '../../providers/profile_provider.dart';
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
import '../../core/constants/app_colors.dart';

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
      final followupsPatientId = data.recordsFollowupsPatientId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = _navigator.currentState;
        navigator?.popUntil((r) => r.isFirst);
        if (visit != null) {
          navigator?.pushNamed(RecordsRoutes.visits,
              arguments: visit.patientId);
          navigator?.pushNamed(RecordsRoutes.visit, arguments: visit);
        } else if (followupsPatientId != null) {
          navigator?.pushNamed(RecordsRoutes.followups,
              arguments: followupsPatientId);
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
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = MainShellScope.maybeOf(context)?.selectedIndex == 2;
    return Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme,
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(primary: AppColors.primary, secondary: AppColors.sky),
          cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 2,
              shadowColor: const Color(0x14000675),
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide.none)),
          outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(0, 36),
                  side: const BorderSide(color: AppColors.divider),
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
    final profiles = context.watch<ProfileProvider>();
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
      if (profiles.historyFamilyLoading)
        const LinearProgressIndicator(),
      if (profiles.historyFamilyError != null)
        Column(children: [
          Text(
              'Không tải được danh sách lịch sử: ${profiles.historyFamilyError}'),
          TextButton(
              onPressed: profiles.loadHistoryFamily,
              child: const Text('Thử lại')),
        ]),
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000675),
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Người được khám',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(p.id),
              initialValue: p.id,
              isExpanded: true,
              dropdownColor: Colors.white,
              menuMaxHeight: 280,
              selectedItemBuilder: (_) => [
                for (final patient in data.recordsPatients)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${patient.fullName} (${patient.isPrimary ? "Bản thân" : patient.relationship})${patient.isArchived ? " · Đã lưu trữ · Chỉ xem lịch sử" : ""}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              icon: const Icon(
                Icons.expand_more,
                color: Colors.white,
              ),
              items: [
                for (final patient in data.recordsPatients)
                  DropdownMenuItem(
                    value: patient.id,
                    child: PatientOptionLabel(
                      '${patient.fullName} (${patient.isPrimary ? "Bản thân" : patient.relationship})${patient.isArchived ? " · Đã lưu trữ · Chỉ xem lịch sử" : ""}',
                      avatarMediaId: patient.avatarMediaId,
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id != null) {
                  if (AppConfig.current.dataSource == DataSource.api) {
                    data.selectPatient(id, reload: false);
                  }
                  data.focusAppointmentsFor(id);
                }
              },
            ),
          ],
        ),
      ),
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
                          style: const TextStyle(color: Color(0xFF666666))))
                ],
              ),
            ),
          ),
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
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFF666666), fontSize: 11))
              ])),
          const SizedBox(height: 10),
          const Align(
              alignment: Alignment.bottomRight,
              child: Icon(Icons.chevron_right, color: Colors.grey, size: 20)),
        ])
      ]);
}
