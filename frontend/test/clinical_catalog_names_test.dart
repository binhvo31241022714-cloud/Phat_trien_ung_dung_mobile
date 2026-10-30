import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/features/records/visit_history_screen.dart';
import 'package:frontend/features/records/visit_detail_screen.dart';
import 'package:frontend/features/records/exam_result_screen.dart';
import 'package:frontend/features/records/prescription_screen.dart';
import 'package:frontend/features/records/treatment_detail_screen.dart';
import 'package:frontend/features/records/followup_screen.dart';
import 'support/fake_catalog_backend.dart';
import 'appointment_catalog_names_test.dart' show DelayedCatalog;

class ClinicalData extends PatientDataProvider {
  late final Visit v;
  late final Prescription p;
  late final TreatmentPlan plan;
  late final Followup f;
  ClinicalData(
      {bool snapshot = false,
      bool unknown = false,
      bool missing = false,
      bool demo = false,
      String? doctorSnapshot}) {
    final doctor = missing
        ? null
        : unknown || demo
            ? 'doctor-lan'
            : 'doc_01';
    final ids =
        missing ? <String>[] : [unknown || demo ? 'service-checkup' : 'svc_01'];
    final common = <String, dynamic>{
      'id': 'record',
      'patientId': primaryPatient.id,
      'doctorId': doctor,
      if (snapshot) 'doctorName': doctorSnapshot ?? 'Bác sĩ trong hồ sơ',
      'serviceIds': ids,
      if (snapshot) 'serviceName': 'Dịch vụ trong hồ sơ',
      'createdAt': '2026-10-01T09:00:00+07:00',
      'scheduledAt': '2099-01-01T09:00:00+07:00'
    };
    v = Visit.fromJson({
      ...common,
      'id': 'visit-real',
      'diagnosis': 'Chẩn đoán giữ nguyên',
      'result': 'Kết quả giữ nguyên',
      'note': 'Lời dặn giữ nguyên'
    });
    p = Prescription.fromJson({
      ...common,
      'visitId': v.id,
      'issuedAt': '2026-10-01T09:00:00+07:00',
      'items': [
        {'name': 'Thuốc kiểm thử', 'dosage': 'Liều giữ nguyên'}
      ],
      'instructions': 'Ghi chú đơn thuốc'
    });
    plan = TreatmentPlan.fromJson({
      ...common,
      'name': 'Liệu trình giữ nguyên',
      'description': 'Mô tả giữ nguyên',
      'totalSessions': 3
    });
    f = Followup.fromJson({...common, 'note': 'Tái khám giữ nguyên'});
  }
  @override
  List<Visit> get visits => [v];
  @override
  List<Prescription> get prescriptions => [p];
  @override
  List<TreatmentPlan> get treatmentPlans => [plan];
  @override
  List<Followup> get followups => [f];
}

Widget screen(String name, ClinicalData d) => switch (name) {
      'history' => VisitHistoryScreen(patientId: d.primaryPatient.id),
      'visit' => VisitDetailScreen(visit: d.v),
      'result' => ExamResultScreen(visit: d.v),
      'prescription' => PrescriptionScreen(prescription: d.p),
      'treatment' => TreatmentDetailScreen(plan: d.plan),
      _ => FollowupScreen(patientId: d.primaryPatient.id),
    };
Future<void> mount(
    WidgetTester t, String name, ClinicalData d, CatalogProvider c,
    {bool settle = true}) async {
  await t.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider<PatientDataProvider>.value(value: d),
    ChangeNotifierProvider<CatalogProvider>.value(value: c),
  ], child: MaterialApp(home: screen(name, d))));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }
}

