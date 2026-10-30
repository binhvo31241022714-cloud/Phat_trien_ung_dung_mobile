import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/availability_slot.dart' as slots;
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/booking/widgets/booking_price_summary.dart';
import 'package:frontend/features/booking/booking_doctor_name.dart';
import 'package:frontend/features/booking/booking_success_screen.dart';
import 'package:frontend/features/booking/steps/confirm_booking_step.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'package:frontend/features/records/records_widgets.dart';
import 'package:frontend/features/me/edit_profile_screen.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'private_session_test.dart' show DeferredProfile;
import 'me_test.dart' show demoUsers;
import 'support/fake_catalog_backend.dart';

class QuoteBackend {
  int quotes = 0, creates = 0;
  int status = 200;
  bool timeout = false;
  Completer<http.Response>? gate;
  late final service =
      BookingService(client: ApiClient(client: MockClient((r) async {
    if (r.url.path == '/api/bookings/quote') {
      quotes++;
      if (timeout) throw TimeoutException('simulated');
      if (gate != null) return gate!.future;
      return http.Response(
          jsonEncode(status == 200
              ? {
                  'subtotal': 125000,
                  'discount': 0,
                  'totalPrice': 125000,
                  'durationMinutes': 45
                }
              : {'message': 'Quote unavailable'}),
          status);
    }
    creates++;
    throw StateError('Creation must not be sent in this test');
  })));
}

class RecordsState extends PatientDataProvider {
  bool busy = false;
  String? failure;
  @override
  bool get recordsLoading => busy;
  @override
  String? get recordsError => failure;
}

class AppointmentState extends AppointmentsProvider {
  String? failure;
  int retries = 0;
  @override
  String? get error => failure;
  @override
  Future<void> load() async {
    retries++;
    failure = null;
    notifyListeners();
  }
}

