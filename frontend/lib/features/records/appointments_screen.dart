import '../../providers/appointments_provider.dart';
import 'appointment_api_status.dart';
import '../../core/config/app_config.dart';
import '../../providers/catalog_provider.dart';
import '../../data/models/appointment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/patient_navigation.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({required this.patientId, super.key});
  final String patientId;
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool get isApi => AppConfig.current.dataSource == DataSource.api;
  @override
  void initState() {
    super.initState();
    if (isApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final catalog = context.read<CatalogProvider>();
        if (!catalog.loaded && !catalog.loading && catalog.error == null) {
          catalog.load();
        }
      });
    }
  }

  String _services(
      Appointment a, PatientDataProvider data, CatalogProvider? catalog) {
    if (!isApi) return serviceNames(data, a.serviceIds);
    if (a.serviceIds.isEmpty) return 'Chưa có thông tin dịch vụ';
    return a.serviceIds.map((id) {
      final matches = catalog!.services
          .where((s) => s.id == id && s.name.trim().isNotEmpty);
      if (matches.isNotEmpty) return matches.first.name;
      return catalog.loading || !catalog.loaded && catalog.error == null
          ? 'Đang tải dịch vụ…'
          : 'Chưa có thông tin dịch vụ';
    }).join(', ');
  }

  String _doctor(
      Appointment a, PatientDataProvider data, CatalogProvider? catalog) {
    if (!isApi) return doctorName(data, a.doctorId);
    if (a.doctorName?.trim().isNotEmpty == true) return a.doctorName!.trim();
    if (a.doctorId == null || a.doctorId!.trim().isEmpty) {
      return 'Chờ phân công';
    }
    final matches = catalog!.doctors
        .where((d) => d.id == a.doctorId && d.fullName.trim().isNotEmpty);
    if (matches.isNotEmpty) return matches.first.fullName;
    return catalog.loading || !catalog.loaded && catalog.error == null
        ? 'Đang tải bác sĩ…'
        : 'Chưa có thông tin bác sĩ';
  }

  Widget _catalogStatus(CatalogProvider catalog) {
    if (catalog.error != null) {
      return Row(children: [
        Expanded(child: Text(catalog.error!)),
        TextButton(
            onPressed: catalog.loading ? null : catalog.load,
            child: const Text('Thử lại'))
      ]);
    }
    return const Row(children: [
      SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2)),
      SizedBox(width: 8),
      Text('Đang tải danh mục…')
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final catalog = isApi ? context.watch<CatalogProvider>() : null;
    final source = isApi ? context.watch<AppointmentsProvider?>() : null;
    final patients = data.patients.where((p) => p.id == widget.patientId);
    if (patients.isEmpty) {
      return const RecordsPage(
          title: 'Lịch hẹn',
          useRecordsState: false,
          children: [
            RecordEmpty('Hồ sơ này không còn trong danh sách người thân.')
          ]);
    }
    final patient = patients.first;
    final appointments = data.appointmentsFor(widget.patientId);
    return RecordsPage(
        title: 'Lịch hẹn',
        useRecordsState: false,
        onRefresh: isApi ? () => reloadAppointments(context) : null,
        children: [
      if (isApi) const AppointmentApiStatus(),
      if (catalog != null &&
          (catalog.loading || !catalog.loaded || catalog.error != null))
        _catalogStatus(catalog),
      RecordHeading('Lịch hẹn của ${patient.fullName}'),
      if (appointments.isEmpty &&
          source?.loading != true &&
          source?.error == null)
        RecordEmpty('Chưa có lịch hẹn.',
            action: RecordButton('Đặt lịch khám', () {
              data.requestBookingFor(widget.patientId);
              PatientNavigation.selectTab(context, 1);
            })),
      for (final a in appointments)
        RecordCard(
            onTap: () =>
                RecordsRoutes.open(context, RecordsRoutes.appointment, a.id),
            children: [
              appointmentBadge(a),
              Row(children: [
                Expanded(child: RecordHeading(_services(a, data, catalog))),
                const Icon(Icons.chevron_right, size: 20)
              ]),
              Text(appointmentDateText(a),
                  style: const TextStyle(color: Color(0xFF666666))),
              const SizedBox(height: 8),
              Text(_doctor(a, data, catalog)),
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
