import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'support/fake_catalog_backend.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/availability_slot.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart'
    hide AvailabilitySlot;
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/providers/appointments_provider.dart';

class BookingBackend {
  int posts = 0, gets = 0;
  final postStarted = Completer<void>();
  bool failGet = false, failPost = false;
  Completer<http.Response>? pendingPost, pendingGet;
  late final payload = <String, dynamic>{
    'id': 'appointment_real',
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
    'discount': 0,
    'status': 'booked',
  };
  http.Response response(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
  late final service =
      BookingService(client: ApiClient(client: MockClient((r) async {
    if (r.url.path == '/api/bookings/quote') {
      return response({
        'subtotal': 250000,
        'discount': 0,
        'totalPrice': 250000,
        'durationMinutes': 45
      });
    }
    if (r.url.path != '/api/appointments') {
      throw StateError('Unexpected endpoint');
    }
    if (r.method == 'POST') {
      posts++;
      if (!postStarted.isCompleted) postStarted.complete();
      expect(jsonDecode(r.body)['serviceIds'], ['svc_01']);
      if (pendingPost != null) return pendingPost!.future;
      return failPost
          ? response({'message': 'create failed'}, 500)
          : response(payload, 201);
    }
    gets++;
    if (pendingGet != null) return pendingGet!.future;
    return failGet
        ? response({'message': 'refresh failed'}, 500)
        : response([payload]);
  })));
}

PatientDataProvider patients() {
  final p = PatientDataProvider(seedDemo: false);
  p.syncPatients(
      const UserProfile(id: 'A', email: '', fullName: 'A', phone: ''), []);
  return p;
}

BookingController draft(PatientDataProvider data, BookingService service) {
  final c = BookingController(data, bookingService: service);
  // Prepare an already-confirmed slot without requesting quote/availability.
  c.serviceIds.add('svc_01');
  c.doctorId = 'doc_01';
  c.doctorChosen = true;
  c.date = DateTime(2099, 1, 1);
  c.time = '09:00';
  c.availabilitySlots = [
    const AvailabilitySlot(
        doctorId: 'doc_01',
        doctorName: 'Bác sĩ API',
        date: '2099-01-01',
        startTime: '09:00',
        endTime: '09:45',
        durationMinutes: 45)
  ];
  return c;
}

void main() {
  group('API booking sync', () {
    test('server response with real IDs updates both appointment stores',
        () async {
      final b = BookingBackend();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      final result = await c.submit(appointmentsProvider: list);
      expect(result!.id, 'appointment_real');
      expect(c.created, same(result));
      expect(data.appointmentsFor('A').single.id, result.id);
      expect(list.appointments.single.id, result.id);
      expect(result.doctorId, 'doc_01');
      expect(result.serviceIds, ['svc_01']);
      expect(result.totalPrice, 250000);
      expect(result.durationMinutes, 45);
      expect(result.status, AppointmentStatus.pending);
      expect(b.posts, 1);
      expect(b.gets, 0);
      c.dispose();
      list.dispose();
      data.dispose();
    });
    test(
        'failed refresh after success keeps new appointment and does not repeat POST',
        () async {
      final b = BookingBackend();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      final result = await c.submit(appointmentsProvider: list);
      b.failGet = true;
      await list.load();
      expect(list.error, isNotNull);
      expect(list.appointments.single.id, result!.id);
      expect(data.appointments.single.id, result.id);
      expect(c.created, same(result));
      await c.submit(appointmentsProvider: list);
      expect(b.posts, 1);
      expect(c.submitting, isFalse);
      c.dispose();
      list.dispose();
      data.dispose();
    });
    test(
        'double tap while POST is pending and repeated submit after success send one POST',
        () async {
      final b = BookingBackend()..pendingPost = Completer<http.Response>();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      final first = c.submit(appointmentsProvider: list);
      await b.postStarted.future;
      await c.submit(appointmentsProvider: list);
      expect(c.submitting, isTrue);
      expect(b.posts, 1);
      b.pendingPost!.complete(b.response(b.payload, 201));
      await first;
      await c.submit(appointmentsProvider: list);
      expect(b.posts, 1);
      expect(data.appointments, hasLength(1));
      c.dispose();
      list.dispose();
      data.dispose();
    });
    test(
        'late response from A cannot update B or show success in the old controller',
        () async {
      final b = BookingBackend()..pendingPost = Completer<http.Response>();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      final old = c.submit(appointmentsProvider: list);
      await b.postStarted.future;
      data.clearPrivateState();
      list.clear();
      data.syncPatients(
          const UserProfile(id: 'B', email: '', fullName: 'B', phone: ''), []);
      b.pendingPost!.complete(b.response(b.payload, 201));
      await old;
      expect(data.appointments, isEmpty);
      expect(list.appointments, isEmpty);
      expect(c.created, isNull);
      expect(b.posts, 1);
      c.dispose();
      list.dispose();
      data.dispose();
    });
    test('list session guard is checked even before patient store is reset',
        () async {
      final b = BookingBackend()..pendingPost = Completer<http.Response>();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      final old = c.submit(appointmentsProvider: list);
      list.clear();
      b.pendingPost!.complete(b.response(b.payload, 201));
      await old;
      expect(data.appointments, isEmpty);
      expect(c.created, isNull);
      c.dispose();
      list.dispose();
      data.dispose();
    });
    test(
        'older in-flight GET cannot erase a successful create; later GET deduplicates',
        () async {
      final b = BookingBackend()..pendingGet = Completer<http.Response>();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      final oldGet = list.load();
      await c.submit(appointmentsProvider: list);
      b.pendingGet!.complete(b.response([]));
      await oldGet;
      expect(list.appointments.single.id, 'appointment_real');
      b.pendingGet = null;
      await list.load();
      expect(list.appointments, hasLength(1));
      data.replaceAppointments(list.appointments,
          generation: data.sessionGeneration);
      expect(data.appointments, hasLength(1));
      c.dispose();
      list.dispose();
      data.dispose();
    });
    test('applying the same response twice is idempotent in both stores',
        () async {
      final b = BookingBackend();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final a = Appointment.fromJson(b.payload);
      for (var i = 0; i < 2; i++) {
        list.addCreated(a, generation: list.sessionGeneration);
        data.upsertApiAppointment(a, generation: data.sessionGeneration);
      }
      expect(list.appointments, hasLength(1));
      expect(data.appointments, hasLength(1));
      list.clear();
      await list.load();
      expect(list.appointments, hasLength(1));
      list.dispose();
      data.dispose();
    });
    test('failed POST does not create a local success and leaves loading clear',
        () async {
      final b = BookingBackend()..failPost = true;
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      await expectLater(
          c.submit(appointmentsProvider: list), throwsA(isA<ApiException>()));
      expect(c.created, isNull);
      expect(data.appointments, isEmpty);
      expect(list.appointments, isEmpty);
      expect(c.submitting, isFalse);
      c.dispose();
      list.dispose();
      data.dispose();
    });
    test(
        'missing aggregate provider still updates the records appointment list',
        () async {
      final b = BookingBackend();
      final data = patients();
      final c = draft(data, b.service);
      await c.submit();
      expect(data.appointmentsFor('A').single.id, 'appointment_real');
      c.dispose();
      data.dispose();
    });
    testWidgets(
        'records appointment screen updates immediately from the confirmed response',
        (tester) async {
      final b = BookingBackend();
      final data = patients();
      final list = AppointmentsProvider(service: b.service);
      final c = draft(data, b.service);
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: data),
        ChangeNotifierProvider<CatalogProvider>(
            create: (_) => FakeCatalogBackend().provider()),
      ], child: const MaterialApp(home: AppointmentsScreen(patientId: 'A'))));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có lịch hẹn.'), findsOneWidget);
      await c.submit(appointmentsProvider: list);
      await tester.pumpAndSettle();
      expect(find.text('Khám răng tổng quát'), findsOneWidget);
      expect(find.text('Bác sĩ API'), findsOneWidget);
      expect(find.text('Chưa có lịch hẹn.'), findsNothing);
      expect(b.posts, 1);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      list.dispose();
      data.dispose();
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
  test('Mock booking retains demo catalog validation and sync behavior',
      () async {
    final data = PatientDataProvider();
    var posts = 0;
    final service =
        BookingService(client: ApiClient(client: MockClient((r) async {
      posts++;
      return http.Response(
          jsonEncode({
            'id': 'mock-confirmed',
            'patientId': data.primaryPatient.id,
            'doctorId': data.doctors.first.id,
            'serviceIds': [data.services.first.id],
            'date': '2099-01-01',
            'startTime': '09:00',
            'endTime': '09:45',
            'durationMinutes': 45,
            'status': 'booked'
          }),
          201);
    })));
    final c = BookingController(data, bookingService: service);
    c.serviceIds.add(data.services.first.id);
    c.doctorChosen = true;
    c.doctorId = data.doctors.first.id;
    c.date = DateTime(2099, 1, 1);
    c.time = '09:00';
    c.availabilitySlots = [
      AvailabilitySlot(
          doctorId: data.doctors.first.id,
          doctorName: '',
          date: '2099-01-01',
          startTime: '09:00',
          endTime: '09:45',
          durationMinutes: 45)
    ];
    await c.submit();
    expect(
        data.appointments.where((a) => a.id == 'mock-confirmed'), hasLength(1));
    await c.submit();
    expect(posts, 1);
    c.dispose();
    data.dispose();
  }, skip: AppConfig.current.dataSource != DataSource.mock);
}
