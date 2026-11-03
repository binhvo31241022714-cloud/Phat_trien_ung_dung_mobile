import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../providers/catalog_provider.dart';
import '../../data/mock_data.dart';
class ClinicalNames {
  final CatalogProvider? catalog;
  final bool apiMode;
  final Widget? status;
  const ClinicalNames({this.catalog, required this.apiMode, this.status});
  String doctor(String? id, {String? name}) {
    if (name != null && name.isNotEmpty) return name;
    final found = catalog?.doctors.where((d) => d.id == id).firstOrNull;
    return found?.fullName ?? 'Chưa xác định';
  }
  String visitDoctor(dynamic v) => doctor(v.doctorId, name: v.doctorName);
  String prescriptionDoctor(dynamic p) => 'Chưa xác định';
  String visitServices(dynamic v) {
    final ids = (v.serviceIds as Iterable<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    if (apiMode) return 'Chưa có thông tin';
    final names = [
      for (final id in ids)
        for (final service in MockData.services)
          if (service.id == id) service.name,
    ];
    return names.isEmpty ? 'Chưa có thông tin' : names.join(', ');
  }
}
class RecordCatalogNames extends StatelessWidget {
  final Widget Function(BuildContext, ClinicalNames) builder;
  const RecordCatalogNames({required this.builder, super.key});
  @override Widget build(BuildContext context) {
    final api = AppConfig.current.dataSource == DataSource.api;
    final catalog = api ? context.watch<CatalogProvider>() : null;
    return builder(context, ClinicalNames(catalog: catalog, apiMode: api,
      status: api && catalog?.error != null ? Text(catalog!.error!) : null));
  }
}