void main() {
  test(
      'mapping display names preserves clinical data and rejects non-string names',
      () {
    final d = ClinicalData(snapshot: true);
    expect(d.v.doctorName, 'Bác sĩ trong hồ sơ');
    expect(d.v.serviceName, 'Dịch vụ trong hồ sơ');
    expect(d.p.doctorName, 'Bác sĩ trong hồ sơ');
    expect(d.plan.doctorName, 'Bác sĩ trong hồ sơ');
    expect(d.f.doctorName, 'Bác sĩ trong hồ sơ');
    expect(d.v.diagnosis, 'Chẩn đoán giữ nguyên');
    expect(d.v.result, 'Kết quả giữ nguyên');
    expect(d.p.items.single.dosage, 'Liều giữ nguyên');
    expect(d.plan.totalVisits, 3);
    expect(Visit.fromJson({'doctorName': 42, 'serviceName': false}).doctorName,
        isNull);
    d.dispose();
  });
  for (final name in [
    'history',
    'visit',
    'result',
    'prescription',
    'treatment',
    'followup'
  ]) {
    group('API $name', () {
      testWidgets('resolves svc_01/doc_01 from live-catalog-shaped fixture',
          (t) async {
        final d = ClinicalData();
        final c = FakeCatalogBackend().provider();
        await mount(t, name, d, c);
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
        if (['history', 'visit'].contains(name)) {
          expect(find.textContaining('Khám răng tổng quát'), findsOneWidget);
        }
        expect(t.takeException(), isNull);
      });
      testWidgets('prefers backend names over catalog names', (t) async {
        final d = ClinicalData(snapshot: true);
        final c = FakeCatalogBackend().provider();
        await mount(t, name, d, c);
        expect(find.textContaining('Bác sĩ trong hồ sơ'), findsOneWidget);
        expect(find.textContaining('BS. Nguyễn Văn API'), findsNothing);
        if (['history', 'visit'].contains(name)) {
          expect(find.textContaining('Dịch vụ trong hồ sơ'), findsOneWidget);
        }
      });
      testWidgets('rebuilds after late catalog response', (t) async {
        final d = ClinicalData();
        final c = DelayedCatalog(FakeCatalogBackend().provider());
        await mount(t, name, d, c, settle: false);
        expect(find.text('Đang tải danh mục…'), findsOneWidget);
        c.gate.complete();
        await t.pumpAndSettle();
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
      });
      testWidgets('catalog error offers Retry and recovers', (t) async {
        final d = ClinicalData();
        final backend = FakeCatalogBackend()..failStatus = 500;
        final c = backend.provider();
        await mount(t, name, d, c);
        expect(find.text('Thử lại'), findsOneWidget);
        backend.failStatus = null;
        await t.tap(find.text('Thử lại'));
        await t.pumpAndSettle();
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
      });
      testWidgets('demo IDs never resolve against mock catalogs in API mode',
          (t) async {
        final d = ClinicalData(unknown: true);
        await mount(t, name, d, FakeCatalogBackend().provider());
        expect(find.textContaining('Chưa có thông tin bác sĩ'), findsOneWidget);
        expect(find.textContaining(d.doctors.first.fullName), findsNothing);
        if (['history', 'visit'].contains(name)) {
          expect(
              find.textContaining('Chưa có thông tin dịch vụ'), findsOneWidget);
        }
      });
      testWidgets('blank payload name falls back to API catalog', (t) async {
        final d = ClinicalData(snapshot: true, doctorSnapshot: '   ');
        await mount(t, name, d, FakeCatalogBackend().provider());
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
      });
      testWidgets('missing names and IDs show neutral fallback', (t) async {
        final d = ClinicalData(missing: true);
        await mount(t, name, d, FakeCatalogBackend().provider());
        expect(find.textContaining('Chưa có thông tin bác sĩ'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }, skip: AppConfig.current.dataSource != DataSource.api);
    testWidgets('Mock $name keeps existing demo name resolution', (t) async {
      final d = ClinicalData(demo: true, snapshot: true);
      final backend = FakeCatalogBackend()..failStatus = 500;
      await mount(t, name, d, backend.provider());
      expect(find.textContaining(d.doctors.first.fullName), findsOneWidget);
      expect(find.textContaining('Bác sĩ trong hồ sơ'), findsNothing);
      expect(find.text('Thử lại'), findsNothing);
    }, skip: AppConfig.current.dataSource != DataSource.mock);
  }
}
