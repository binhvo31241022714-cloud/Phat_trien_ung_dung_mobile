import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/patient_navigation.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/data/services/profile_service.dart';
import 'package:frontend/data/services/records_service.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/me/api_notifications_view.dart';
import 'package:frontend/features/me/settings_screen.dart';
import 'package:frontend/features/records/followup_screen.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'support/fake_auth_service.dart';
import 'support/fake_catalog_backend.dart';

/// Máy chủ giả cho giai đoạn 3: thông báo các loại, follow-up, hồ sơ.
class Phase3Server {
  final requests = <http.Request>[];
  String notificationType = 'follow_up';
  String refId = 'fu1';
  int? followUpCode, readCode, patchCode;
  bool notificationsEnabled = true;
  List<Map<String, dynamic>> followUps = [
    {
      'id': 'fu1',
      'patientId': 'kid',
      'accountId': 'A',
      'scheduledAt': '2099-04-01T02:00:00Z',
      'reason': 'Kiểm tra mắc cài',
      'serviceId': 'svc_01',
      'status': 'suggested',
    },
  ];

  http.Response json(Object value, [int code = 200]) =>
      http.Response(jsonEncode(value), code,
          headers: {'content-type': 'application/json; charset=utf-8'});

  late final client = ApiClient(
      baseUrl: 'http://fake.invalid:3000',
      client: MockClient((r) async {
        requests.add(r);
        final path = r.url.path;
        if (path == '/api/users/me') {
          if (r.method == 'PATCH') {
            if (patchCode != null) return json({'message': 'Lỗi máy chủ'}, patchCode!);
            notificationsEnabled = (jsonDecode(r.body) as Map)['notificationsEnabled'] as bool;
            return json({'message': 'Cập nhật thành công'});
          }
          return json({
            'id': 'A',
            'email': 'a@example.com',
            'fullName': 'Chủ tài khoản',
            'notificationsEnabled': notificationsEnabled,
          });
        }
        if (path == '/api/family-members') {
          return json([
            {'id': 'kid', 'fullName': 'Bé Na', 'relationship': 'Con'}
          ]);
        }
        if (path.startsWith('/api/follow-ups/')) {
          if (followUpCode != null) {
            return json({'message': 'Không tìm thấy hồ sơ'}, followUpCode!);
          }
          return json(followUps.firstWhere((f) => f['id'] == path.split('/').last));
        }
        if (path == '/api/patients/kid/follow-ups') return json(followUps);
        if (path.startsWith('/api/patients/')) return json([]);
        if (path == '/api/notifications') {
          return json([
            {
              'id': 'n1',
              'userId': 'A',
              'title': 'Nhắc lịch tái khám',
              'body': 'Bác sĩ đề xuất tái khám.',
              'type': notificationType,
              'refId': refId,
              'isRead': false,
              'createdAt': '2099-01-01T00:00:00Z',
            }
          ]);
        }
        if (path == '/api/notifications/n1/read') {
          return readCode == null ? json({'id': 'n1', 'isRead': true}) : json({}, readCode!);
        }
        if (path == '/api/notifications/unread-count') return json({'count': 1});
        return json({'message': 'API không tồn tại'}, 404);
      }));

  PatientDataProvider data() => PatientDataProvider(
      seedDemo: false, recordsService: RecordsService(client: client))
    ..syncPatients(const UserProfile(id: 'A', fullName: 'Chủ tài khoản'),
        [FamilyMember.fromJson({'id': 'kid', 'fullName': 'Bé Na', 'relationship': 'Con'})]);
  ProfileProvider profile() => ProfileProvider(service: ProfileService(client: client));
  Iterable<http.Request> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.url.path == path);
}

