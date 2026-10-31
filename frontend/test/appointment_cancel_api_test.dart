import 'package:frontend/features/records/records_widgets.dart';
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
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/features/records/appointment_detail_screen.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'support/fake_catalog_backend.dart';

class Backend {
  final json = <String, dynamic>{
    'id': 'appointment_A',
    'accountId': 'A',
    'patientId': 'A',
    'doctorId': 'doc_01',
    'doctorName': 'Bác sĩ API',
    'serviceIds': ['svc_01'],
    'date': '2099-01-01',
    'startTime': '09:00',
    'endTime': '09:45',
    'durationMinutes': 45,
    'totalPrice': 250000,
    'status': 'booked'
  };
  int patches = 0;
  int? fail;
  bool wrongAck = false;
  Completer<http.Response>? gate, listGate;
  final started = Completer<void>();
  http.Response response(Object value, [int status = 200]) =>
      http.Response(jsonEncode(value), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
  late final service =
      BookingService(client: ApiClient(client: MockClient((r) async {
    if (r.method == 'PATCH') {
      expect(r.url.path, '/api/appointments/appointment_A/cancel');
      patches++;
      if (!started.isCompleted) started.complete();
      if (gate != null) return gate!.future;
      if (fail != null) return response({'message': 'Lỗi hủy $fail'}, fail!);
      return response(
          {'id': wrongAck ? 'wrong' : json['id'], 'status': 'cancelled'});
    }
    if (r.url.path == '/api/appointments' && listGate != null) {
      return listGate!.future;
    }
    return response(r.url.path == '/api/appointments' ? [json] : json);
  })));
  PatientDataProvider data() {
    final d = PatientDataProvider(seedDemo: false);
    d.syncPatients(
        const UserProfile(id: 'A', email: '', fullName: 'A', phone: ''), []);
    d.replaceAppointments([
      Appointment.fromJson(json),
      Appointment.fromJson({...json, 'id': 'other'})
    ]);
    return d;
  }
}

void main() {
  test(
      'eligibility matches owner, status and Vietnam time; malformed fields fail closed',
      () {
    final b = Backend();
    expect(AppointmentCancellationInfo(b.json).canCancelFor('A'), isTrue);
    expect(
        AppointmentCancellationInfo({...b.json, 'patientId': 'family'})
            .canCancelFor('A'),
        isTrue);
    expect(AppointmentCancellationInfo(b.json).canCancelFor('B'), isFalse);
    for (final status in [
      'cancelled',
      'canceled',
      'completed',
      'expired',
      'rejected',
      'declined'
    ]) {
      expect(
          AppointmentCancellationInfo({...b.json, 'status': status})
              .canCancelFor('A'),
          isFalse);
    }
    for (final extra in [
      {'date': '2000-01-01'},
      {'date': '2099-02-30'},
      {'startTime': '99:00'},
      {'endTime': null},
      {'doctorId': null}
    ]) {
      expect(
          AppointmentCancellationInfo({...b.json, ...extra}).canCancelFor('A'),
          isFalse);
    }
    expect(
        AppointmentCancellationInfo(b.json)
            .canCancelFor('A', now: DateTime.parse('2099-01-01T02:00:00Z')),
        isFalse);
  });
  test(
      'successful ACK cancels only target, preserving all other appointment data',
      () async {
    final b = Backend();
    final p = AppointmentsProvider(service: b.service);
    p.addCreated(Appointment.fromJson(b.json));
    p.addCreated(Appointment.fromJson({...b.json, 'id': 'other'}));
    expect(await p.cancel('appointment_A'), isNull);
    final a = p.appointments.firstWhere((a) => a.id == 'appointment_A');
    expect(a.status, AppointmentStatus.cancelled);
    expect(a.totalPrice, 250000);
    expect(a.durationMinutes, 45);
    expect(a.doctorId, 'doc_01');
    expect(p.appointments.firstWhere((a) => a.id == 'other').status,
        AppointmentStatus.pending);
    p.dispose();
  });
  for (final code in [400, 401, 403, 404, 409, 500]) {
    test('PATCH $code leaves the true status unchanged and permits retry',
        () async {
      final b = Backend()..fail = code;
      final p = AppointmentsProvider(service: b.service);
      p.addCreated(Appointment.fromJson(b.json));
      expect(await p.cancel('appointment_A'), contains('$code'));
      expect(p.appointments.single.status, AppointmentStatus.pending);
      expect(p.isCancelling('appointment_A'), isFalse);
      b.fail = null;
      expect(await p.cancel('appointment_A'), isNull);
      expect(b.patches, 2);
      p.dispose();
    });
  }
  test('malformed success ACK never fabricates a cancelled state', () async {
    final b = Backend()..wrongAck = true;
    final p = AppointmentsProvider(service: b.service);
    p.addCreated(Appointment.fromJson(b.json));
    expect(await p.cancel('appointment_A'), isNotNull);
    expect(p.appointments.single.status, AppointmentStatus.pending);
    p.dispose();
  });
  test(
      'concurrent cancel calls coalesce; late ACK after account switch cannot update B',
      () async {
    final b = Backend()..gate = Completer<http.Response>();
    final p = AppointmentsProvider(service: b.service);
    p.addCreated(Appointment.fromJson(b.json));
    final first = p.cancel('appointment_A');
    final second = p.cancel('appointment_A');
    await b.started.future;
    expect(b.patches, 1);
    expect(p.isCancelling('appointment_A'), isTrue);
    p.clear();
    p.addCreated(Appointment.fromJson(
        {...b.json, 'id': 'B', 'accountId': 'B', 'patientId': 'B'}));
    b.gate!
        .complete(b.response({'id': 'appointment_A', 'status': 'cancelled'}));
    await Future.wait([first, second]);
    expect(p.appointments.single.id, 'B');
    expect(p.appointments.single.status, AppointmentStatus.pending);
    p.dispose();
  });
  test('old list GET cannot restore booked after cancellation ACK', () async {
    final b = Backend()..listGate = Completer<http.Response>();
    final p = AppointmentsProvider(service: b.service);
    p.addCreated(Appointment.fromJson(b.json));
    final get = p.load();
    await p.cancel('appointment_A');
    b.listGate!.complete(b.response([b.json]));
    await get;
    expect(p.appointments.single.status, AppointmentStatus.cancelled);
    p.dispose();
  });
  group('API cancellation UI', () {
    Future<(PatientDataProvider, AppointmentsProvider)> mount(
        WidgetTester tester, Backend b) async {
      final d = b.data();
      final p = AppointmentsProvider(service: b.service);
      for (final a in d.appointments) {
        p.addCreated(a);
      }
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: d),
            ChangeNotifierProvider.value(value: p),
            ChangeNotifierProvider<CatalogProvider>(
                create: (_) => FakeCatalogBackend().provider()),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: Column(children: [
            const Expanded(
                child: AppointmentDetailScreen(appointmentId: 'appointment_A')),
            TextButton(
                onPressed: () => Navigator.of(
                        tester.element(find.byType(AppointmentDetailScreen)))
                    .push(MaterialPageRoute<void>(
                        builder: (_) =>
                            const AppointmentsScreen(patientId: 'A'))),
                child: const Text('Danh sách')),
          ])))));
      await tester.pumpAndSettle();
      return (d, p);
    }

    Future<void> confirm(WidgetTester t) async {
      await t.ensureVisible(find.text('Hủy lịch'));
      await t.tap(find.text('Hủy lịch'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xác nhận hủy'));
      await t.pumpAndSettle();
    }

    testWidgets(
        'confirmation then server ACK updates detail and list, preserving other records',
        (t) async {
      final b = Backend();
      final (d, p) = await mount(t, b);
      await confirm(t);
      expect(d.appointments.firstWhere((a) => a.id == 'appointment_A').status,
          AppointmentStatus.cancelled);
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.text('Hủy lịch'), findsNothing);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await t.tap(find.text('Danh sách'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(Tab, 'Đã hủy'));
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('appointment-card-appointment_A')),
              matching: find.text('Đã hủy')),
          findsOneWidget);
      await t.tap(find.widgetWithText(Tab, 'Chờ xác nhận'));
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(RecordBadge),
              matching: find.text('Chờ xác nhận')),
          findsOneWidget);
      expect(b.patches, 1);
      await t.pumpWidget(const SizedBox());
      d.dispose();
      p.dispose();
    });
    testWidgets('failure shows backend message, leaves status and allows retry',
        (t) async {
      final b = Backend()..fail = 500;
      final (d, p) = await mount(t, b);
      await confirm(t);
      expect(find.text('Yêu cầu thất bại (HTTP 500).'), findsOneWidget);
      expect(d.appointments.first.status, AppointmentStatus.pending);
      b.fail = null;
      await confirm(t);
      expect(find.text('Đã hủy'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      d.dispose();
      p.dispose();
    });
    testWidgets(
        'double-tap confirmation/pending operation never creates duplicate PATCH',
        (t) async {
      final b = Backend()..gate = Completer<http.Response>();
      final (d, p) = await mount(t, b);
      await t.ensureVisible(find.text('Hủy lịch'));
      await t.tap(find.text('Hủy lịch'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xác nhận hủy'));
      await t.pump();
      await b.started.future;
      expect(find.text('Đang hủy…'), findsOneWidget);
      expect(b.patches, 1);
      final button = t.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Đang hủy…'));
      expect(button.onPressed, isNull);
      b.gate!
          .complete(b.response({'id': 'appointment_A', 'status': 'cancelled'}));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      d.dispose();
      p.dispose();
    });
    testWidgets('keeping the appointment in confirmation sends no PATCH',
        (t) async {
      final b = Backend();
      final (d, p) = await mount(t, b);
      await t.ensureVisible(find.text('Hủy lịch'));
      await t.tap(find.text('Hủy lịch'));
      await t.pumpAndSettle();
      await t.tap(find.text('Giữ lịch'));
      await t.pumpAndSettle();
      expect(b.patches, 0);
      expect(d.appointments.first.status, AppointmentStatus.pending);
      await t.pumpWidget(const SizedBox());
      d.dispose();
      p.dispose();
    });
    testWidgets('ineligible appointment has no cancel action', (t) async {
      final b = Backend();
      b.json['status'] = 'completed';
      final (d, p) = await mount(t, b);
      expect(find.text('Hủy lịch'), findsNothing);
      expect(b.patches, 0);
      await t.pumpWidget(const SizedBox());
      d.dispose();
      p.dispose();
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
  testWidgets('Mock cancellation stays local without an API provider',
      (t) async {
    final d = PatientDataProvider();
    d.replaceAppointments([
      Appointment(
          id: 'demo-cancel',
          patientId: d.primaryPatient.id,
          doctorId: d.doctors.first.id,
          serviceIds: [d.services.first.id],
          scheduledAt: DateTime(2099),
          status: AppointmentStatus.pending,
          isDemo: true)
    ]);
    await t.pumpWidget(ChangeNotifierProvider.value(
        value: d,
        child: const MaterialApp(
            home: AppointmentDetailScreen(appointmentId: 'demo-cancel'))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Hủy lịch'));
    await t.tap(find.text('Hủy lịch'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xác nhận hủy'));
    await t.pumpAndSettle();
    expect(d.appointments.single.status, AppointmentStatus.cancelled);
    await t.pumpWidget(const SizedBox());
    d.dispose();
  }, skip: AppConfig.current.dataSource != DataSource.mock);
}
