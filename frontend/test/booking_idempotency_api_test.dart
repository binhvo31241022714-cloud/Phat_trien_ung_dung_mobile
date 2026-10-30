import 'dart:convert';
import 'package:flutter/material.dart';
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
import 'package:frontend/features/booking/widgets/booking_price_summary.dart';

/// Máy chủ giả ghi lại header Idempotency-Key và body của từng lần POST.
class Backend {
  final keys = <String?>[];
  final bodies = <Map<String, dynamic>>[];

  /// 'network' ném lỗi kết nối, số là mã HTTP lỗi, null là thành công.
  final outcomes = <Object?>[];
  http.Response ok(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
  late final service =
      BookingService(client: ApiClient(client: MockClient((r) async {
    if (r.url.path == '/api/bookings/quote') {
      return ok({
        'subtotal': 250000,
        'discount': 0,
        'totalPrice': 250000,
        'durationMinutes': 30
      });
    }
    keys.add(r.headers['Idempotency-Key'] ?? r.headers['idempotency-key']);
    bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
    final outcome = outcomes.isEmpty ? null : outcomes.removeAt(0);
    if (outcome == 'network') throw http.ClientException('mất mạng');
    if (outcome is int) return ok({'message': 'Lỗi $outcome'}, outcome);
    return ok({
      'id': 'appt_1',
      'accountId': 'A',
      'patientId': 'A',
      'doctorId': 'doc_01',
      'serviceIds': ['svc_01'],
      'date': '2099-01-01',
      'startTime': bodies.last['startTime'],
      'endTime': '09:30',
      'note': bodies.last['note'],
      'status': 'booked',
    }, 201);
  })));
}

BookingController draft(Backend b) {
  final data = PatientDataProvider(seedDemo: false)
    ..syncPatients(
        const UserProfile(id: 'A', email: '', fullName: 'A', phone: ''), []);
  final c = BookingController(data, bookingService: b.service);
  c.serviceIds.add('svc_01');
  c.doctorId = 'doc_01';
  c.doctorChosen = true;
  c.date = DateTime(2099, 1, 1);
  c.time = '09:00';
  c.availabilitySlots = [
    for (final t in ['09:00', '10:00'])
      AvailabilitySlot(
          doctorId: 'doc_01',
          doctorName: 'BS',
          date: '2099-01-01',
          startTime: t,
          endTime: t.replaceFirst(':00', ':30'),
          durationMinutes: 30)
  ];
  return c;
}

Future<Object?> submitError(BookingController c) async {
  try {
    await c.submit();
    return null;
  } catch (e) {
    return e;
  }
}

final uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

void main() {
  group('A11/A13 API', () {
    test('gửi ghi chú đã cắt khoảng trắng và Idempotency-Key dạng UUID v4',
        () async {
      final b = Backend();
      final c = draft(b)..note = '  Ê buốt răng  ';
      final result = await c.submit();
      expect(b.bodies.single['note'], 'Ê buốt răng');
      expect(b.keys.single, matches(uuidV4));
      expect(result!.note, 'Ê buốt răng');
      expect(c.awaitingRetry, isFalse);
    });

    test(
        'lỗi mạng: khóa lựa chọn, Thử lại dùng đúng key cũ, thành công thì mở khóa',
        () async {
      final b = Backend()..outcomes.addAll(['network', 'network', null]);
      final c = draft(b)..note = 'ghi chú';
      final error = await submitError(c);
      expect((error as ApiException).kind, ApiErrorKind.connection);
      expect(c.awaitingRetry, isTrue);
      expect(c.locked, isTrue);
      // Mọi lựa chọn bị khóa.
      c.chooseTime('10:00');
      c.toggleService('svc_02');
      c.selectPatient('khac');
      c.removeVoucher();
      c.step = 3;
      c.back();
      expect(c.time, '09:00');
      expect(c.serviceIds, {'svc_01'});
      expect(c.patientId, 'A');
      expect(c.step, 3);
      expect(await c.applyVoucher('GIAM10'), isFalse);
      await submitError(c);
      expect(c.awaitingRetry, isTrue);
      final created = await c.submit();
      expect(created!.id, 'appt_1');
      expect(b.keys.length, 3);
      expect(b.keys.toSet().length, 1, reason: 'cả 3 lần gửi cùng một key');
      expect(c.awaitingRetry, isFalse);
    });

    test('hết thời gian chờ cũng khóa như mất mạng', () async {
      final b = Backend();
      final c = BookingController(
          PatientDataProvider(seedDemo: false)
            ..syncPatients(
                const UserProfile(id: 'A', email: '', fullName: 'A', phone: ''),
                []),
          bookingService: BookingService(
              client: ApiClient(
                  timeout: const Duration(milliseconds: 10),
                  client: MockClient((r) async {
                    if (r.url.path == '/api/bookings/quote') {
                      return b.ok({
                        'subtotal': 1,
                        'discount': 0,
                        'totalPrice': 1,
                        'durationMinutes': 30
                      });
                    }
                    await Future<void>.delayed(const Duration(seconds: 1));
                    return b.ok({});
                  }))));
      final d = draft(b);
      c.serviceIds.addAll(d.serviceIds);
      c.doctorId = d.doctorId;
      c.doctorChosen = true;
      c.date = d.date;
      c.time = d.time;
      c.availabilitySlots = d.availabilitySlots;
      final error = await submitError(c);
      expect((error as ApiException).kind, ApiErrorKind.timeout);
      expect(c.awaitingRetry, isTrue);
    });

    test('lỗi không phải mạng (409): mở khóa; sửa lựa chọn thì đổi key',
        () async {
      final b = Backend()..outcomes.addAll([409, 409, null]);
      final c = draft(b);
      await submitError(c);
      expect(c.awaitingRetry, isFalse);
      expect(c.locked, isFalse);
      await submitError(c);
      expect(b.keys[1], b.keys[0], reason: 'không đổi lựa chọn thì giữ key');
      c.chooseTime('10:00');
      expect(c.time, '10:00');
      await c.submit();
      expect(b.keys[2], isNot(b.keys[0]));
    });

    test('sửa ghi chú cũng là lựa chọn mới, đổi key', () async {
      final b = Backend()..outcomes.addAll([400, null]);
      final c = draft(b)..note = 'a';
      await submitError(c);
      c.note = 'b';
      await c.submit();
      expect(b.keys[1], isNot(b.keys[0]));
    });

    test('Chọn lại: chưa có lịch thì mở khóa và lần sau dùng key mới',
        () async {
      final b = Backend()..outcomes.addAll(['network', null]);
      final c = draft(b);
      await submitError(c);
      expect(c.matchLastSent(const []), isNull);
      c.unlockForNewRequest();
      expect(c.awaitingRetry, isFalse);
      await c.submit();
      expect(b.keys[1], isNot(b.keys[0]));
    });

    test(
        'Chọn lại: tìm đúng lịch đã tạo (cùng người khám, ngày, giờ, còn hiệu lực)',
        () async {
      final b = Backend()..outcomes.add('network');
      final c = draft(b);
      await submitError(c);
      Appointment appt(String id,
              {String patient = 'A',
              String date = '2099-01-01',
              String time = '09:00',
              String status = 'booked'}) =>
          Appointment.fromJson({
            'id': id,
            'patientId': patient,
            'date': date,
            'startTime': time,
            'status': status
          });
      final list = [
        appt('khac_nguoi', patient: 'B'),
        appt('khac_ngay', date: '2099-01-02'),
        appt('khac_gio', time: '10:00'),
        appt('da_huy', status: 'cancelled'),
        appt('dung', status: 'confirmed'),
      ];
      expect(c.matchLastSent(list)?.id, 'dung');
      c.adoptCreated(list.last);
      expect(c.created?.id, 'dung');
      expect(c.awaitingRetry, isFalse);
    });

    testWidgets(
        'khi khóa: nút chính là "Thử lại", có "Chọn lại", không có "Quay lại"',
        (t) async {
      final b = Backend()..outcomes.add('network');
      final c = draft(b)..step = 3;
      await submitError(c);
      var retried = 0, reselected = 0;
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BookingPriceSummary(
                  controller: c,
                  onNext: () => retried++,
                  onReselect: () => reselected++))));
      expect(find.text('Quay lại'), findsNothing);
      await t.tap(find.text('Thử lại'));
      await t.tap(find.text('Chọn lại'));
      expect((retried, reselected), (1, 1));
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
}