void main() {
  late AppConfig previous;
  setUp(() {
    previous = AppConfig.current;
    AppConfig.current = AppConfig.fromValues(
        source: 'api', baseUrl: 'http://fake.invalid:3000');
    PatientNavigation.pendingBookingRequest = null;
  });
  tearDown(() {
    AppConfig.current = previous;
    PatientNavigation.pendingBookingRequest = null;
  });

  Future<void> mount(WidgetTester t, Phase3Server s, PatientDataProvider data,
      Widget page, {ProfileProvider? profile, ContentProvider? content}) async {
    t.view.physicalSize = const Size(420, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final catalog = FakeCatalogBackend().provider();
    await catalog.load();
    await t.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
      ChangeNotifierProvider(
          create: (_) => AppointmentsProvider(service: BookingService(client: s.client))),
      ChangeNotifierProvider.value(value: profile ?? s.profile()),
      ChangeNotifierProvider(
          create: (_) => UserProvider(auth: FakeAuthService())..signInDemo('a@example.com')),
      if (content != null) ChangeNotifierProvider.value(value: content),
    ], child: MaterialApp(home: Scaffold(body: page))));
    await t.pumpAndSettle();
  }

  group('A19: bấm thông báo tái khám', () {
    for (final type in ['follow_up', 'follow_up_reminder']) {
      testWidgets('$type: máy chưa có dữ liệu vẫn mở Lịch tái khám đúng người, đọc lỗi vẫn mở',
          (t) async {
        final s = Phase3Server()
          ..notificationType = type
          ..readCode = 500;
        final data = s.data();
        final content = ContentProvider(service: ContentService(client: s.client))..setAccount('A');
        await mount(t, s, data, const ApiNotificationsView(), content: content);
        expect(data.followups, isEmpty);
        await t.tap(find.text('Nhắc lịch tái khám'));
        await t.pumpAndSettle();
        expect(s.calls('GET', '/api/follow-ups/fu1'), hasLength(1));
        expect(data.selectedPatientId, 'kid');
        expect(data.recordsFollowupsPatientId, 'kid');
        expect(data.followups.single.id, 'fu1');
        expect(content.errors['read'], isNotNull);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('đề xuất không còn (404): báo lỗi, không mở', (t) async {
      final s = Phase3Server()..followUpCode = 404;
      final data = s.data();
      final content = ContentProvider(service: ContentService(client: s.client))..setAccount('A');
      await mount(t, s, data, const ApiNotificationsView(), content: content);
      await t.tap(find.text('Nhắc lịch tái khám'));
      await t.pumpAndSettle();
      expect(data.recordsFollowupsPatientId, isNull);
      expect(find.text('Không tìm thấy hồ sơ'), findsOneWidget);
    });

    testWidgets('thông báo nhắc nằm trong mục "Lịch hẹn"; tắt nhận thông báo thì có ghi chú', (t) async {
      final s = Phase3Server()
        ..notificationType = 'appointment_reminder'
        ..notificationsEnabled = false;
      final profile = s.profile();
      await profile.loadProfile();
      final content = ContentProvider(service: ContentService(client: s.client))..setAccount('A');
      await mount(t, s, s.data(), const ApiNotificationsView(), content: content, profile: profile);
      await t.tap(find.text('Lịch hẹn'));
      await t.pumpAndSettle();
      expect(find.text('Nhắc lịch tái khám'), findsOneWidget);
      expect(find.byIcon(Icons.alarm), findsOneWidget);
      expect(find.textContaining('Bạn đã tắt "Nhận thông báo"'), findsOneWidget);
      expect(find.textContaining('demo'), findsNothing);
    });
  });

  group('A08: màn tái khám và đặt lịch', () {
    testWidgets('đề xuất "suggested": Đặt lịch tái khám gửi followUpId cho bước đặt lịch', (t) async {
      final s = Phase3Server();
      final data = s.data()..selectPatient('kid');
      await data.loadRecords(patientId: 'kid');
      await mount(t, s, data, const FollowupScreen(patientId: 'kid'));
      expect(find.text('Đã đề xuất'), findsOneWidget);
      await t.tap(find.text('Đặt lịch tái khám'));
      await t.pumpAndSettle();
      final request = PatientNavigation.pendingBookingRequest!;
      expect([request.followUpId, request.patientId, request.serviceIds], ['fu1', 'kid', ['svc_01']]);
    });

    testWidgets('đề xuất "booked": hiện "Xem lịch đã đặt", ẩn nút đặt lịch', (t) async {
      final s = Phase3Server();
      s.followUps.first
        ..['status'] = 'booked'
        ..['appointmentId'] = 'appt_9';
      final data = s.data()..selectPatient('kid');
      await data.loadRecords(patientId: 'kid');
      await mount(t, s, data, const FollowupScreen(patientId: 'kid'));
      expect(find.text('Đã đặt lịch'), findsOneWidget);
      expect(find.text('Xem lịch đã đặt'), findsOneWidget);
      expect(find.text('Đặt lịch tái khám'), findsNothing);
    });

    test('BookingController: followUpId chỉ gửi khi đúng người khám của đề xuất', () {
      final data = Phase3Server().data();
      final c = BookingController(data)
        ..applyInitialValues(replaceSelection: true, patientId: 'kid', followUpId: 'fu1', serviceIds: ['svc_01']);
      expect(c.activeFollowUpId, 'fu1');
      c.selectPatient('A');
      expect(c.activeFollowUpId, isNull);
      c.selectPatient('kid');
      expect(c.activeFollowUpId, 'fu1');
      c.applyInitialValues(replaceSelection: true, patientId: 'kid', serviceIds: ['svc_01']);
      expect(c.activeFollowUpId, isNull);
      c.dispose();
    });

    test('BookingService gửi followUpId trong body', () async {
      Map<String, dynamic>? body;
      final service = BookingService(
          client: ApiClient(
              baseUrl: 'http://fake.invalid:3000',
              client: MockClient((r) async {
                body = jsonDecode(r.body) as Map<String, dynamic>;
                return http.Response(
                    jsonEncode({
                      'id': 'appt_1', 'patientId': 'kid', 'date': '2099-04-01', 'startTime': '09:00',
                      'status': 'booked', 'followUpId': 'fu1', 'serviceIds': ['svc_01'],
                    }),
                    201,
                    headers: {'content-type': 'application/json'});
              })));
      final created = await service.createAppointment(
          patientId: 'kid', date: DateTime(2099, 4, 1), startTime: '09:00',
          serviceIds: ['svc_01'], followUpId: 'fu1');
      expect(body!['followUpId'], 'fu1');
      expect(created.followUpId, 'fu1');
    });
  });

  group('Cài đặt: Nhận thông báo lưu trên máy chủ', () {
    testWidgets('đọc từ hồ sơ, bật/tắt gửi PATCH, lỗi thì trả lại như cũ', (t) async {
      final s = Phase3Server()..notificationsEnabled = false;
      final profile = s.profile();
      await profile.loadProfile();
      await mount(t, s, s.data(), const SettingsScreen(), profile: profile);
      expect(find.text(notificationsSettingDescription), findsOneWidget);
      expect(t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);

      await t.tap(find.text('Nhận thông báo'));
      await t.pumpAndSettle();
      expect(jsonDecode(s.calls('PATCH', '/api/users/me').single.body), {'notificationsEnabled': true});
      expect(profile.profile!.notificationsEnabled, isTrue);
      expect(t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);

      s.patchCode = 500;
      await t.tap(find.text('Nhận thông báo'));
      await t.pumpAndSettle();
      expect(profile.profile!.notificationsEnabled, isTrue);
      expect(find.textContaining('Chưa lưu được cài đặt thông báo'), findsOneWidget);
    });
  });
}
