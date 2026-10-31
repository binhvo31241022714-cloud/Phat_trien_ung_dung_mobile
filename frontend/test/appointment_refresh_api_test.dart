import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/patient_navigation.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/features/me/api_notifications_view.dart';
import 'package:frontend/features/records/appointment_detail_screen.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'package:frontend/features/records/records_home_screen.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/content_provider.dart';
import 'support/fake_catalog_backend.dart';

/// Máy chủ giả: trạng thái lịch đổi được giữa chừng, giống staff vừa xác nhận.
class Server {
  final json = <String, dynamic>{
    'id': 'appt_1',
    'accountId': 'A',
    'patientId': 'A',
    'doctorId': 'doc_01',
    'doctorName': 'Bác sĩ API',
    'serviceIds': ['svc_01'],
    'date': '2099-01-01',
    'startTime': '09:00',
    'endTime': '09:30',
    'totalPrice': 250000,
    'status': 'booked',
  };
  int listCalls = 0, detailCalls = 0;
  int? detailCode, readCode;
  String notificationType = 'appointment_confirmed';
  Completer<void>? detailGate;
  http.Response ok(Object value) => http.Response(jsonEncode(value), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
  late final client = ApiClient(client: MockClient((r) async {
    final path = r.url.path;
    if (path == '/api/appointments') {
      listCalls++;
      return ok([json]);
    }
    if (path == '/api/appointments/appt_1') {
      detailCalls++;
      if (detailGate != null) await detailGate!.future;
      if (detailCode != null) {
        return http.Response(
            jsonEncode({'message': 'Lỗi $detailCode'}), detailCode!,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return ok(json);
    }
    if (path == '/api/notifications') {
      return ok([
        {
          'id': 'n1',
          'userId': 'A',
          'title': 'Lịch hẹn đã được xác nhận',
          'body': 'Lịch hẹn đã được phòng khám xác nhận.',
          'type': notificationType,
          'refId': 'appt_1',
          'isRead': false,
          'createdAt': {'_seconds': 1790812800},
        }
      ]);
    }
    if (path == '/api/notifications/n1/read') {
      if (readCode != null) return http.Response('{}', readCode!);
      return ok({'id': 'n1', 'isRead': true});
    }
    if (path == '/api/notifications/unread-count') return ok({'count': 0});
    return http.Response('{}', 404);
  }));

  /// Bộ nhớ app đang giữ bản cũ "booked"; máy chủ đổi sang [serverStatus].
  (PatientDataProvider, AppointmentsProvider) providers(String serverStatus) {
    final cached = Appointment.fromJson(json);
    json['status'] = serverStatus;
    final d = PatientDataProvider(seedDemo: false)
      ..syncPatients(
          const UserProfile(id: 'A', email: '', fullName: 'A', phone: ''), [])
      ..replaceAppointments([cached]);
    final p = AppointmentsProvider(service: BookingService(client: client))
      ..addCreated(cached);
    return (d, p);
  }
}

Future<void> mount(
    WidgetTester t, PatientDataProvider d, AppointmentsProvider p, Widget page,
    {ContentProvider? content, bool settle = true}) async {
  await t.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: d),
    ChangeNotifierProvider.value(value: p),
    ChangeNotifierProvider<CatalogProvider>(
        create: (_) => FakeCatalogBackend().provider()),
    if (content != null) ChangeNotifierProvider.value(value: content),
  ], child: MaterialApp(home: Scaffold(body: page))));
  if (settle) await t.pumpAndSettle();
}

AppointmentStatus statusIn(Iterable<Appointment> list) =>
    list.firstWhere((a) => a.id == 'appt_1').status;

