import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/patient_navigation.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/features/records/followup_screen.dart';
import 'support/fake_catalog_backend.dart';
import 'appointment_catalog_names_test.dart' show DelayedCatalog;

// Suppress networking while checking the booking handoff state.
class HandoffController extends BookingController {
  HandoffController(super.data);
  @override
  Future<void> refreshQuote() async {}
  @override
  Future<void> loadAvailability() async {}
}

class FollowupData extends PatientDataProvider {
  late List<Followup> rows;
  FollowupData(
      {String? serviceId, String doctor = 'doc_01', bool past = false}) {
    rows = [
      Followup.fromJson({
        'id': 'real',
        'patientId': primaryPatient.id,
        'serviceId': serviceId,
        'doctorId': doctor,
        'appointmentId': 'previous',
        'visitId': 'previous',
        'scheduledAt': past ? '2020-01-01T09:00:00' : '2099-01-02T09:00:00'
      })
    ];
  }
  @override
  List<Followup> get followups => rows;
  @override
  void clearPrivateState() {
    rows = [];
    super.clearPrivateState();
  }
}

Future<void> mount(WidgetTester t, FollowupData d, CatalogProvider c,
    {bool settle = true}) async {
  final id = d.primaryPatient.id;
  await t.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider<PatientDataProvider>.value(value: d),
    ChangeNotifierProvider<CatalogProvider>.value(value: c),
  ], child: MaterialApp(home: FollowupScreen(patientId: id))));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }
}

OutlinedButton button(WidgetTester t) => t.widget<OutlinedButton>(
    find.widgetWithText(OutlinedButton, 'Đặt lịch tái khám'));
void main() {
  final api = AppConfig.current.dataSource == DataSource.api;
  setUp(() => PatientNavigation.pendingBookingRequest = null);
  tearDown(() => PatientNavigation.pendingBookingRequest = null);
  test('service mapping strictly accepts explicit nonblank string', () {
    expect(Followup.fromJson({'serviceId': ' svc_02 '}).serviceId, 'svc_02');
    for (final v in [
      null,
      '',
      '  ',
      42,
      ['svc_01']
    ]) {
      expect(Followup.fromJson({'serviceId': v}).serviceId, isNull);
    }
  });
  test('followup handoff replaces old selection and retains suggested day', () {
    final data = PatientDataProvider();
    final c = HandoffController(data);
    c.serviceIds.add('old-service');
    c.comboId = 'old-combo';
    c.applyInitialValues(
        replaceSelection: true,
        serviceIds: ['svc_02'],
        doctorId: 'doc_01',
        suggestedDate: DateTime(2099, 1, 2, 9),
        restrictToServiceIds: true);
    expect(c.serviceIds, {'svc_02'});
    expect(c.comboId, isNull);
    expect(c.doctorId, 'doc_01');
    expect(c.date, DateTime(2099, 1, 2));
    c.applyInitialValues(
        replaceSelection: true,
        serviceIds: ['svc_02'],
        suggestedDate: DateTime(2020));
    expect(c.date, isNull);
    expect(c.doctorId, isNull);
    c.dispose();
    data.dispose();
  });
  group('API followup', () {
    testWidgets('explicit service preserves eligible doctor and date',
        (t) async {
      final d = FollowupData(serviceId: 'svc_01');
      await mount(t, d, FakeCatalogBackend().provider());
      await t.tap(find.text('Đặt lịch tái khám'));
      final r = PatientNavigation.pendingBookingRequest!;
      expect(r.serviceIds, ['svc_01']);
      expect(r.doctorId, 'doc_01');
      expect(r.suggestedDate, DateTime(2099, 1, 2, 9));
      expect(r.patientId, d.primaryPatient.id);
      expect(r.restrictToServiceIds, isTrue);
    });
    testWidgets('svc_02 never replaced by svc_01', (t) async {
      await mount(t, FollowupData(serviceId: 'svc_02'),
          FakeCatalogBackend().provider());
      await t.tap(find.text('Đặt lịch tái khám'));
      expect(PatientNavigation.pendingBookingRequest!.serviceIds, ['svc_02']);
      expect(PatientNavigation.pendingBookingRequest!.doctorId, isNull);
    });
    testWidgets('missing service blocks despite previous visit links',
        (t) async {
      await mount(t, FollowupData(), FakeCatalogBackend().provider());
      expect(button(t).onPressed, isNull);
      expect(find.textContaining('Chưa có chỉ định'), findsOneWidget);
      expect(PatientNavigation.pendingBookingRequest, isNull);
    });
    testWidgets('unknown service blocks without default', (t) async {
      await mount(t, FollowupData(serviceId: 'missing'),
          FakeCatalogBackend().provider());
      expect(button(t).onPressed, isNull);
      expect(find.textContaining('không có trong danh mục'), findsOneWidget);
    });
    testWidgets('delayed catalog enables only after load', (t) async {
      final c = DelayedCatalog(FakeCatalogBackend().provider());
      await mount(t, FollowupData(serviceId: 'svc_02'), c, settle: false);
      expect(button(t).onPressed, isNull);
      c.gate.complete();
      await t.pumpAndSettle();
      expect(button(t).onPressed, isNotNull);
    });
    testWidgets('catalog error and Retry', (t) async {
      final b = FakeCatalogBackend()..failStatus = 500;
      await mount(t, FollowupData(serviceId: 'svc_02'), b.provider());
      expect(button(t).onPressed, isNull);
      b.failStatus = null;
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(button(t).onPressed, isNotNull);
    });
    testWidgets('old callback rejected after account change', (t) async {
      final d = FollowupData(serviceId: 'svc_02');
      await mount(t, d, FakeCatalogBackend().provider());
      final old = button(t).onPressed!;
      d.clearPrivateState();
      old();
      await t.pumpAndSettle();
      expect(PatientNavigation.pendingBookingRequest, isNull);
      expect(find.text('Đặt lịch tái khám'), findsNothing);
    });
    testWidgets('logout during delayed catalog cannot revive records',
        (t) async {
      final d = FollowupData(serviceId: 'svc_02');
      final c = DelayedCatalog(FakeCatalogBackend().provider());
      await mount(t, d, c, settle: false);
      d.clearPrivateState();
      c.gate.complete();
      await t.pumpAndSettle();
      expect(find.text('Đặt lịch tái khám'), findsNothing);
      expect(PatientNavigation.pendingBookingRequest, isNull);
    });
    testWidgets('past date and absent doctor not preselected', (t) async {
      await mount(t, FollowupData(serviceId: 'svc_02', doctor: '', past: true),
          FakeCatalogBackend().provider());
      await t.tap(find.text('Đặt lịch tái khám'));
      expect(PatientNavigation.pendingBookingRequest!.suggestedDate, isNull);
      expect(PatientNavigation.pendingBookingRequest!.doctorId, isNull);
    });
  }, skip: !api);
  testWidgets('mock retains manual demo service selection', (t) async {
    await mount(
        t, FollowupData(doctor: 'doctor-lan'), FakeCatalogBackend().provider());
    await t.tap(find.text('Đặt lịch tái khám'));
    expect(PatientNavigation.pendingBookingRequest!.serviceIds, isNull);
    expect(PatientNavigation.pendingBookingRequest!.doctorId, isNull);
  }, skip: api);
}
