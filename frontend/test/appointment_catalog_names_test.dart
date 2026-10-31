import 'package:frontend/features/records/records_widgets.dart';
import 'support/fake_appointments_provider.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'package:frontend/features/records/appointment_detail_screen.dart';
import 'support/fake_catalog_backend.dart';

class DelayedCatalog extends CatalogProvider {
  final CatalogProvider source;
  final gate = Completer<void>();
  bool busy = false;
  DelayedCatalog(this.source);
  @override
  bool get loading => busy;
  @override
  bool get loaded => source.loaded;
  @override
  get services => source.services;
  @override
  get doctors => source.doctors;
  @override
  Future<void> load() async {
    busy = true;
    notifyListeners();
    await gate.future;
    await source.load();
    busy = false;
    notifyListeners();
  }
}

void main() {
  for (final detail in [false, true]) {
    final name = detail ? 'detail' : 'list';
    Future<void> mount(WidgetTester tester, CatalogProvider catalog,
        {String? doctorName, bool unknown = false}) async {
      final data = PatientDataProvider();
      data.replaceAppointments([
        Appointment(
            id: 'real-appointment',
            patientId: data.primaryPatient.id,
            serviceIds: unknown ? ['service-checkup'] : ['svc_01', 'svc_02'],
            doctorId: unknown ? 'doctor-lan' : 'doc_01',
            doctorName: doctorName,
            scheduledAt: DateTime(2099, 1, 1, 9),
            totalPrice: 300000,
            status: AppointmentStatus.pending,
            isDemo: false)
      ]);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: data),
            ChangeNotifierProvider<AppointmentsProvider>(
                create: (_) => FakeAppointmentsProvider()),
            ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
          ],
          child: MaterialApp(
              home: detail
                  ? const AppointmentDetailScreen(
                      appointmentId: 'real-appointment')
                  : AppointmentsScreen(patientId: data.primaryPatient.id))));
      await tester.pump();
    }

    group('API $name', () {
      testWidgets('resolves all service IDs and doctor ID with real catalog',
          (tester) async {
        await mount(tester, FakeCatalogBackend().provider());
        await tester.pumpAndSettle();
        expect(find.textContaining('Khám răng tổng quát'), findsOneWidget);
        expect(find.textContaining('Lấy cao răng'), findsOneWidget);
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(RecordBadge),
                matching: find.text('Chờ xác nhận')),
            findsOneWidget);
      });
      testWidgets('prefers appointment doctor snapshot', (tester) async {
        await mount(tester, FakeCatalogBackend().provider(),
            doctorName: 'Bác sĩ trong lịch');
        await tester.pumpAndSettle();
        expect(find.textContaining('Bác sĩ trong lịch'), findsOneWidget);
      });
      testWidgets('updates names after delayed catalog completes',
          (tester) async {
        final c = DelayedCatalog(FakeCatalogBackend().provider());
        await mount(tester, c);
        expect(find.text('Đang tải danh mục…'), findsOneWidget);
        c.gate.complete();
        await tester.pumpAndSettle();
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
      });
      testWidgets('catalog error exposes Retry and recovers', (tester) async {
        final b = FakeCatalogBackend()..failStatus = 500;
        await mount(tester, b.provider());
        await tester.pumpAndSettle();
        expect(find.text('Thử lại'), findsOneWidget);
        b.failStatus = null;
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
      });
      testWidgets('unknown IDs never resolve names from mock catalog',
          (tester) async {
        await mount(tester, FakeCatalogBackend().provider(), unknown: true);
        await tester.pumpAndSettle();
        expect(
            find.textContaining('Chưa có thông tin dịch vụ'), findsOneWidget);
        expect(find.textContaining('Chưa có thông tin bác sĩ'), findsOneWidget);
      });
      testWidgets('blank snapshot falls back to catalog', (tester) async {
        await mount(tester, FakeCatalogBackend().provider(), doctorName: '   ');
        await tester.pumpAndSettle();
        expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
      });
    }, skip: AppConfig.current.dataSource != DataSource.api);
    testWidgets('mock $name retains demo lookup', (tester) async {
      await mount(tester, FakeCatalogBackend().provider(), unknown: true);
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có thông tin dịch vụ'), findsNothing);
      expect(find.textContaining('Chưa có thông tin bác sĩ'), findsNothing);
      expect(find.text('Đang tải danh mục…'), findsNothing);
    }, skip: AppConfig.current.dataSource != DataSource.mock);
  }
}
