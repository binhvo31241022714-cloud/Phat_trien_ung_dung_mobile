import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointments_provider.dart';
Future<void> reloadAppointments(BuildContext context) => context.read<AppointmentsProvider>().load();
class AppointmentApiStatus extends StatelessWidget {
  const AppointmentApiStatus({super.key});
  @override Widget build(BuildContext context) => const Text('Dữ liệu từ máy chủ', style: TextStyle(color: Colors.blueGrey, fontSize: 12));
}
