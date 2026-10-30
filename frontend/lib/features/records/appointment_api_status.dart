import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointments_provider.dart';
import '../../data/providers/patient_data_provider.dart';

/// Tải lại lịch hẹn từ API rồi chép sang PatientDataProvider (nguồn dữ liệu
/// của các màn Hồ sơ). Dùng cho kéo để tải lại, quay lại tab Hồ sơ, bấm thông báo.
Future<void> reloadAppointments(BuildContext context) async {
  final source = context.read<AppointmentsProvider?>();
  if (source == null) return;
  final data = context.read<PatientDataProvider>();
  final session = data.sessionGeneration;
  final generation = source.sessionGeneration;
  await source.load();
  if (!data.isSessionCurrent(session) ||
      !source.isSessionCurrent(generation) ||
      source.error != null) {
    return;
  }
  data.replaceAppointments(source.appointments, generation: session);
}

/// Appointment failures must remain visible independently of clinical records.
class AppointmentApiStatus extends StatelessWidget {
  const AppointmentApiStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final source = context.watch<AppointmentsProvider?>();
    if (source == null) return const SizedBox.shrink();
    if (source.loading) return const Text('Đang tải lịch hẹn…');
    if (source.error == null) return const SizedBox.shrink();
    return Row(children: [
      Expanded(child: Text(source.error!)),
      TextButton(
          onPressed: () => reloadAppointments(context),
          child: const Text('Thử lại lịch hẹn')),
    ]);
  }
}