void main() {
  group('A07: chi tiết lịch luôn đọc lại từ máy chủ', () {
    testWidgets(
        'đang tải hiện dữ liệu cũ kèm chỉ báo; xong thì hiện "Đã xác nhận" và cập nhật cả hai provider',
        (t) async {
      final s = Server()..detailGate = Completer<void>();
      final (d, p) = s.providers('confirmed');
      await mount(
          t, d, p, const AppointmentDetailScreen(appointmentId: 'appt_1'),
          settle: false);
      await t.pump();
      await t.pump();
      expect(find.text('Chờ xác nhận'), findsOneWidget);
      expect(find.text('Đang cập nhật trạng thái lịch hẹn…'), findsOneWidget);
      expect(find.text('Hủy lịch'), findsNothing);
      s.detailGate!.complete();
      await t.pumpAndSettle();
      expect(s.detailCalls, 1);
      expect(find.text('Đã xác nhận'), findsOneWidget);
      expect(find.text('Chờ xác nhận'), findsNothing);
      expect(find.text('Đang cập nhật trạng thái lịch hẹn…'), findsNothing);
      expect(statusIn(d.appointments), AppointmentStatus.confirmed);
      expect(statusIn(p.appointments), AppointmentStatus.confirmed);
      // Lịch đã xác nhận vẫn được hủy (confirmed → cancelled hợp lệ).
      expect(find.text('Hủy lịch'), findsOneWidget);
    });

    testWidgets('lịch bị từ chối: nhãn "Bị từ chối", không có nút hủy',
        (t) async {
      final s = Server();
      final (d, p) = s.providers('rejected');
      await mount(
          t, d, p, const AppointmentDetailScreen(appointmentId: 'appt_1'));
      expect(find.text('Bị từ chối'), findsOneWidget);
      expect(find.text('Hủy lịch'), findsNothing);
      expect(statusIn(d.appointments), AppointmentStatus.rejected);
    });

    for (final code in [403, 404]) {
      testWidgets('$code: báo lịch không còn khả dụng và bỏ khỏi bộ nhớ',
          (t) async {
        final s = Server()..detailCode = code;
        final (d, p) = s.providers('booked');
        await mount(
            t, d, p, const AppointmentDetailScreen(appointmentId: 'appt_1'));
        expect(find.text('Lịch hẹn không còn khả dụng.'), findsOneWidget);
        expect(find.text('Hủy lịch'), findsNothing);
        expect(d.appointments.any((a) => a.id == 'appt_1'), isFalse);
        expect(p.appointments.any((a) => a.id == 'appt_1'), isFalse);
      });
    }

    testWidgets('lỗi 500: giữ dữ liệu cũ, báo lỗi, bấm Thử lại thì cập nhật',
        (t) async {
      final s = Server()..detailCode = 500;
      final (d, p) = s.providers('confirmed');
      await mount(
          t, d, p, const AppointmentDetailScreen(appointmentId: 'appt_1'));
      expect(find.text('Chờ xác nhận'), findsOneWidget);
      expect(find.text('Yêu cầu thất bại (HTTP 500).'), findsOneWidget);
      expect(find.text('Hủy lịch'), findsNothing);
      s.detailCode = null;
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(find.text('Đã xác nhận'), findsOneWidget);
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);

  group('A07: danh sách lịch hẹn tải lại', () {
    testWidgets('kéo xuống để tải lại cập nhật nhãn và PatientDataProvider',
        (t) async {
      final s = Server();
      final (d, p) = s.providers('confirmed');
      await mount(t, d, p, const AppointmentsScreen(patientId: 'A'));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('appointment-card-appt_1')),
              matching: find.text('Chờ xác nhận')),
          findsOneWidget);
      await t.fling(find.text('Lịch hẹn của A'), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(s.listCalls, 1);
      await t.tap(find.widgetWithText(Tab, 'Đã xác nhận'));
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('appointment-card-appt_1')),
              matching: find.text('Đã xác nhận')),
          findsOneWidget);
      expect(statusIn(d.appointments), AppointmentStatus.confirmed);
    });

    testWidgets('quay lại tab Hồ sơ thì tự tải lại lịch hẹn', (t) async {
      final s = Server();
      final (d, p) = s.providers('confirmed');
      var tab = 0;
      late StateSetter setTab;
      await mount(t, d, p, StatefulBuilder(builder: (context, setState) {
        setTab = setState;
        return MainShellScope(
            selectedIndex: tab,
            onSelectTab: (_) {},
            child: const RecordsHomeScreen());
      }));
      expect(s.listCalls, 0);
      setTab(() => tab = 2);
      await t.pumpAndSettle();
      expect(s.listCalls, 1);
      expect(statusIn(d.appointments), AppointmentStatus.confirmed);
      setTab(() => tab = 0);
      await t.pumpAndSettle();
      setTab(() => tab = 2);
      await t.pumpAndSettle();
      expect(s.listCalls, 2);
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);

  group('detail refresh integration', () {
    setUp(() {
      final previous = AppConfig.current;
      AppConfig.current = AppConfig.fromValues(source: 'api');
      addTearDown(() => AppConfig.current = previous);
    });

    testWidgets('pull refresh observes staff cancellation in both stores',
        (t) async {
      final s = Server();
      final (d, p) = s.providers('confirmed');
      await mount(
          t, d, p, const AppointmentDetailScreen(appointmentId: 'appt_1'));
      s.json['status'] = 'cancelled';
      final refresh =
          t.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await t.pumpAndSettle();
      await refresh;
      expect(s.detailCalls, 2);
      expect(statusIn(d.appointments), AppointmentStatus.cancelled);
      expect(statusIn(p.appointments), AppointmentStatus.cancelled);
      expect(find.text('Hủy lịch'), findsNothing);
    });

    testWidgets(
        'resume refresh observes confirmed and rejects overlapping fetch',
        (t) async {
      final s = Server();
      final (d, p) = s.providers('booked');
      await mount(
          t, d, p, const AppointmentDetailScreen(appointmentId: 'appt_1'));
      s.json['status'] = 'confirmed';
      s.detailGate = Completer<void>();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(s.detailCalls, 2);
      s.detailGate!.complete();
      await t.pumpAndSettle();
      expect(statusIn(d.appointments), AppointmentStatus.confirmed);
      expect(statusIn(p.appointments), AppointmentStatus.confirmed);
      await t.pumpWidget(const SizedBox());
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump();
      expect(s.detailCalls, 2, reason: 'disposed screen must remove observer');
    });
  });

  testWidgets(
      'A07: bấm thông báo appointment_confirmed tải lại lịch trước khi mở',
      (t) async {
    final s = Server();
    final (d, p) = s.providers('confirmed');
    final content = ContentProvider(service: ContentService(client: s.client))
      ..setAccount('A');
    await mount(t, d, p, const ApiNotificationsView(), content: content);
    expect(find.text('Lịch hẹn đã được xác nhận'), findsOneWidget);
    expect(s.listCalls, 0);
    await t.tap(find.text('Lịch hẹn đã được xác nhận'));
    await t.pumpAndSettle();
    expect(s.detailCalls, 1);
    // Màn Hồ sơ đọc PatientDataProvider: đã có trạng thái mới trước khi mở.
    expect(statusIn(d.appointments), AppointmentStatus.confirmed);
    expect(statusIn(p.appointments), AppointmentStatus.confirmed);
    expect(d.recordsAppointmentId, 'appt_1');
  }, skip: AppConfig.current.dataSource != DataSource.api);
  for (final type in [
    'appointment_booked',
    'appointment_confirmed',
    'appointment_rejected',
    'appointment_cancelled',
    'appointment_completed',
    'appointment_reminder'
  ]) {
    testWidgets('A19: $type opens uncached detail despite mark-read failure',
        (t) async {
      final s = Server()
        ..readCode = 500
        ..notificationType = type;
      final (d, p) = s.providers('confirmed');
      p.clear();
      d.replaceAppointments([]);
      final content = ContentProvider(service: ContentService(client: s.client))
        ..setAccount('A');
      await mount(t, d, p, const ApiNotificationsView(), content: content);
      await t.tap(find.text('Lịch hẹn đã được xác nhận'));
      await t.pumpAndSettle();
      expect(s.detailCalls, 1);
      expect(d.recordsAppointmentId, 'appt_1');
      expect(content.notifications.single.isRead, isFalse);
      expect(content.errors['read'], isNotNull);
      expect(t.takeException(), isNull);
    });
  }
  for (final code in [401, 403, 404]) {
    testWidgets('A19: detail $code never opens cached appointment', (t) async {
      final s = Server()..detailCode = code;
      final (d, p) = s.providers('confirmed');
      final content = ContentProvider(service: ContentService(client: s.client))
        ..setAccount('A');
      await mount(t, d, p, const ApiNotificationsView(), content: content);
      await t.tap(find.text('Lịch hẹn đã được xác nhận'));
      await t.pumpAndSettle();
      expect(d.recordsAppointmentId, isNull);
      if (code != 401) expect(d.appointments, isEmpty);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('A19: account switch during detail request prevents navigation',
      (t) async {
    final s = Server()..detailGate = Completer<void>();
    final (d, p) = s.providers('confirmed');
    final content = ContentProvider(service: ContentService(client: s.client))
      ..setAccount('A');
    await mount(t, d, p, const ApiNotificationsView(), content: content);
    await t.tap(find.text('Lịch hẹn đã được xác nhận'));
    await t.pump();
    content.setAccount('B');
    p.clear();
    s.detailGate!.complete();
    await t.pumpAndSettle();
    expect(d.recordsAppointmentId, isNull);
    expect(p.appointments, isEmpty);
    expect(t.takeException(), isNull);
  });
}
