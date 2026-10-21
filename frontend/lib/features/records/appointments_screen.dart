import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/patient_navigation.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({required this.patientId, super.key});
  final String patientId;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final patients = data.patients.where((p) => p.id == patientId);
    if (patients.isEmpty) {
      return const RecordsPage(title: 'Lịch hẹn', children: [
        RecordEmpty('Hồ sơ này không còn trong danh sách người thân.')
      ]);
    }
    final patient = patients.first;
    final appointments = data.appointmentsFor(patientId);
    return RecordsPage(title: 'Lịch hẹn', children: [
      RecordHeading('Lịch hẹn của ${patient.fullName}'),
      if (appointments.isEmpty)
        RecordEmpty('Chưa có lịch hẹn.',
            action: RecordButton('Đặt lịch khám', () {
              data.requestBookingFor(patientId);
              PatientNavigation.selectTab(context, 1);
            })),
      for (final a in appointments)
        RecordCard(
            onTap: () =>
                RecordsRoutes.open(context, RecordsRoutes.appointment, a.id),
            children: [
              appointmentBadge(a),
              Row(children: [
                Expanded(
                    child: RecordHeading(serviceNames(data, a.serviceIds))),
                const Icon(Icons.chevron_right, size: 20)
              ]),
              Text(recordDateTime(a.scheduledAt),
                  style: const TextStyle(color: Color(0xFF666666))),
              const SizedBox(height: 8),
              Text(doctorName(data, a.doctorId)),
              if (a.totalPrice > 0)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(formatVnd(a.totalPrice),
                        style: const TextStyle(
                            color: recordsBlue,
                            fontSize: 18,
                            fontWeight: FontWeight.w600))),
            ]),
    ]);
  }
}
