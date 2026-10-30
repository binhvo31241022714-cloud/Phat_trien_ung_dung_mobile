import '../../data/models/appointment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/catalog_provider.dart';
import 'records_widgets.dart' as demo;

/// Name resolution for the six clinical-record views; no medical state is cached.
class RecordCatalogNames extends StatefulWidget {
  const RecordCatalogNames({required this.builder, super.key});
  final Widget Function(BuildContext, ClinicalNames) builder;
  @override
  State<RecordCatalogNames> createState() => _RecordCatalogNamesState();
}

class _RecordCatalogNamesState extends State<RecordCatalogNames> {
  bool get apiMode => AppConfig.current.dataSource == DataSource.api;
  @override
  void initState() {
    super.initState();
    if (apiMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = context.read<CatalogProvider>();
        if (!c.loaded && !c.loading && c.error == null) c.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(
      context,
      ClinicalNames(context.watch<PatientDataProvider>(),
          apiMode ? context.watch<CatalogProvider>() : null));
}

class ClinicalNames {
  final PatientDataProvider data;
  final CatalogProvider? catalog;
  ClinicalNames(this.data, this.catalog);
  bool get apiMode => catalog != null;
  String? valid(String? value) =>
      value?.trim().isNotEmpty == true ? value!.trim() : null;
  Widget? get status {
    final c = catalog;
    if (c == null) return null;
    if (c.error != null) {
      return Row(children: [
        Expanded(child: Text(c.error!)),
        TextButton(
            onPressed: c.loading ? null : c.load, child: const Text('Thử lại'))
      ]);
    }
    if (c.loading || !c.loaded) {
      return const Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Đang tải danh mục…')
      ]);
    }
    return null;
  }

  String doctor(String? id, {String? name}) {
    if (!apiMode) return demo.doctorName(data, id);
    final snapshot = valid(name);
    if (snapshot != null) return snapshot;
    if (id == null || id.trim().isEmpty) return 'Chưa có thông tin bác sĩ';
    final matches =
        catalog!.doctors.where((d) => d.id == id && valid(d.fullName) != null);
    if (matches.isNotEmpty) return matches.first.fullName;
    return catalog!.loading || !catalog!.loaded && catalog!.error == null
        ? 'Đang tải bác sĩ…'
        : 'Chưa có thông tin bác sĩ';
  }

  String services(Iterable<String> ids,
      {String? name, List<String> names = const []}) {
    if (!apiMode) return demo.serviceNames(data, ids);
    final snapshot = valid(name);
    if (snapshot != null) return snapshot;
    if (names.isNotEmpty &&
        names.every((n) => valid(n) != null) &&
        (ids.isEmpty || names.length == ids.length)) {
      return names.map((n) => n.trim()).join(', ');
    }
    if (ids.isEmpty) return 'Chưa có thông tin dịch vụ';
    return ids.map((id) {
      final matches =
          catalog!.services.where((s) => s.id == id && valid(s.name) != null);
      if (matches.isNotEmpty) return matches.first.name;
      return catalog!.loading || !catalog!.loaded && catalog!.error == null
          ? 'Đang tải dịch vụ…'
          : 'Chưa có thông tin dịch vụ';
    }).join(', ');
  }

  Appointment? _apiAppointment(Visit visit) {
    final matches = data.appointments.where((a) =>
        !a.isDemo &&
        a.id == visit.appointmentId &&
        a.patientId == visit.patientId);
    return matches.isEmpty ? null : matches.first;
  }

  String visitServices(Visit v) {
    if (!apiMode) return demo.visitServices(data, v);
    final a = _apiAppointment(v);
    return services(
        v.serviceIds.isNotEmpty ? v.serviceIds : a?.serviceIds ?? [],
        name: v.serviceName,
        names: v.serviceNames);
  }

  String visitDoctor(Visit v) {
    if (!apiMode) return demo.visitDoctor(data, v);
    final a = _apiAppointment(v);
    final id = v.doctorId ?? a?.doctorId;
    return doctor(id,
        name:
            valid(v.doctorName) ?? (a?.doctorId == id ? a?.doctorName : null));
  }

  String prescriptionDoctor(Prescription p) {
    if (apiMode && (valid(p.doctorName) != null || valid(p.doctorId) != null)) {
      return doctor(p.doctorId, name: p.doctorName);
    }
    final visits = data.visits.where((v) => v.id == p.visitId);
    return visits.isEmpty
        ? (apiMode ? 'Chưa có thông tin bác sĩ' : demo.missingRecordInfo)
        : visitDoctor(visits.first);
  }
}
