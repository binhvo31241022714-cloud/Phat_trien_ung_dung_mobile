import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/clinic_time.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';

const recordsBlue = Color(0xFF247BF3);
const missingRecordInfo = 'Chưa có thông tin';
const missingRecordTime = 'Chưa có thời gian';

class RecordsRoutes {
  static const appointments = '/appointments';
  static const appointment = '/appointment';
  static const visits = '/visits';
  static const visit = '/visit';
  static const result = '/result';
  static const prescription = '/prescription';
  static const receipt = '/receipt';
  static const treatments = '/treatments';
  static const treatment = '/treatment';
  static const photos = '/photos';
  static const followups = '/followups';
  static void open(BuildContext context, String route, Object arguments) =>
      Navigator.of(context).pushNamed(route, arguments: arguments);
}

class RecordsPage extends StatelessWidget {
  const RecordsPage(
      {required this.title,
      required this.children,
      this.useRecordsState = true,
      this.onRefresh,
      super.key});
  final String title;
  final bool useRecordsState;
  final List<Widget> children;

  /// Có giá trị thì cho kéo xuống để tải lại.
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    // Màn hồ sơ ở chế độ API mặc định kéo xuống để tải lại hồ sơ.
    final refresh = onRefresh ??
        (useRecordsState && AppConfig.current.dataSource == DataSource.api
            ? () => data.loadRecords()
            : null);
    final content = useRecordsState && data.recordsLoading
        ? const Center(child: CircularProgressIndicator())
        : useRecordsState && data.recordsError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 36),
                    const SizedBox(height: 8),
                    Text(data.recordsError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => data.loadRecords(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : refresh == null
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    children: children)
                : RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        children: children));
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      appBar: AppBar(
          title: Text(title),
          centerTitle: false,
          toolbarHeight: 48,
          backgroundColor: const Color(0xFFF1F5FB),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
              fontSize: 18, color: Colors.black, fontWeight: FontWeight.w600)),
      body: content,
    );
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard({required this.children, this.onTap, super.key});
  final List<Widget> children;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children))),
      ));
}

class RecordHeading extends StatelessWidget {
  const RecordHeading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)));
}

class RecordLine extends StatelessWidget {
  const RecordLine(this.label, this.value, {super.key});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
          '$label: ${value == null || value!.trim().isEmpty ? missingRecordInfo : value}'));
}

class RecordSection extends StatelessWidget {
  const RecordSection(this.title, this.content, {super.key});
  final String title;
  final String? content;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RecordHeading(title),
        Text(content == null || content!.trim().isEmpty
            ? missingRecordInfo
            : content!),
        const SizedBox(height: 16),
      ]);
}

class RecordButton extends StatelessWidget {
  const RecordButton(this.label, this.onPressed, {super.key});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: onPressed, child: Text(label))));
}

class RecordEmpty extends StatelessWidget {
  const RecordEmpty(this.message, {this.action, super.key});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(children: [
        const Icon(Icons.folder_open_outlined, color: recordsBlue, size: 36),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (action != null) action!,
      ]));
}

class RecordBadge extends StatelessWidget {
  const RecordBadge(this.label, {this.color = recordsBlue, super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: TextStyle(color: color, fontSize: 12)),
      ));
}

Widget appointmentBadge(Appointment a) => RecordBadge(
      a.status == AppointmentStatus.completed
          ? 'Đã hoàn thành'
          : a.status.label,
      color: switch (a.status) {
        AppointmentStatus.pending => Colors.deepOrange,
        AppointmentStatus.confirmed => recordsBlue,
        AppointmentStatus.rejected => Colors.red,
        AppointmentStatus.completed => Colors.green,
        AppointmentStatus.cancelled => Colors.grey,
        AppointmentStatus.unknown => Colors.blueGrey,
      },
    );

String doctorName(PatientDataProvider data, String? id) {
  if (id == null) return 'Chờ phân công';
  for (final d in data.doctors) {
    if (d.id == id) return d.fullName;
  }
  return missingRecordInfo;
}

String serviceNames(PatientDataProvider data, Iterable<String> ids) {
  final names = [
    for (final id in ids)
      for (final s in data.services)
        if (s.id == id) s.name
  ];
  return names.isEmpty ? missingRecordInfo : names.join(', ');
}

Appointment? visitAppointment(PatientDataProvider data, Visit visit) {
  for (final a in data.appointments) {
    if (a.id == visit.appointmentId && a.patientId == visit.patientId) return a;
  }
  return null;
}

Appointment? sessionAppointment(
    PatientDataProvider data, TreatmentSession session) {
  final id = session.appointmentId;
  if (id == null || id.isEmpty) return null;
  for (final appointment in data.appointments) {
    if (appointment.id == id) return appointment;
  }
  return null;
}

Visit? sessionVisit(PatientDataProvider data, TreatmentSession session) {
  final id = session.visitId;
  if (id != null && id.isNotEmpty) {
    for (final visit in data.visits) {
      if (visit.id == id) return visit;
    }
  }
  final appointmentId = session.appointmentId;
  if (appointmentId == null || appointmentId.isEmpty) return null;
  for (final visit in data.visits) {
    if (visit.appointmentId == appointmentId) return visit;
  }
  return null;
}

String visitServices(PatientDataProvider data, Visit v) => serviceNames(
    data,
    v.serviceIds.isNotEmpty
        ? v.serviceIds
        : visitAppointment(data, v)?.serviceIds ?? []);
String visitDoctor(PatientDataProvider data, Visit v) {
  final id = v.doctorId ?? visitAppointment(data, v)?.doctorId;
  return id == null ? missingRecordInfo : doctorName(data, id);
}

/// Ngày trong hồ sơ từ API là thời điểm UTC; hiển thị theo giờ phòng khám
/// (UTC+7). Dữ liệu mẫu là giờ địa phương nên giữ nguyên.
DateTime _recordWallTime(DateTime date) =>
    date.isUtc ? clinicWallTime(date) : date;

/// Ngày thiếu hoặc sai (model đã trả null) hiện "Chưa có thời gian" (A16).
String recordDate(DateTime? date) => date == null
    ? missingRecordTime
    : formatVietnameseDate(_recordWallTime(date));

String recordDateTime(DateTime? date) {
  if (date == null) return missingRecordTime;
  final wall = _recordWallTime(date);
  return '${formatVietnameseDate(wall)} · ${formatVietnameseTime(wall)}';
}

String appointmentDateText(Appointment a) {
  if (!a.hasValidScheduledAt) return 'Chưa có thông tin ngày giờ';
  // displayScheduledAt đã là giờ phòng khám, không đổi múi giờ lần nữa.
  final wall = a.displayScheduledAt;
  return '${formatVietnameseDate(wall)} · ${formatVietnameseTime(wall)}';
}