void main() {
  final api = AppConfig.current.dataSource == DataSource.api;
  test('appointment unknown dates and duration never become now or 30 minutes',
      () {
    for (final row in <Map<String, dynamic>>[
      {},
      {'date': '2026-02-30', 'startTime': '10:00'},
      {'date': '2026-10-29', 'startTime': '25:61'},
      {'scheduledAt': '2026-02-30T10:00:00'},
      {'scheduledAt': '2026-10-29T09:00:99'},
      {
        'scheduledAt': {'_seconds': 'bad'}
      }
    ]) {
      final a = Appointment.fromJson(row);
      expect(a.hasValidScheduledAt, isFalse);
      expect(a.durationMinutes, 0);
      expect(a.endAt, isNull);
      expect(appointmentDateText(a), 'Chưa có thông tin ngày giờ');
    }
  });
  test(
      'appointment accepts timestamp and explicit end/duration without inventing end',
      () {
    final a = Appointment.fromJson({
      'scheduledAt': {'_seconds': 1793271600},
      'endAt': {'_seconds': 1793274300}
    });
    expect(a.hasValidScheduledAt, isTrue);
    expect(a.durationMinutes, 45);
    final b = Appointment.fromJson(
        {'date': '2026-10-29', 'startTime': '09:00', 'durationMinutes': 60});
    expect(b.endAt!.difference(b.scheduledAt).inMinutes, 60);
    final c =
        Appointment.fromJson({'date': '2026-10-29', 'startTime': '09:00'});
    expect(c.hasValidScheduledAt, isTrue);
    expect(c.durationMinutes, 0);
    expect(c.endAt, isNull);
    final d = Appointment.fromJson({
      'date': '2026-10-29',
      'startTime': '09:00',
      'durationMinutes': -5,
      'endTime': '08:00'
    });
    expect(d.endAt, isNull);
    expect(d.durationMinutes, 0);
  });
  test('demo constructor remains unchanged', () {
    final a = Appointment(
        id: 'demo',
        patientId: 'A',
        serviceIds: [],
        scheduledAt: DateTime(2026),
        status: AppointmentStatus.pending);
    expect(a.durationMinutes, 30);
    expect(a.hasValidScheduledAt, isTrue);
    expect(a.isDemo, isTrue);
  });
  group('API P2', () {
    for (final failure in ['http', 'timeout']) {
      test('quote $failure exposes error and retry returns authoritative price',
          () async {
        final b = QuoteBackend();
        final d = PatientDataProvider();
        final c = BookingController(d, bookingService: b.service);
        c.serviceIds.add('service-checkup');
        b.status = 500;
        b.timeout = failure == 'timeout';
        await c.refreshQuote();
        expect(c.quoteReady, isFalse);
        expect(c.quoteError, isNotNull);
        expect(c.total, 0);
        expect(c.subtotal, 0);
        expect(c.quoteLoading, isFalse);
        b.status = 200;
        b.timeout = false;
        await c.refreshQuote();
        expect(c.quoteReady, isTrue);
        expect(c.quoteError, isNull);
        expect(c.total, 125000);
        expect(b.quotes, 2);
        expect(b.creates, 0);
        c.dispose();
        d.dispose();
      });
    }
    test('failed quote blocks creation even with a valid selected slot',
        () async {
      final b = QuoteBackend()..status = 500;
      final d = PatientDataProvider();
      final c = BookingController(d, bookingService: b.service);
      c.serviceIds.add('svc_01');
      c.doctorId = 'doc_01';
      c.doctorChosen = true;
      c.date = DateTime(2099, 1, 1);
      c.time = '09:00';
      c.availabilitySlots = [
        const slots.AvailabilitySlot(
            doctorId: 'doc_01',
            doctorName: 'API Doctor',
            date: '2099-01-01',
            startTime: '09:00',
            endTime: '09:45',
            durationMinutes: 45)
      ];
      expect(await c.submit(), isNull);
      expect(b.creates, 0);
      expect(c.quoteError, isNotNull);
      expect(c.submitting, isFalse);
      c.dispose();
      d.dispose();
    });
    test('late quote after logout cannot publish a price', () async {
      final b = QuoteBackend()..gate = Completer<http.Response>();
      final d = PatientDataProvider();
      final c = BookingController(d, bookingService: b.service);
      c.serviceIds.add('svc_01');
      final pending = c.refreshQuote();
      expect(c.quoteLoading, isTrue);
      d.clearPrivateState();
      b.gate!.complete(http.Response(
          '{"subtotal":1,"totalPrice":1,"durationMinutes":30}', 200));
      await pending;
      expect(c.total, 0);
      expect(c.quoteReady, isFalse);
      c.dispose();
      d.dispose();
    });
    testWidgets('confirm price error hides total and offers retry', (t) async {
      final b = QuoteBackend()..status = 500;
      final d = PatientDataProvider();
      final c = BookingController(d, bookingService: b.service);
      c.serviceIds.add('svc_01');
      await c.refreshQuote();
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ConfirmBookingStep(controller: c)))));
      expect(find.text('Chưa có giá'), findsNWidgets(2));
      expect(find.text('Thử lại báo giá'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      d.dispose();
    });
    testWidgets('price summary exposes quote Retry before confirmation',
        (t) async {
      final b = QuoteBackend()..status = 500;
      final d = PatientDataProvider();
      final c = BookingController(d, bookingService: b.service);
      c.serviceIds.add('svc_01');
      c.step = 2;
      await c.refreshQuote();
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: AnimatedBuilder(
                  animation: c,
                  builder: (_, child) =>
                      BookingPriceSummary(controller: c, onNext: () {})))));
      expect(find.text('Chưa có giá'), findsOneWidget);
      b.status = 200;
      await t.tap(find.text('Thử lại báo giá'));
      await t.pumpAndSettle();
      expect(c.quoteReady, isTrue);
      expect(b.quotes, 2);
      expect(find.text('Chưa có giá'), findsNothing);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      d.dispose();
    });
    testWidgets('doctor catalog late/error/retry never resolves mock ID',
        (t) async {
      final d = PatientDataProvider();
      final b = FakeCatalogBackend()..failStatus = 500;
      final catalog = b.provider();
      final c = BookingController(d, catalog: catalog);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BookingDoctorName(controller: c, doctorId: 'doctor-lan'))));
      expect(find.textContaining('Đang tải bác sĩ'), findsOneWidget);
      await catalog.load();
      await t.pump();
      expect(find.text('Bác sĩ: Chưa có thông tin bác sĩ'), findsOneWidget);
      expect(find.text('Thử lại danh mục'), findsOneWidget);
      b.failStatus = null;
      await t.tap(find.text('Thử lại danh mục'));
      await t.pumpAndSettle();
      expect(find.text('Bác sĩ: Chưa có thông tin bác sĩ'), findsOneWidget);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BookingDoctorName(controller: c, doctorId: 'doc_01'))));
      expect(find.textContaining('BS. Nguyễn Văn API'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      catalog.dispose();
      d.dispose();
    });
    for (final success in [false, true]) {
      for (final known in [false, true]) {
        testWidgets(
            '${success ? "success" : "confirm"} resolves API doctor and rejects mock fallback: $known',
            (t) async {
          final d = PatientDataProvider();
          final catalog = FakeCatalogBackend().provider();
          await catalog.load();
          final c = BookingController(d, catalog: catalog);
          final id = known ? 'doc_01' : 'doctor-lan';
          c.doctorId = id;
          c.created = Appointment.fromJson(
              {'id': 'real', 'patientId': d.primaryPatient.id, 'doctorId': id});
          final widget = success
              ? BookingSuccessScreen(
                  controller: c, onHome: () {}, onRecords: () {})
              : ConfirmBookingStep(controller: c);
          await t.pumpWidget(MaterialApp(
              home: Scaffold(body: SingleChildScrollView(child: widget))));
          expect(
              find.text(known
                  ? 'Bác sĩ: BS. Nguyễn Văn API'
                  : 'Bác sĩ: Chưa có thông tin bác sĩ'),
              findsOneWidget);
          await t.pumpWidget(const SizedBox());
          c.dispose();
          catalog.dispose();
          d.dispose();
        });
      }
    }
    testWidgets('success prioritizes doctorName from API response', (t) async {
      final d = PatientDataProvider();
      final c = BookingController(d);
      c.created = Appointment.fromJson({
        'id': 'a',
        'patientId': d.primaryPatient.id,
        'doctorId': 'doctor-lan',
        'doctorName': 'Payload Doctor'
      });
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BookingSuccessScreen(
                  controller: c, onRecords: () {}, onHome: () {}))));
      expect(find.text('Bác sĩ: Payload Doctor'), findsOneWidget);
      expect(find.textContaining('Chưa có thông tin ngày giờ'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
      d.dispose();
    });
    for (final recordsFail in [true, false]) {
      testWidgets(
          'isolated ${recordsFail ? "records" : "appointments"} error uses its own source',
          (t) async {
        final d = RecordsState()
          ..failure = recordsFail ? 'Records failed' : null;
        final catalog = FakeCatalogBackend().provider();
        await catalog.load();
        final appointments = AppointmentState()
          ..failure = recordsFail ? null : 'Appointments failed';
        d.replaceAppointments([
          Appointment.fromJson({
            'id': 'real',
            'patientId': d.primaryPatient.id,
            'serviceIds': ['svc_01'],
            'date': '2026-10-29',
            'startTime': '09:00'
          })
        ]);
        await t.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<PatientDataProvider>.value(value: d),
              ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
              ChangeNotifierProvider<AppointmentsProvider>.value(
                  value: appointments),
            ],
            child: MaterialApp(
                home: AppointmentsScreen(patientId: d.primaryPatient.id))));
        await t.pumpAndSettle();
        expect(find.text('Khám răng tổng quát'), findsOneWidget);
        expect(find.text('Records failed'), findsNothing);
        expect(find.text('Appointments failed'),
            recordsFail ? findsNothing : findsOneWidget);
        await t.pumpWidget(const SizedBox());
        d.dispose();
        catalog.dispose();
        appointments.dispose();
      });
    }
    for (final busy in [false, true]) {
      testWidgets(
          'records ${busy ? 'loading' : 'error'} does not hide appointments or appointment errors',
          (t) async {
        final d = RecordsState()
          ..busy = busy
          ..failure = 'Records failed';
        d.replaceAppointments([
          Appointment.fromJson({
            'id': 'a',
            'patientId': d.primaryPatient.id,
            'serviceIds': ['svc_01'],
            'doctorId': 'doc_01'
          })
        ]);
        final c = FakeCatalogBackend().provider();
        await c.load();
        final a = AppointmentState()..failure = 'Appointments failed';
        await t.pumpWidget(MultiProvider(
            providers: [
              ChangeNotifierProvider<PatientDataProvider>.value(value: d),
              ChangeNotifierProvider<CatalogProvider>.value(value: c),
              ChangeNotifierProvider<AppointmentsProvider>.value(value: a),
            ],
            child: MaterialApp(
                home: AppointmentsScreen(patientId: d.primaryPatient.id))));
        await t.pumpAndSettle();
        expect(find.text('Khám răng tổng quát'), findsOneWidget);
        expect(find.text('Chưa có thông tin ngày giờ'), findsOneWidget);
        expect(find.text('Appointments failed'), findsOneWidget);
        expect(find.text('Records failed'), findsNothing);
        await t.tap(find.text('Thử lại lịch hẹn'));
        await t.pumpAndSettle();
        expect(a.retries, 1);
        expect(find.text('Appointments failed'), findsNothing);
        await t.pumpWidget(const SizedBox());
        d.dispose();
        c.dispose();
        a.dispose();
      });
    }
  }, skip: !api);
  testWidgets(
      'profile A save returns late after B: no stale message/navigation or form',
      (t) async {
    final service = DeferredProfile();
    final p = ProfileProvider(service: service);
    final users = demoUsers();
    Future<void> load(String id) async {
      final pending = p.loadProfile();
      service.pending.last.complete(UserProfile(
          id: id,
          email: 'test@example.test',
          fullName: 'Account $id',
          phone: '0901234567',
          birthday: DateTime(1990, 1, 1)));
      await pending;
    }

    await load('A');
    await t.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<ProfileProvider>.value(value: p),
      ChangeNotifierProvider<UserProvider>.value(value: users),
    ], child: const MaterialApp(home: EditProfileScreen())));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Lưu thay đổi'));
    await t.pumpAndSettle();
    await t.tap(find.text('Lưu thay đổi'));
    await t.pump();
    expect(service.writes.length, 1);
    p.clear();
    await load('B');
    await t.pumpAndSettle();
    service.writes.single.complete();
    await t.pumpAndSettle();
    expect(p.profile!.id, 'B');
    expect(find.text('Account B'), findsOneWidget);
    expect(find.textContaining('Đã lưu thông tin'), findsNothing);
    expect(find.textContaining('Chưa lưu được'), findsNothing);
    await t.pumpWidget(const SizedBox());
    p.dispose();
    users.dispose();
  });
}
